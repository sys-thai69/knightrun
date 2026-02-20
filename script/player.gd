extends CharacterBody2D

# --- Movement ---
const BASE_SPEED = 100.0
const JUMP_VELOCITY = -200.0
const MAX_JUMPS = 2
const WALL_SLIDE_SPEED = 30.0
const WALL_JUMP_VELOCITY = Vector2(150, -180)
const DASH_SPEED = 250.0
const DASH_DURATION = 0.15
const DASH_COOLDOWN = 0.8
const GROUND_POUND_SPEED = 350.0

var jump_count = 0
var is_dead: bool = false

# --- Wall Slide/Jump ---
var is_wall_sliding: bool = false
var wall_direction: int = 0

# --- Dash ---
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: float = 0.0

# --- Ground Pound ---
var is_ground_pounding: bool = false

# --- Combat ---
var is_attacking: bool = false
var is_blocking: bool = false
var shield_hp: int = 0
var invincible: bool = false
var attack_damage: int = 0
var attack_source: String = "melee"
var attack_hit_targets: Array = []  # Track what we already hit this swing

# --- Charged Attack ---
var charge_time: float = 0.0
var is_charging: bool = false
const CHARGE_THRESHOLD = 0.5  # Hold 0.5s for charged attack

# --- Parry ---
var parry_window: float = 0.0
const PARRY_DURATION = 0.15  # 150ms parry window

# --- Ranged Attack ---
var ranged_cooldown: float = 0.0
const RANGED_COOLDOWN_TIME = 0.6

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var sfx_jump: AudioStreamPlayer = $SFXJump
@onready var sfx_hurt: AudioStreamPlayer = $SFXHurt
@onready var sfx_attack: AudioStreamPlayer = $SFXAttack

func _ready() -> void:
    add_to_group("player")
    sprite.animation_finished.connect(_on_sprite_animation_finished)
    attack_collision.disabled = true
    attack_area.body_entered.connect(_on_attack_area_body_entered)
    attack_area.area_entered.connect(_on_attack_area_area_entered)
    PlayerData.full_heal()
    PlayerData.player_died.connect(_on_player_died)
    # Respawn at checkpoint if one was activated
    if PlayerData.has_checkpoint:
        global_position = PlayerData.checkpoint_position

func _on_sprite_animation_finished() -> void:
    if sprite.animation == "attack":
        is_attacking = false
        is_charging = false
        attack_collision.disabled = true
        attack_hit_targets.clear()

func get_speed() -> float:
    return BASE_SPEED + PlayerData.get_speed_bonus()

