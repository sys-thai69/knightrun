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

# --- Stamina ---
const MAX_STAMINA: float = 100.0
const STAMINA_REGEN_RATE: float = 25.0  # Per second
const DASH_STAMINA_COST: float = 30.0
const SHIELD_STAMINA_COST: float = 15.0  # Per second while blocking
var current_stamina: float = MAX_STAMINA
var stamina_regen_delay: float = 0.0  # Delay before regen starts after use
const STAMINA_REGEN_DELAY_TIME: float = 0.5

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

# --- Coyote Time & Jump Buffer ---
var coyote_timer: float = 0.0
const COYOTE_TIME = 0.1
var jump_buffer: float = 0.0
const JUMP_BUFFER_TIME = 0.1

# --- Invincibility Timer ---
var invincibility_timer: float = 0.0

# --- Ceiling Stick ---
var ceiling_stick_timer: float = 0.0
const CEILING_STICK_MAX: float = 0.12  # Max time to cling to ceiling (seconds)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var sfx_jump: AudioStreamPlayer = $SFXJump
@onready var sfx_hurt: AudioStreamPlayer = $SFXHurt
@onready var sfx_attack: AudioStreamPlayer = $SFXAttack

# --- Ladder ---
var is_on_ladder: bool = false
var ladder_count: int = 0  # How many ladder areas overlap

# --- Surface Modifiers ---
var on_ice: bool = false     # Set by IceBlock area
var on_mud: bool = false     # Set by MudBlock area

# --- Torch ---
var has_torch: bool = false  # Set by TorchPickup; disables sword

# --- Carry Block ---
var carried_block: Node2D = null  # Block currently being held

# Surface constants
const ICE_FRICTION = 5.0     # Very low friction on ice (vs normal get_speed())
const MUD_SPEED_MULT = 0.5   # Half speed on mud
const MUD_JUMP_MULT = 0.75   # Weaker jump on mud

func _ready() -> void:
    add_to_group("player")
    sprite.animation_finished.connect(_on_sprite_animation_finished)
    attack_collision.disabled = true
    attack_area.body_entered.connect(_on_attack_area_body_entered)
    attack_area.area_entered.connect(_on_attack_area_area_entered)
    PlayerData.full_heal()
    PlayerData.player_died.connect(_on_player_died)
    # Register camera for screen shake
    if has_node("Camera2D"):
        ScreenEffects.register_camera($Camera2D)
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
    var spd = BASE_SPEED + PlayerData.get_speed_bonus()
    if on_mud:
        spd *= MUD_SPEED_MULT
    return spd

