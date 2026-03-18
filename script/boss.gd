# boss.gd — Final Guardian of the Trial (Mahoraga-inspired adaptive boss)
# Animations used: idle, run, attack, charge, fire, block, adapt, death
# Future animations (add later): plunge, shield
extends CharacterBody2D

signal boss_defeated

# --- Stats ---
const MAX_HEALTH: int = 48
var health: int = MAX_HEALTH
var scaled_max_health: int = MAX_HEALTH  # Actual max after NG+ scaling
var is_dead: bool = false

# --- Mahoraga Adaptation System ---
var damage_from_melee: int = 0
var damage_from_distance: int = 0
var adaptation_threshold: int = 8
var melee_resistance: float = 0.0
var ranged_resistance: float = 0.0
var phase: int = 1  # 1 = slow, 2 = faster, 3 = aggressive

# --- Movement ---
var direction: int = -1
const ACTIVATION_RANGE: float = 250.0  # Boss only engages when player is within this range
var is_activated: bool = false
const SPEED_PHASE1: float = 40.0
const SPEED_PHASE2: float = 52.0
const SPEED_PHASE3: float = 66.0
var current_speed: float = SPEED_PHASE1

# --- Action State ---
var is_acting: bool = false  # True when attacking/blocking/adapting
var attack_cooldown: float = 2.9
var attack_timer: float = 0.0
var player_ref: CharacterBody2D = null
var gravity: float = 800.0
var combo_count: int = 0  # Track combo hits in phase 3

# --- Charge Attack (Phase 2+) ---
var is_charging: bool = false
var charge_speed: float = 200.0
var charge_duration: float = 0.5
var charge_timer: float = 0.0

# --- Slam Attack (Phase 3) ---
var is_slamming: bool = false
var slam_jump_velocity: float = -300.0
const SLAM_DAMAGE_RADIUS: float = 80.0  # Shockwave radius

# --- Block ---
var is_blocking: bool = false
var block_chance: float = 0.15  # Lower block chance for fairer damage windows

# --- 50% HP Summon ---
var has_summoned_backup: bool = false
var summoner_scene: PackedScene = preload("res://enemy/summoner.tscn")
var homing_scene: PackedScene = preload("res://scenes/homing_projectile.tscn")

# --- Hit Effect ---
var base_sprite_scale: Vector2 = Vector2.ONE
var pop_tween: Tween = null

# --- Contact Damage (standing on boss) ---
var _contact_dmg_timer: float = 0.0
const CONTACT_DMG_INTERVAL: float = 1.15

# --- Attack Telegraphing ---
var telegraph_tween: Tween = null

# --- Ranged Attack ---
@export var projectile_scene: PackedScene  # Drag fireball.tscn here in Inspector

# --- Pre-generated shockwave texture (optimization) ---
var _shockwave_texture: ImageTexture = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
var hurt_area: Area2D = null  # Created dynamically in _setup_hurt_area()

func _ready() -> void:
    add_to_group("enemy")
    add_to_group("boss")
    # Scale boss HP with NG+ level
    health = int(MAX_HEALTH * PlayerData.get_enemy_hp_multiplier())
    scaled_max_health = health
    if attack_collision:
        attack_collision.disabled = true
    # Store original sprite scale so hit effects can pop and return correctly
    base_sprite_scale = sprite.scale
    # Pre-generate shockwave texture
    _create_shockwave_texture()
    # Setup attack area signal for real-time hit detection
    # Setup hurt area for body contact damage
    _setup_hurt_area()
    # Find the player
    await get_tree().process_frame
    var players: Array[Node] = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        player_ref = players[0]
    # Do NOT show HP bar yet - wait until boss is activated
    # Start idle animation
    _play("idle")

func _setup_hurt_area() -> void:
    # Create a hurt area for body contact damage (during charge, etc.)
    if not has_node("HurtArea"):
        hurt_area = Area2D.new()
        hurt_area.name = "HurtArea"
        hurt_area.collision_layer = 0
        hurt_area.collision_mask = 2  # Detect player
        var shape = CollisionShape2D.new()
        var rect = RectangleShape2D.new()
        rect.size = Vector2(38, 50)
        shape.shape = rect
        shape.position = Vector2(0, 0)
        hurt_area.add_child(shape)
        add_child(hurt_area)
    if hurt_area:
        hurt_area.body_entered.connect(_on_hurt_area_body_entered)