func _physics_process(delta: float) -> void:
    # ---- Timers ----
    if dash_cooldown_timer > 0:
        dash_cooldown_timer -= delta
    if ranged_cooldown > 0:
        ranged_cooldown -= delta
    if parry_window > 0:
        parry_window -= delta

    # ---- Dash ----
    if is_dashing:
        dash_timer -= delta
        velocity = Vector2(dash_direction * DASH_SPEED, 0)
        if dash_timer <= 0:
            is_dashing = false
            invincible = false
        move_and_slide()
        return

    # Gravity (not during ground pound — it has its own)
    if not is_on_floor() and not is_ground_pounding:
        velocity += get_gravity() * delta

    # Dead = no input
    if is_dead:
        velocity.x = 0
        move_and_slide()
        return

    # --- Ground Pound ---
    if is_ground_pounding:
        velocity = Vector2(0, GROUND_POUND_SPEED)
        move_and_slide()
        if is_on_floor():
            _ground_pound_impact()
        return

    # --- Wall Slide Detection ---
    is_wall_sliding = false
    wall_direction = 0
    if not is_on_floor() and velocity.y > 0:
        if is_on_wall():
            # Determine wall direction
            if test_move(global_transform, Vector2(1, 0)):
                wall_direction = 1  # wall on right
            elif test_move(global_transform, Vector2(-1, 0)):
                wall_direction = -1  # wall on left
            if wall_direction != 0:
                is_wall_sliding = true
                velocity.y = min(velocity.y, WALL_SLIDE_SPEED)

    # --- Shield Block (hold K) / Parry (tap K) ---
    if Input.is_action_just_pressed("shield") and not is_attacking:
        # Start parry window
        parry_window = PARRY_DURATION
        is_blocking = true
        shield_hp = PlayerData.get_shield_durability()
        sprite.play("idle")  # Could use a shield animation if available
        sprite.modulate = Color(0.6, 0.8, 1.0)  # Blue tint while shielding

    if Input.is_action_just_released("shield"):
        is_blocking = false
        parry_window = 0.0
        sprite.modulate = Color.WHITE

    # --- Dash (Shift) ---
    if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and PlayerData.has_dash and not is_attacking:
        is_dashing = true
        dash_timer = DASH_DURATION
        dash_cooldown_timer = DASH_COOLDOWN
        invincible = true
        # Dash in the facing direction
        dash_direction = -1.0 if sprite.flip_h else 1.0
        # Dash trail effect
        _spawn_dash_ghost()
        return

    # --- Ground Pound (S while airborne) ---
    if Input.is_action_just_pressed("move_down") and not is_on_floor() and not is_ground_pounding:
        is_ground_pounding = true
        velocity = Vector2.ZERO
        return

    # --- Ranged Attack (L key) ---
    if Input.is_action_just_pressed("ranged_attack") and PlayerData.has_ranged and ranged_cooldown <= 0 and not is_attacking and not is_blocking:
        _ranged_attack()

    # --- Charged Attack (hold J) ---
    if Input.is_action_pressed("attack") and not is_blocking and not is_attacking:
        if not is_charging:
            is_charging = true
            charge_time = 0.0
        charge_time += delta
        # Visual feedback: player glows more as charge builds
        var charge_ratio = min(charge_time / CHARGE_THRESHOLD, 1.0)
        sprite.modulate = Color(1, 1, 1 - charge_ratio * 0.7)  # Tints yellow

    if Input.is_action_just_released("attack") and is_charging:
        if charge_time >= CHARGE_THRESHOLD:
            _charged_attack()
        else:
            _normal_attack()
        is_charging = false
        charge_time = 0.0
        sprite.modulate = Color.WHITE

    # --- Normal Attack (J or Left Click, tap) ---
    if Input.is_action_just_pressed("attack") and not is_attacking and not is_blocking and not is_charging:
        pass  # Handled by charge system above (release triggers attack)

    # --- Jump ---
    if is_on_floor():
        jump_count = 0

    if Input.is_action_just_pressed("jump"):
        if is_wall_sliding and not is_attacking:
            # Wall jump
            velocity.x = -wall_direction * WALL_JUMP_VELOCITY.x
            velocity.y = WALL_JUMP_VELOCITY.y
            jump_count = 1
            is_wall_sliding = false
            sprite.flip_h = wall_direction > 0
            if attack_area:
                attack_area.position.x = -wall_direction * 10
                attack_area.scale.x = -wall_direction
            if sfx_jump:
                sfx_jump.play()
            sprite.play("jump")
        elif is_on_floor() or jump_count < MAX_JUMPS:
            velocity.y = JUMP_VELOCITY
            jump_count += 1
            if sfx_jump:
                sfx_jump.play()
            if not is_attacking:
                if jump_count == 1:
                    sprite.play("jump")
                else:
                    sprite.play("jump1")

    # --- Horizontal Movement ---
    var direction := Input.get_axis("move_left", "move_right")
    if is_blocking:
        direction = 0  # Can't move while blocking

    if direction:
        velocity.x = direction * get_speed()
        if direction > 0:
            sprite.flip_h = false
            attack_area.position.x = 10
            attack_area.scale.x = 1
        elif direction < 0:
            sprite.flip_h = true
            attack_area.position.x = -10
            attack_area.scale.x = -1
    else:
        velocity.x = move_toward(velocity.x, 0, get_speed())

    # --- Animation ---
    if not is_attacking:
        if is_wall_sliding:
            sprite.play("jump")  # Placeholder: use "wall_slide" when available
        elif not is_on_floor():
            if (sprite.animation != "jump" and sprite.animation != "jump1") and velocity.y > 0:
                sprite.play("jump")
        elif direction != 0:
            sprite.play("run")
        else:
            sprite.play("idle")

    move_and_slide()

