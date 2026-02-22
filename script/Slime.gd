# Slime.gd — Basic patrol enemy that walks back and forth on platforms
extends CharacterBody2D

const SPEED = 60.0
const COIN_DROP = 2
const GRAVITY_VAL = 600.0

var direction: int = 1  # 1 = Right, -1 = Left
var health: int = 2
var is_dead: bool = false
var _flip_cooldown: float = 0.0  # Prevents rapid direction flipping

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_wall: RayCast2D = $RayCastWall
@onready var ray_cast_floor: RayCast2D = $RayCastFloor

func _ready() -> void:
    add_to_group("enemy")
    # Scale HP with New Game+ level
    health = int(health * PlayerData.get_enemy_hp_multiplier())
    # Off-screen optimization
    var notifier = VisibleOnScreenNotifier2D.new()
    notifier.rect = Rect2(-20, -20, 40, 40)
    add_child(notifier)
    notifier.screen_exited.connect(func(): set_physics_process(false))
    notifier.screen_entered.connect(func(): set_physics_process(true))
    _update_raycast_direction()

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    # Apply gravity
    if not is_on_floor():
        velocity.y += GRAVITY_VAL * delta
    else:
        velocity.y = 0

    # Flip cooldown prevents direction oscillation
    if _flip_cooldown > 0.0:
        _flip_cooldown -= delta
    else:
        # Reverse if hitting a wall or about to walk off an edge
        var should_flip = false
        if ray_cast_wall.is_colliding():
            should_flip = true
        if is_on_floor() and not ray_cast_floor.is_colliding():
            should_flip = true

        if should_flip:
            direction *= -1
            sprite.flip_h = direction < 0
            _update_raycast_direction()
            _flip_cooldown = 0.15  # Ignore further flips for 150ms

    velocity.x = direction * SPEED
    move_and_slide()

func _update_raycast_direction() -> void:
    # Point the wall raycast in the movement direction
    if ray_cast_wall:
        ray_cast_wall.target_position = Vector2(direction * 10, 0)
    # Floor check stays slightly ahead in movement direction
    if ray_cast_floor:
        ray_cast_floor.target_position = Vector2(direction * 8, 16)

func take_hit(damage: int, _source_type: String = "melee") -> void:
    if is_dead:
        return
    health -= damage
    ScreenEffects.spawn_damage_number(global_position, damage, Color.WHITE)
    # White flash on hit (bright then fade back)
    sprite.modulate = Color(3, 3, 3)
    var flash_tw = create_tween()
    flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
    # Scale pop
    var pop_tw = create_tween()
    pop_tw.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.05)
    pop_tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
    # Knockback away from attacker (uses velocity, not raw position)
    var player = get_tree().get_first_node_in_group("player")
    if player:
        var kb_dir = sign(global_position.x - player.global_position.x)
        if kb_dir == 0:
            kb_dir = 1
        velocity.x = kb_dir * 120  # Physics-safe knockback
    if health <= 0:
        die()

func die() -> void:
    is_dead = true
    velocity = Vector2.ZERO
    PlayerData.add_coins(COIN_DROP)
    ScreenEffects.spawn_coin_text(global_position, COIN_DROP)
    AchievementManager.check_and_unlock("first_kill")
    AchievementManager.check_coin_achievements()
    _spawn_death_particles()
    # Disable collision so dead slime doesn't block
    set_physics_process(false)
    # Death effect: shrink and fade
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
    tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
    tween.chain().tween_callback(queue_free)

func _spawn_death_particles() -> void:
    for i in range(6):
        var p = Label.new()
        p.text = "*"
        p.add_theme_font_size_override("font_size", 8)
        p.add_theme_color_override("font_color", Color.GREEN_YELLOW)
        p.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
        p.z_index = 50
        get_parent().add_child(p)
        var tw = p.create_tween()
        tw.set_parallel(true)
        tw.tween_property(p, "position", p.position + Vector2(randf_range(-20, 20), randf_range(-30, -10)), 0.4)
        tw.tween_property(p, "modulate:a", 0.0, 0.4)
        tw.chain().tween_callback(p.queue_free)