func _on_hurt_area_body_entered(body: Node2D) -> void:
    # Immediate damage on body contact — extra hit during charge
    if is_dead:
        return
    if body.is_in_group("player") and body.has_method("take_damage") and not body.invincible:
        var dmg = 1
        body.take_damage(dmg)
        _contact_dmg_timer = CONTACT_DMG_INTERVAL

func _create_shockwave_texture() -> void:
    # Pre-generate the shockwave ring texture once
    var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for x in range(64):
        for y in range(64):
            var dist = Vector2(x - 32, y - 32).length()
            if dist >= 28 and dist <= 32:
                img.set_pixel(x, y, Color.WHITE)
    _shockwave_texture = ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    # Gravity
    if not is_on_floor():
        velocity.y += gravity * delta

    attack_timer -= delta

    if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
        var dist: float = global_position.distance_to(player_ref.global_position)
        var dir_to_player: int = int(sign(player_ref.global_position.x - global_position.x))

        # Only activate when player gets close enough
        if not is_activated:
            if dist > ACTIVATION_RANGE:
                velocity.x = 0
                _play("idle")
                move_and_slide()
                return
            else:
                is_activated = true
                # Show boss HP bar when activated
                var hp_bar = get_parent().get_node_or_null("BossHPBar")
                if hp_bar and hp_bar.has_method("set_boss"):
                    hp_bar.set_boss(self)

        # Face player (flip sprite)
        if not is_charging and not is_acting:
            if dir_to_player != 0:
                sprite.flip_h = dir_to_player < 0
                if attack_area:
                    attack_area.position.x = 16.0 * dir_to_player
        # --- Charge Attack ---
        if is_charging:
            charge_timer -= delta
            velocity.x = direction * charge_speed
            if charge_timer <= 0:
                is_charging = false
                is_acting = false
                velocity.x = 0
                _play("idle")
            move_and_slide()
            return

        # --- Slam Attack ---
        if is_slamming:
            if is_on_floor() and velocity.y >= 0:
                is_slamming = false
                _slam_impact()
            move_and_slide()
            return

        # Don't pick new actions while acting
        # Contact damage — damage player if standing on/touching boss
        _contact_dmg_timer -= delta
        if _contact_dmg_timer <= 0 and hurt_area:
            for body in hurt_area.get_overlapping_bodies():
                if body.is_in_group("player") and body.has_method("take_damage") and not body.invincible:
                    body.take_damage(1)
                    _contact_dmg_timer = CONTACT_DMG_INTERVAL
                    break

        if is_acting:
            velocity.x = move_toward(velocity.x, 0, 200.0 * delta)
            move_and_slide()
            return

        # --- Phase-based AI ---
        if dist < 38 and attack_timer <= 0:
            _melee_attack()
        elif phase >= 2 and dist > 180 and attack_timer <= 0:
            _ranged_attack(dir_to_player)
        elif phase >= 2 and dist > 80 and dist < 180 and attack_timer <= 0:
            # Phase 2+: Random choice between charge and ranged
            if randf() < 0.6:
                _charge_attack(dir_to_player)
            else:
                _ranged_attack(dir_to_player)
        elif phase >= 3 and dist > 60 and dist < 150 and attack_timer <= 0 and is_on_floor():
            # Phase 3: Slam or combo attack
            if randf() < 0.4:
                _slam_attack()
            else:
                _combo_attack(dir_to_player)
        else:
            # Walk toward player
            velocity.x = dir_to_player * current_speed
            _play("run")
    else:
        velocity.x = 0
        _play("idle")

    move_and_slide()

# --- ATTACKS ---

var _attack_hit_this_swing: bool = false  # Track if we hit player this attack