# --- ATTACKS ---

func _normal_attack() -> void:
    is_attacking = true
    attack_damage = PlayerData.get_attack_damage()
    attack_source = "melee"
    attack_hit_targets.clear()
    attack_collision.disabled = false
    sprite.play("attack")
    if sfx_attack:
        sfx_attack.play()
    # Safety timer: force-clear is_attacking if animation_finished doesn't fire
    get_tree().create_timer(0.6).timeout.connect(_force_clear_attack)

func _charged_attack() -> void:
    is_attacking = true
    attack_damage = PlayerData.get_attack_damage() * 2
    attack_source = "melee"
    attack_hit_targets.clear()
    attack_collision.disabled = false
    sprite.play("attack")
    if sfx_attack:
        sfx_attack.play()
    get_tree().create_timer(0.6).timeout.connect(_force_clear_attack)
    # Screen shake for charged attack
    ScreenEffects.shake(5.0, 0.15)
    ScreenEffects.hit_freeze(0.06)

func _force_clear_attack() -> void:
    if is_attacking:
        is_attacking = false
        is_charging = false
        attack_collision.disabled = true
        attack_hit_targets.clear()

func _ranged_attack() -> void:
    ranged_cooldown = RANGED_COOLDOWN_TIME
    # Spawn a player projectile
    var proj_scene = preload("res://scenes/player_projectile.tscn")
    var proj = proj_scene.instantiate()
    get_parent().add_child(proj)
    var dir = -1 if sprite.flip_h else 1
    proj.global_position = global_position + Vector2(dir * 12, 2)
    proj.set_direction(dir)
    if sfx_attack:
        sfx_attack.play()

func _perform_attack(damage: int, source_type: String = "melee") -> void:
    for body in attack_area.get_overlapping_bodies():
        if body in attack_hit_targets:
            continue
        if body.has_method("take_hit"):
            attack_hit_targets.append(body)
            body.take_hit(damage, source_type)
            ScreenEffects.hit_freeze(0.04)
            ScreenEffects.shake(3.0, 0.1)
            ScreenEffects.spawn_damage_number(body.global_position, damage, Color.WHITE)
    for area in attack_area.get_overlapping_areas():
        var target = area
        if not area.has_method("take_hit") and area.get_parent() and area.get_parent().has_method("take_hit"):
            target = area.get_parent()
        if target in attack_hit_targets:
            continue
        if target.has_method("take_hit"):
            attack_hit_targets.append(target)
            target.take_hit(damage, source_type)
            ScreenEffects.spawn_damage_number(target.global_position, damage, Color.WHITE)

# Signal-based hit detection: fires whenever something enters the attack area during a swing
func _on_attack_area_body_entered(body: Node2D) -> void:
    if not is_attacking or body == self:
        return
    if body in attack_hit_targets:
        return
    if body.has_method("take_hit"):
        attack_hit_targets.append(body)
        body.take_hit(attack_damage, attack_source)
        ScreenEffects.hit_freeze(0.04)
        ScreenEffects.shake(3.0, 0.1)
        ScreenEffects.spawn_damage_number(body.global_position, attack_damage, Color.WHITE)

func _on_attack_area_area_entered(area: Area2D) -> void:
    if not is_attacking:
        return
    var target = area
    if not area.has_method("take_hit") and area.get_parent() and area.get_parent().has_method("take_hit"):
        target = area.get_parent()
    if target in attack_hit_targets:
        return
    if target.has_method("take_hit"):
        attack_hit_targets.append(target)
        target.take_hit(attack_damage, attack_source)
        ScreenEffects.spawn_damage_number(target.global_position, attack_damage, Color.WHITE)

func _ground_pound_impact() -> void:
    is_ground_pounding = false
    ScreenEffects.shake(6.0, 0.2)
    ScreenEffects.hit_freeze(0.05)
    # Damage nearby enemies
    var damage = PlayerData.get_attack_damage()
    for body in attack_area.get_overlapping_bodies():
        if body.has_method("take_hit"):
            body.take_hit(damage, "melee")
            ScreenEffects.spawn_damage_number(body.global_position, damage, Color.ORANGE)
    # Check for crumbling platforms below
    var space = get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 20))
    var result = space.intersect_ray(query)
    if result and result.collider.has_method("start_crumble"):
        result.collider.start_crumble()

