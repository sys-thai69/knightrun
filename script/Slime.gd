extends Node2D

const SPEED = 60.0
const COIN_DROP = 2
var direction = 1  # 1 = Right, -1 = Left
var health: int = 2
var is_dead: bool = false

@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_down: RayCast2D = $RayCastDown
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    add_to_group("enemy")
    # Scale HP with New Game+ level
    health = int(health * PlayerData.get_enemy_hp_multiplier())

func _process(delta: float) -> void:
    if is_dead:
        return
    if ray_cast_right.is_colliding():
        direction *= -1
        sprite.flip_h = direction < 0
    if ray_cast_down.is_colliding() == false:
        direction *= -1
        sprite.flip_h = direction < 0

    position.x += direction * SPEED * delta

func take_hit(damage: int, _source_type: String = "melee") -> void:
    if is_dead:
        return
    health -= damage
    # White flash on hit (bright then fade back)
    sprite.modulate = Color(3, 3, 3)
    var flash_tw = create_tween()
    flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
    # Scale pop
    var pop_tw = create_tween()
    pop_tw.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.05)
    pop_tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
    # Knockback away from attacker
    var player = get_tree().get_first_node_in_group("player")
    if player:
        var kb_dir = sign(global_position.x - player.global_position.x)
        if kb_dir == 0:
            kb_dir = 1
        var kb_tw = create_tween()
        kb_tw.tween_property(self, "position:x", position.x + kb_dir * 12, 0.1).set_ease(Tween.EASE_OUT)
    if health <= 0:
        die()

func die() -> void:
    is_dead = true
    PlayerData.add_coins(COIN_DROP)
    AchievementManager.check_and_unlock("first_kill")
    AchievementManager.check_coin_achievements()
    _spawn_death_particles()
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