func _melee_attack() -> void:
    is_acting = true
    velocity.x = 0
    attack_timer = attack_cooldown
    _attack_hit_this_swing = false

    # Lock facing direction before acting so attack area is correctly placed
    if player_ref and is_instance_valid(player_ref):
        var atk_dir = int(sign(player_ref.global_position.x - global_position.x))
        if atk_dir != 0:
            sprite.flip_h = atk_dir < 0
            attack_area.position.x = 16.0 * atk_dir

    # Telegraph
    _telegraph_attack()
    await get_tree().create_timer(0.15).timeout
    if is_dead or not is_instance_valid(self):
        return

    _play("attack")
    attack_collision.disabled = false

    # Wait one physics frame so overlap detection updates
    await get_tree().physics_frame

    # Poll every physics frame for 0.5s
    var elapsed: float = 0.0
    while elapsed < 0.5:
        if is_dead or not is_instance_valid(self):
            attack_collision.disabled = true
            return
        if not _attack_hit_this_swing and attack_area:
            for body in attack_area.get_overlapping_bodies():
                if body.is_in_group("player") and body.has_method("take_damage"):
                    if not body.invincible:
                        body.take_damage(1)
                        ScreenEffects.hit_freeze(0.04)
                    _attack_hit_this_swing = true
                    break
        await get_tree().physics_frame
        elapsed += get_physics_process_delta_time()

    attack_collision.disabled = true
    is_acting = false
    _play("idle")

func _combo_attack(dir: int) -> void:
    # Phase 3 combo: charge into melee
    is_acting = true
    direction = dir
    attack_timer = attack_cooldown * 0.8
    
    # First: short dash
    _telegraph_attack()
    await get_tree().create_timer(0.1).timeout
    if is_dead or not is_instance_valid(self):
        return
    
    _play("charge")
    var dash_time: float = 0.25
    var dash_speed: float = 150.0
    var elapsed: float = 0.0
    while elapsed < dash_time:
        velocity.x = direction * dash_speed
        await get_tree().process_frame
        if is_dead or not is_instance_valid(self):
            return
        elapsed += get_physics_process_delta_time()
    
    velocity.x = 0
    
    # Second: immediate melee swing
    if attack_collision:
        attack_collision.disabled = false
    _play("attack")
    await get_tree().physics_frame
    if attack_area:
        for body in attack_area.get_overlapping_bodies():
            if body.is_in_group("player") and body.has_method("take_hit"):
                body.take_hit(2, "melee")
    await get_tree().create_timer(0.4).timeout
    if is_dead or not is_instance_valid(self):
        return
    
    await get_tree().physics_frame
    if attack_area:
        for body in attack_area.get_overlapping_bodies():
            if body.is_in_group("player") and body.has_method("take_hit"):
                body.take_hit(2, "melee")
    
    if attack_collision:
        attack_collision.disabled = true
    is_acting = false
    _play("idle")

func _charge_attack(dir: int) -> void:
    is_acting = true
    direction = dir
    attack_timer = attack_cooldown * 1.5
    
    # Telegraph the charge
    _telegraph_attack()
    velocity.x = 0
    await get_tree().create_timer(0.2).timeout
    if is_dead or not is_instance_valid(self):
        return
    
    is_charging = true
    charge_timer = charge_duration
    _play("charge")

func _ranged_attack(dir: int) -> void:
    is_acting = true
    velocity.x = 0
    attack_timer = attack_cooldown * 1.2
    _play("fire")

    # Wait for the animation to reach the "release" point
    await get_tree().create_timer(0.3).timeout
    if is_dead or not is_instance_valid(self):
        return

    # Spawn multiple fireballs in spread pattern
    if projectile_scene:
        var fireball_count = 3 if phase >= 2 else 2
        var spread_angles = [-0.3, 0, 0.3] if fireball_count == 3 else [-0.15, 0.15]
        for i in range(fireball_count):
            var proj: Node2D = projectile_scene.instantiate()
            get_parent().add_child(proj)
            proj.global_position = global_position + Vector2(20.0 * dir, -10.0)
            # Set direction with spread
            var angle = spread_angles[i] if i < spread_angles.size() else 0.0
            var fire_dir = Vector2(dir, angle).normalized()
            if "direction" in proj:
                proj.direction = fire_dir
            elif proj.has_method("set_direction"):
                proj.set_direction(fire_dir)
    
    # In phase 3, also shoot a homing projectile
    if phase >= 3 and homing_scene:
        await get_tree().create_timer(0.2).timeout
        if is_dead or not is_instance_valid(self):
            return
        var homing = homing_scene.instantiate()
        get_parent().add_child(homing)
        homing.global_position = global_position + Vector2(15.0 * dir, -15.0)
        if "direction" in homing:
            homing.direction = Vector2(dir, 0)

    await get_tree().create_timer(0.3).timeout
    if is_dead or not is_instance_valid(self):
        return
    is_acting = false
    _play("idle")

