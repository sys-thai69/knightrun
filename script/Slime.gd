extends Node2D

const SPEED = 60.0
const COIN_DROP = 2
var direction = 1  # 1 = Right, -1 = Left
var health: int = 2
var is_dead: bool = false

@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_down: RayCast2D = $RayCastDown
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _process(delta: float) -> void:
    if is_dead:
        return
    if ray_cast_right.is_colliding():
        direction = -1
        sprite.flip_h = true
    if ray_cast_down.is_colliding() == false:
        direction = 1
        sprite.flip_h = false

    position.x += direction * SPEED * delta

func take_hit(damage: int, _source_type: String = "melee") -> void:
    if is_dead:
        return
    health -= damage
    # Flash white on hit
    sprite.modulate = Color.RED
    get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color.WHITE)
    if health <= 0:
        die()

func die() -> void:
    is_dead = true
    PlayerData.add_coins(COIN_DROP)
    # Death effect: shrink and fade
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
    tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
    tween.chain().tween_callback(queue_free)
