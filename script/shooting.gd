extends Area2D
const FIREBALL_SCENE = preload("res://enemy/fireball.tscn")
@onready var fire_timer: Timer = $FireTimer
@onready var timer: Timer = $Timer
@onready var muzzle_node: Marker2D = $Marker2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@export var shoot_direction: Vector2 = Vector2.LEFT

var health: int = 3
var is_dead: bool = false
const COIN_DROP = 3

func _on_animated_sprite_2d_animation_finished() -> void:
    animated_sprite_2d.animation_finished.disconnect(_on_animated_sprite_2d_animation_finished)
    animated_sprite_2d.play("idle")

func _ready():
    animated_sprite_2d.play("idle")
    fire_timer.start()
    if shoot_direction.x > 0:
        animated_sprite_2d.flip_h = false
    elif shoot_direction.x < 0:
        animated_sprite_2d.flip_h = true

func _on_fire_timer_timeout():
    if is_dead:
        return
    animated_sprite_2d.play("shooting")
    var fireball = FIREBALL_SCENE.instantiate()
    get_parent().add_child(fireball)
    fireball.global_position = muzzle_node.global_position
    fireball.direction = shoot_direction
    if not animated_sprite_2d.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
        animated_sprite_2d.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
    fire_timer.start()

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    if body.has_method("take_damage"):
        body.take_damage(1)
    else:
        # Fallback: old death behavior
        body.is_dead = true

func take_hit(damage: int, _source_type: String = "melee") -> void:
    if is_dead:
        return
    health -= damage
    animated_sprite_2d.modulate = Color.RED
    get_tree().create_timer(0.1).timeout.connect(func(): animated_sprite_2d.modulate = Color.WHITE)
    if health <= 0:
        die()

func die() -> void:
    is_dead = true
    fire_timer.stop()
    PlayerData.add_coins(COIN_DROP)
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(animated_sprite_2d, "modulate:a", 0.0, 0.3)
    tween.tween_property(animated_sprite_2d, "scale", Vector2.ZERO, 0.3)
    tween.chain().tween_callback(queue_free)