func _physics_process(delta: float) -> void:
    # ---- Time Trial ----
    PlayerData.update_time_trial(delta)
    
    # ---- Timers ----
    if dash_cooldown_timer > 0:
        dash_cooldown_timer -= delta
    if ranged_cooldown > 0:
        ranged_cooldown -= delta
    if parry_window > 0:
        parry_window -= delta

    # ---- Stamina Regen ----
    if stamina_regen_delay > 0:
        stamina_regen_delay -= delta
    elif not is_blocking and current_stamina < MAX_STAMINA:
        current_stamina = min(current_stamina + STAMINA_REGEN_RATE * delta, MAX_STAMINA)

    # ---- Invincibility timer ----
    if invincibility_timer > 0:
        invincibility_timer -= delta
        if invincibility_timer <= 0:
            invincible = false

    # Dead = no input (checked BEFORE dash so corpse can't dash)
    if is_dead:
        velocity.x = 0
        if not is_on_floor():
            velocity += get_gravity() * delta
        move_and_slide()
        return

    # ---- Dash ----
    if is_dashing:
        dash_timer -= delta
        velocity = Vector2(dash_direction * DASH_SPEED, 0)
        if dash_timer <= 0:
            is_dashing = false
            invincible = false
        move_and_slide()
        return

    # Gravity (not during ground pound or ladder — it has its own)
    if not is_on_floor() and not is_ground_pounding and not is_on_ladder:
        # Ceiling stick: when jumping upward and hitting a ceiling, briefly hold
        if ceiling_stick_timer > 0:
            ceiling_stick_timer -= delta
            velocity.y = 0
        else:
            velocity += get_gravity() * delta

    # Detect ceiling hit and start stick
    if is_on_ceiling() and velocity.y <= 0 and ceiling_stick_timer <= 0 and not is_on_ladder:
        # Stick duration proportional to remaining upward momentum
        var momentum_ratio = clamp(abs(velocity.y) / abs(JUMP_VELOCITY), 0.0, 1.0)
        ceiling_stick_timer = momentum_ratio * CEILING_STICK_MAX
        velocity.y = 0

    # Reset ceiling stick when on floor
    if is_on_floor():
        ceiling_stick_timer = 0

    # --- Ladder Climbing ---
    if is_on_ladder:
        var vert = Input.get_axis("jump", "move_down")  # W = up, S = down
        velocity.y = vert * 80.0
        # Allow horizontal movement on ladder
        var horiz := Input.get_axis("move_left", "move_right")
        velocity.x = horiz * get_speed() * 0.5
        if not is_attacking:
            if vert != 0:
                sprite.play("run")  # Placeholder for climb animation
            else:
                sprite.play("idle")
        move_and_slide()
        # Jump off ladder
        if Input.is_action_just_pressed("jump"):
            is_on_ladder = false
            ladder_count = 0  # Force exit
            velocity.y = JUMP_VELOCITY
            jump_count = 1
            if sfx_jump:
                sfx_jump.play()
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
    if Input.is_action_just_pressed("shield") and not is_attacking and PlayerData.has_shield and current_stamina > 0:
        # Start parry window
        parry_window = PARRY_DURATION
        is_blocking = true
        shield_hp = PlayerData.get_shield_durability()
        sprite.play("idle")  # Could use a shield animation if available
        sprite.modulate = Color(0.6, 0.8, 1.0)  # Blue tint while shielding

    # Shield consumes stamina while held
    if is_blocking:
        current_stamina -= SHIELD_STAMINA_COST * delta
        stamina_regen_delay = STAMINA_REGEN_DELAY_TIME
        if current_stamina <= 0:
            current_stamina = 0
            is_blocking = false
            parry_window = 0.0
            sprite.modulate = Color.WHITE

    if Input.is_action_just_released("shield"):
        is_blocking = false
        parry_window = 0.0
        sprite.modulate = Color.WHITE

    # --- Dash (Shift) ---
    if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and PlayerData.has_dash and not is_attacking and current_stamina >= DASH_STAMINA_COST:
        is_dashing = true
        dash_timer = DASH_DURATION
        dash_cooldown_timer = DASH_COOLDOWN
        invincible = true
        # Consume stamina for dash
        current_stamina -= DASH_STAMINA_COST
        stamina_regen_delay = STAMINA_REGEN_DELAY_TIME
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

    # --- Interact / Carry Block (E key) ---
    if Input.is_action_just_pressed("interact"):
        if carried_block:
            _drop_block()
        else:
            _try_pick_up_block()

    # --- Ranged Attack (L key) ---
    if Input.is_action_just_pressed("ranged_attack") and PlayerData.has_ranged and ranged_cooldown <= 0 and not is_attacking and not is_blocking and not has_torch:
        _ranged_attack()

    # --- Charged Attack (hold J) ---
    if Input.is_action_pressed("attack") and not is_blocking and not is_attacking and PlayerData.has_sword and not has_torch:
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

    # --- Instant tap attack (J pressed, fires immediately if not already attacking) ---
    if Input.is_action_just_pressed("attack") and not is_attacking and not is_blocking and PlayerData.has_sword and not has_torch:
        # Start charging, but also do instant attack on super-fast taps via release above
        pass

    # --- Coyote Time & Jump Buffer ---
    if is_on_floor():
        jump_count = 0
        coyote_timer = COYOTE_TIME
    else:
        coyote_timer -= delta

    if Input.is_action_just_pressed("jump"):
        jump_buffer = JUMP_BUFFER_TIME
    if jump_buffer > 0:
        jump_buffer -= delta

    # --- Variable Jump Height (release early = short hop) ---
    if Input.is_action_just_released("jump") and velocity.y < 0:
        velocity.y *= 0.5

    # --- Jump ---
    if Input.is_action_just_pressed("jump") or (jump_buffer > 0 and is_on_floor()):
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
        elif coyote_timer > 0 or jump_count < MAX_JUMPS:
            velocity.y = JUMP_VELOCITY * (MUD_JUMP_MULT if on_mud else 1.0)
            jump_count += 1
            coyote_timer = 0
            jump_buffer = 0
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
        if on_ice:
            # On ice: accelerate toward target speed with low friction (slide)
            velocity.x = move_toward(velocity.x, direction * get_speed(), ICE_FRICTION)
        else:
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
        if on_ice:
            velocity.x = move_toward(velocity.x, 0, ICE_FRICTION)
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
    _check_landing()

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
    _start_safe_timer(0.6, _force_clear_attack)