func _spawn_dash_ghost() -> void:
    # Create a fading ghost sprite at current position
    var ghost = AnimatedSprite2D.new()
    ghost.sprite_frames = sprite.sprite_frames
    ghost.animation = sprite.animation
    ghost.frame = sprite.frame
    ghost.flip_h = sprite.flip_h
    ghost.global_position = global_position
    ghost.modulate = Color(0.5, 0.8, 1.0, 0.6)
    ghost.z_index = -1
    get_parent().add_child(ghost)
    var tween = ghost.create_tween()
    tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
    tween.tween_callback(ghost.queue_free)

# --- DAMAGE ---

func take_damage(amount: int = 1) -> void:
    if is_dead or invincible:
        return

    # Parry check (precise timing)
    if parry_window > 0:
        _parry_success()
        return

    if is_blocking and shield_hp > 0:
        shield_hp -= 1
        if shield_hp <= 0:
            is_blocking = false
        # Shield block effect
        ScreenEffects.shake(2.0, 0.1)
        sprite.modulate = Color(0.5, 0.5, 1.0)
        # Brief invincibility after shield block to prevent instant re-damage
        invincible = true
        get_tree().create_timer(0.5).timeout.connect(func():
            invincible = false
            if is_blocking:
                sprite.modulate = Color(0.6, 0.8, 1.0)
            else:
                sprite.modulate = Color.WHITE
        )
        return  # Blocked!

    PlayerData.take_damage(amount)
    ScreenEffects.shake(4.0, 0.2)
    ScreenEffects.spawn_damage_number(global_position, amount, Color.RED)
    if PlayerData.current_health > 0:
        if sfx_hurt:
            sfx_hurt.play()
        # Brief invincibility
        invincible = true
        _flash_damage()
        get_tree().create_timer(1.0).timeout.connect(func(): invincible = false)

func _parry_success() -> void:
    # Successful parry: reflect nearby projectiles and stun nearby enemies
    parry_window = 0.0
    # Don't drop shield — player is still holding K
    ScreenEffects.hit_freeze(0.08)
    ScreenEffects.shake(3.0, 0.15)

    # Brief invincibility after parry
    invincible = true
    get_tree().create_timer(0.3).timeout.connect(func(): invincible = false)

    # Flash green for parry
    sprite.modulate = Color(0.3, 1.0, 0.3)
    get_tree().create_timer(0.2).timeout.connect(func():
        if is_blocking:
            sprite.modulate = Color(0.6, 0.8, 1.0)  # Return to shield tint
        else:
            sprite.modulate = Color.WHITE
    )

    # Reflect nearby projectiles
    var nearby = get_tree().get_nodes_in_group("projectile")
    for proj in nearby:
        if proj.global_position.distance_to(global_position) < 50:
            if proj.has_method("reflect"):
                proj.reflect()

func _flash_damage() -> void:
    sprite.modulate = Color(1, 0.3, 0.3)
    get_tree().create_timer(0.15).timeout.connect(func(): sprite.modulate = Color.WHITE)
    get_tree().create_timer(0.3).timeout.connect(func(): sprite.modulate = Color(1, 0.3, 0.3))
    get_tree().create_timer(0.45).timeout.connect(func(): sprite.modulate = Color.WHITE)

func _on_player_died() -> void:
    if is_dead:
        return
    is_dead = true
    is_attacking = false
    is_charging = false
    is_blocking = false
    is_ground_pounding = false
    attack_collision.disabled = true
    sprite.modulate = Color.WHITE
    Engine.time_scale = 0.5
    velocity.y = -200
    set_collision_mask_value(1, false)
    set_collision_layer_value(1, false)
    sprite.play("jump")
    get_tree().create_timer(1.0, true, false, true).timeout.connect(_on_death_timer)

func _on_death_timer() -> void:
    Engine.time_scale = 1
    PlayerData.reset_health_only()
    SaveManager.save_game()
    get_tree().reload_current_scene()  # Scene reloads, player._ready() will move to checkpoint
