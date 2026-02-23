# boss.gd — Final Guardian of the Trial (Mahoraga-inspired adaptive boss)
# Animations used: idle, run, attack, charge, fire, block, adapt, death
# Future animations (add later): plunge, shield
extends CharacterBody2D

signal boss_defeated

# --- Stats ---
const MAX_HEALTH: int = 30
var health: int = MAX_HEALTH
var scaled_max_health: int = MAX_HEALTH  # Actual max after NG+ scaling
var is_dead: bool = false

# --- Mahoraga Adaptation System ---
var damage_from_melee: int = 0
var damage_from_distance: int = 0
var adaptation_threshold: int = 5
var melee_resistance: float = 0.0
var ranged_resistance: float = 0.0
var phase: int = 1  # 1 = slow, 2 = faster, 3 = aggressive

# --- Movement ---
var direction: int = -1
const ACTIVATION_RANGE: float = 250.0  # Boss only engages when player is within this range
var is_activated: bool = false
const SPEED_PHASE1: float = 40.0
const SPEED_PHASE2: float = 60.0
const SPEED_PHASE3: float = 80.0
var current_speed: float = SPEED_PHASE1

# --- Action State ---
var is_acting: bool = false  # True when attacking/blocking/adapting
var attack_cooldown: float = 2.0
var attack_timer: float = 0.0
var player_ref: CharacterBody2D = null
var gravity: float = 800.0

# --- Charge Attack (Phase 2+) ---
var is_charging: bool = false
var charge_speed: float = 200.0
var charge_duration: float = 0.5
var charge_timer: float = 0.0

# --- Slam Attack (Phase 3) ---
var is_slamming: bool = false
var slam_jump_velocity: float = -300.0

# --- Block ---
var is_blocking: bool = false
var block_chance: float = 0.3  # 30% chance to block incoming damage

# --- Hit Effect ---
var base_sprite_scale: Vector2 = Vector2.ONE
var pop_tween: Tween = null

# --- Ranged Attack ---
@export var projectile_scene: PackedScene  # Drag fireball.tscn here in Inspector

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

func _ready() -> void:
    add_to_group("enemy")
    # Scale boss HP with NG+ level
    health = int(MAX_HEALTH * PlayerData.get_enemy_hp_multiplier())
    scaled_max_health = health
    if attack_collision:
        attack_collision.disabled = true
    # Store original sprite scale so hit effects can pop and return correctly
    base_sprite_scale = sprite.scale
    # Find the player
    await get_tree().process_frame
    var players: Array[Node] = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        player_ref = players[0]
    # Do NOT show HP bar yet - wait until boss is activated
    # Start idle animation
    _play("idle")

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    # Gravity
    if not is_on_floor():
        velocity.y += gravity * delta

    attack_timer -= delta

    if player_ref and not player_ref.is_dead:
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
                    attack_area.scale.x = dir_to_player

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
        if is_acting:
            velocity.x = move_toward(velocity.x, 0, 200.0 * delta)
            move_and_slide()
            return

        # --- Phase-based AI ---
        if dist < 30 and attack_timer <= 0:
            _melee_attack()
        elif phase >= 2 and dist > 150 and attack_timer <= 0:
            _ranged_attack(dir_to_player)
        elif phase >= 2 and dist > 60 and dist < 150 and attack_timer <= 0:
            _charge_attack(dir_to_player)
        elif phase >= 3 and dist > 40 and attack_timer <= 0 and is_on_floor():
            _slam_attack()
        else:
            # Walk toward player
            velocity.x = dir_to_player * current_speed
            _play("run")
    else:
        velocity.x = 0
        _play("idle")

    move_and_slide()

# --- ATTACKS ---

func _melee_attack() -> void:
    is_acting = true
    velocity.x = 0
    attack_timer = attack_cooldown
    _play("attack")

    if attack_collision:
        attack_collision.disabled = false

    # Use timer fallback in case animation_finished doesn't fire
    var anim_timeout = get_tree().create_timer(0.6)
    sprite.animation_finished.connect(func(): pass, CONNECT_ONE_SHOT)
    await anim_timeout.timeout
    if is_dead or not is_instance_valid(self):
        return

    # Deal damage at end of animation
    if attack_area:
        for body in attack_area.get_overlapping_bodies():
            if body.is_in_group("player") and body.has_method("take_damage"):
                body.take_damage(1)

    if attack_collision:
        attack_collision.disabled = true
    is_acting = false
    _play("idle")

func _charge_attack(dir: int) -> void:
    is_acting = true
    is_charging = true
    direction = dir
    charge_timer = charge_duration
    attack_timer = attack_cooldown * 1.5
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

    # Spawn projectile
    if projectile_scene:
        var proj: Node2D = projectile_scene.instantiate()
        get_parent().add_child(proj)
        proj.global_position = global_position + Vector2(20.0 * dir, -10.0)
        if proj.has_method("set_direction"):
            proj.set_direction(dir)
        elif "shoot_direction" in proj:
            proj.shoot_direction = Vector2(dir, 0)

    await get_tree().create_timer(0.5).timeout
    if is_dead or not is_instance_valid(self):
        return
    is_acting = false
    _play("idle")

func _slam_attack() -> void:
    is_acting = true
    is_slamming = true
    velocity.y = slam_jump_velocity
    attack_timer = attack_cooldown * 2.0
    # Future: play "plunge" animation here when added
    # _play("plunge")

func _slam_impact() -> void:
    is_acting = false
    if attack_collision:
        attack_collision.disabled = false
    if attack_area:
        for body in attack_area.get_overlapping_bodies():
            if body.is_in_group("player") and body.has_method("take_damage"):
                body.take_damage(2)
    await get_tree().create_timer(0.2).timeout
    if is_dead or not is_instance_valid(self):
        return
    if attack_collision:
        attack_collision.disabled = true
    _play("idle")

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
        melee_resistance = min(melee_resistance + 0.25, 0.75)
        damage_from_melee = 0
        _adaptation_effect()

    if damage_from_distance >= adaptation_threshold:
        ranged_resistance = min(ranged_resistance + 0.25, 0.75)
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
    if hp_percent <= 0.3 and phase < 3:
        phase = 3
        current_speed = SPEED_PHASE3
        attack_cooldown = 1.0
        _phase_transition_effect()
    elif hp_percent <= 0.6 and phase < 2:
        phase = 2
        current_speed = SPEED_PHASE2
        attack_cooldown = 1.5
        _phase_transition_effect()

func _adaptation_effect() -> void:
    _play("adapt")
    # Mahoraga wheel spin: rapid color cycling
    var tween: Tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(0.5, 0, 1), 0.15)
    tween.tween_property(sprite, "modulate", Color(1, 1, 0), 0.15)
    tween.tween_property(sprite, "modulate", Color(0, 1, 1), 0.15)
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)

func _phase_transition_effect() -> void:
    var tween: Tween = create_tween().set_loops(3)
    tween.tween_property(sprite, "modulate", Color(1, 0, 0), 0.1)
    tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func die() -> void:
    is_dead = true
    velocity = Vector2.ZERO
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