func _slam_attack() -> void:
    is_acting = true
    attack_timer = attack_cooldown * 2.0
    
    # Telegraph before jumping
    _telegraph_attack()
    await get_tree().create_timer(0.25).timeout
    if is_dead or not is_instance_valid(self):
        return
    
    is_slamming = true
    velocity.y = slam_jump_velocity
    # Future: play "plunge" animation here when added
    # _play("plunge")

func _slam_impact() -> void:
    is_acting = false
    ScreenEffects.shake(2.0, 0.15)
    
    # Shockwave effect - damage all players in radius
    var slam_pos = global_position
    var players = get_tree().get_nodes_in_group("player")
    for p in players:
        if p.has_method("take_damage") and not p.is_dead:
            var dist_to_player = slam_pos.distance_to(p.global_position)
            if dist_to_player <= SLAM_DAMAGE_RADIUS:
                p.take_damage(2)
    
    # Visual shockwave indicator
    _spawn_shockwave()
    
    await get_tree().create_timer(0.3).timeout
    if is_dead or not is_instance_valid(self):
        return
    _play("idle")

func _spawn_shockwave() -> void:
    # Create a visual ring effect for the shockwave using pre-generated texture
    var ring = Sprite2D.new()
    ring.modulate = Color(1, 0.3, 0.3, 0.8)
    ring.scale = Vector2(0.1, 0.1)
    ring.global_position = global_position
    ring.z_index = -1
    ring.texture = _shockwave_texture
    get_parent().add_child(ring)
    
    var tween = create_tween()
    tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.3)
    tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
    tween.tween_callback(ring.queue_free)

# --- BLOCK ---

func _block() -> void:
    if is_acting or is_dead:
        return
    is_acting = true
    is_blocking = true
    velocity.x = 0
    _play("block")
    # Future: swap to "shield" animation when added
    # _play("shield")
    await get_tree().create_timer(1.0).timeout
    if is_dead or not is_instance_valid(self):
        return
    is_blocking = false
    is_acting = false
    _play("idle")

# --- DAMAGE & DEATH ---

func take_hit(damage: int, source_type: String = "melee") -> void:
    if is_dead:
        return

    # Chance to block if not already busy
    if not is_acting and randf() < block_chance:
        _block()
        return

    # If currently blocking, negate all damage
    if is_blocking:
        return

    # Apply resistance
    var resistance: float = melee_resistance if source_type == "melee" else ranged_resistance
    var actual_damage: int = max(1, int(damage * (1.0 - resistance)))
    health -= actual_damage
    ScreenEffects.spawn_damage_number(global_position, actual_damage, Color.WHITE)

    # Track damage by type for adaptation
    if source_type == "melee":
        damage_from_melee += actual_damage
    else:
        damage_from_distance += actual_damage

    # Adapt after threshold
    if damage_from_melee >= adaptation_threshold:
        melee_resistance = min(melee_resistance + 0.12, 0.5)
        damage_from_melee = 0
        _adaptation_effect()

    if damage_from_distance >= adaptation_threshold:
        ranged_resistance = min(ranged_resistance + 0.12, 0.5)
        damage_from_distance = 0
        _adaptation_effect()

    # White flash on hit
    sprite.modulate = Color(3, 3, 3)
    var flash_tw = create_tween()
    flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

    # Scale pop on hit — kill previous tween to prevent compounding
    if pop_tween and pop_tween.is_valid():
        pop_tween.kill()
        sprite.scale = base_sprite_scale  # Reset before starting new pop
    pop_tween = create_tween()
    pop_tween.tween_property(sprite, "scale", base_sprite_scale * 1.15, 0.05)
    pop_tween.tween_property(sprite, "scale", base_sprite_scale, 0.1).set_ease(Tween.EASE_OUT)

    # Phase transitions
    _check_phase()

    if health <= 0:
        die()