func _charged_attack() -> void:
    is_attacking = true
    attack_damage = PlayerData.get_attack_damage() * 2
    attack_source = "melee"
    attack_hit_targets.clear()
    attack_collision.disabled = false
    sprite.play("attack")
    if sfx_attack:
        sfx_attack.play()
    _start_safe_timer(0.6, _force_clear_attack)

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

# --- CARRY BLOCK ---

func _try_pick_up_block() -> void:
    # Find the nearest carriable block within pickup range
    var best: Node2D = null
    var best_dist: float = 30.0  # Max pickup range
    for node in get_tree().get_nodes_in_group("carriable"):
        if not is_instance_valid(node) or node.is_carried:
            continue
        var d = global_position.distance_to(node.global_position)
        if d < best_dist:
            best_dist = d
            best = node
    if best and best.has_method("pick_up"):
        carried_block = best
        best.pick_up(self)

func _drop_block() -> void:
    if carried_block and is_instance_valid(carried_block):
        var dir = -1 if sprite.flip_h else 1
        carried_block.drop(dir)
    carried_block = null

# Signal-based hit detection: fires whenever something enters the attack area during a swing
func _on_attack_area_body_entered(body: Node2D) -> void:
    if not is_attacking or body == self:
        return
    if body in attack_hit_targets:
        return
    if body.has_method("take_hit"):
        attack_hit_targets.append(body)
        body.take_hit(attack_damage, attack_source)

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

func _ground_pound_impact() -> void:
    is_ground_pounding = false
    ScreenEffects.shake(2.0, 0.1)
    # Temporarily enable attack collision for ground pound hit detection
    attack_collision.disabled = false
    # Force physics update so overlapping bodies are detected
    attack_area.force_update_transform()
    await get_tree().physics_frame
    # Damage nearby enemies (deduplicate to prevent double-hits)
    var damage = PlayerData.get_attack_damage()
    var hit_targets: Array = []
    for body in attack_area.get_overlapping_bodies():
        if body != self and body.has_method("take_hit") and body not in hit_targets:
            hit_targets.append(body)
            body.take_hit(damage, "melee")
    for area in attack_area.get_overlapping_areas():
        var target = area
        if not area.has_method("take_hit") and area.get_parent() and area.get_parent().has_method("take_hit"):
            target = area.get_parent()
        if target.has_method("take_hit") and target not in hit_targets:
            hit_targets.append(target)
            target.take_hit(damage, "melee")
    attack_collision.disabled = true
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

# --- LADDER ---

func enter_ladder() -> void:
    ladder_count += 1
    is_on_ladder = true
    velocity.y = 0
    jump_count = 0

func exit_ladder() -> void:
    ladder_count -= 1
    if ladder_count <= 0:
        ladder_count = 0
        is_on_ladder = false

# --- LANDING DUST ---

var was_in_air: bool = false

func _check_landing() -> void:
    if is_on_floor() and was_in_air:
        _spawn_landing_dust()
    was_in_air = not is_on_floor()

func _spawn_landing_dust() -> void:
    for i in range(4):
        var p = Label.new()
        p.text = "~"
        p.add_theme_font_size_override("font_size", 6)
        p.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65, 0.8))
        p.global_position = global_position + Vector2(randf_range(-6, 6), 10)
        p.z_index = 50
        get_parent().add_child(p)
        var tw = p.create_tween()
        tw.set_parallel(true)
        tw.tween_property(p, "position", p.position + Vector2(randf_range(-12, 12), randf_range(-8, -3)), 0.3)
        tw.tween_property(p, "modulate:a", 0.0, 0.3)
        tw.chain().tween_callback(p.queue_free)

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
        sprite.modulate = Color(0.5, 0.5, 1.0)
        # Brief invincibility after shield block to prevent instant re-damage
        invincible = true
        invincibility_timer = 0.5
        _start_safe_timer(0.5, func():
            if is_blocking:
                sprite.modulate = Color(0.6, 0.8, 1.0)
            else:
                sprite.modulate = Color.WHITE
        )
        return  # Blocked!

    PlayerData.take_damage(amount)
    ScreenEffects.shake(1.5, 0.1)
    ScreenEffects.spawn_damage_number(global_position, amount, Color.RED)
    if PlayerData.current_health > 0:
        if sfx_hurt:
            sfx_hurt.play()
        # Brief invincibility
        invincible = true
        invincibility_timer = 1.0
        _flash_damage()

func _parry_success() -> void:
    # Successful parry: reflect nearby projectiles and stun nearby enemies
    parry_window = 0.0
    # Don't drop shield — player is still holding K
    ScreenEffects.hit_freeze(0.04)

    # Brief invincibility after parry
    invincible = true
    invincibility_timer = 0.3

    # Flash green for parry
    sprite.modulate = Color(0.3, 1.0, 0.3)
    _start_safe_timer(0.2, func():
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
    var tw = create_tween()
    tw.tween_property(sprite, "modulate", Color(1, 0.3, 0.3), 0.0)
    tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
    tw.tween_property(sprite, "modulate", Color(1, 0.3, 0.3), 0.0)
    tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)

# --- SAFE TIMER: uses node-owned Timer that dies with the scene ---
func _start_safe_timer(duration: float, callback: Callable) -> void:
    var t = Timer.new()
    t.wait_time = duration
    t.one_shot = true
    t.autostart = true
    add_child(t)
    t.timeout.connect(func():
        if is_instance_valid(self):
            callback.call()
        t.queue_free()
    )

func _on_player_died() -> void:
    if is_dead:
        return
    is_dead = true
    is_attacking = false
    is_charging = false
    is_blocking = false
    is_dashing = false
    is_ground_pounding = false
    # Drop any carried block
    if carried_block and is_instance_valid(carried_block):
        _drop_block()
    attack_collision.set_deferred("disabled", true)
    sprite.modulate = Color.WHITE
    # Clear any active hit-freeze so death slow-mo isn't overridden
    ScreenEffects.freeze_timer = 0.0
    Engine.time_scale = 0.5
    velocity.y = -200
    set_collision_mask_value(1, false)
    set_collision_layer_value(1, false)
    sprite.play("jump")
    # Use a node-owned timer so it gets freed with the player
    var death_timer = Timer.new()
    death_timer.wait_time = 1.0
    death_timer.one_shot = true
    death_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
    add_child(death_timer)
    death_timer.timeout.connect(_on_death_timer)
    death_timer.start()

func _on_death_timer() -> void:
    Engine.time_scale = 1
    PlayerData.reset_health_only()
    SaveManager.save_game()
    get_tree().reload_current_scene()  # Scene reloads, player._ready() will move to checkpoint