func _check_phase() -> void:
    var hp_percent: float = float(health) / float(scaled_max_health)
    
    # At 50% HP: boost resistance and summon backup
    if hp_percent <= 0.5 and not has_summoned_backup:
        has_summoned_backup = true
        _summon_backup()
        # Boost resistances
        melee_resistance = min(melee_resistance + 0.1, 0.5)
        ranged_resistance = min(ranged_resistance + 0.1, 0.5)
    
    if hp_percent <= 0.3 and phase < 3:
        phase = 3
        current_speed = SPEED_PHASE3
        attack_cooldown = 1.65
        block_chance = 0.22
        _phase_transition_effect(3)
    elif hp_percent <= 0.6 and phase < 2:
        phase = 2
        current_speed = SPEED_PHASE2
        attack_cooldown = 2.1
        _phase_transition_effect(2)

func _summon_backup() -> void:
    # Summon a Summoner beside the boss
    if summoner_scene:
        var summoner = summoner_scene.instantiate()
        # Use call_deferred to avoid state change during physics
        get_parent().call_deferred("add_child", summoner)
        # Spawn to the side of the boss
        var spawn_offset = 60 if sprite.flip_h else -60
        summoner.set_deferred("global_position", global_position + Vector2(spawn_offset, 0))
        # Visual effect
        ScreenEffects.shake(2.0, 0.15)
        # Flash effect on summoner spawn
        var flash_tween = create_tween().set_loops(3)
        flash_tween.tween_property(sprite, "modulate", Color(1, 0, 1), 0.1)
        flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _adaptation_effect() -> void:
    _play("adapt")
    # Mahoraga wheel spin: rapid color cycling
    var tween: Tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(0.5, 0, 1), 0.15)
    tween.tween_property(sprite, "modulate", Color(1, 1, 0), 0.15)
    tween.tween_property(sprite, "modulate", Color(0, 1, 1), 0.15)
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func _phase_transition_effect(new_phase: int) -> void:
    # Dramatic phase transition
    ScreenEffects.shake(1.5, 0.2)
    ScreenEffects.hit_freeze(0.08)
    
    # Color based on phase
    var phase_color: Color = Color.ORANGE if new_phase == 2 else Color.RED
    
    var tween: Tween = create_tween().set_loops(4)
    tween.tween_property(sprite, "modulate", phase_color, 0.1)
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
    
    # Scale pulse
    var scale_tween = create_tween()
    scale_tween.tween_property(sprite, "scale", base_sprite_scale * 1.3, 0.15)
    scale_tween.tween_property(sprite, "scale", base_sprite_scale, 0.2).set_ease(Tween.EASE_OUT)

func die() -> void:
    is_dead = true
    velocity = Vector2.ZERO
    PlayerData.boss_defeated = true
    SaveManager.save_game()
    boss_defeated.emit()
    AchievementManager.check_and_unlock("boss_slayer")
    ScreenEffects.shake(3.0, 0.2)
    ScreenEffects.hit_freeze(0.06)
    _play("death")
    # Wait for death animation to finish, then fade out
    await get_tree().create_timer(2.0).timeout
    if not is_instance_valid(self):
        return
    var tween = create_tween()
    tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
    tween.tween_callback(queue_free)

func get_health_percent() -> float:
    return float(health) / float(scaled_max_health)

# --- HELPER: safe animation player ---
func _play(anim_name: String) -> void:
    if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
        if sprite.animation != anim_name:
            sprite.play(anim_name)
    else:
        # Fallback: if animation doesn't exist yet, don't crash
        pass

# --- HELPER: telegraph attack with visual warning ---
func _telegraph_attack() -> void:
    if telegraph_tween and telegraph_tween.is_valid():
        telegraph_tween.kill()
    telegraph_tween = create_tween()
    telegraph_tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.08)
    telegraph_tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)
