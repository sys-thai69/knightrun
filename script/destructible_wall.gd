# destructible_wall.gd — Breakable wall that hides secret areas
# IMAGE KEYWORD: "pixel art breakable cracked wall bricks sprite 32x32"
extends StaticBody2D

@export var hits_to_break: int = 3
@export var coin_reward: int = 3

var current_hits: int = 0
var is_broken: bool = false
var _original_position: Vector2 = Vector2.ZERO

@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_original_position = position

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_broken:
		return
	current_hits += damage
	ScreenEffects.spawn_damage_number(global_position, damage, Color.ORANGE)
	# Crack color effect via modulate (affects _draw output)
	var crack_ratio = clampf(float(current_hits) / float(hits_to_break), 0.0, 1.0)
	modulate = Color(1, 1 - crack_ratio * 0.5, 1 - crack_ratio * 0.5)
	# Shake using stored original position to prevent drift
	var tween = create_tween()
	tween.tween_property(self, "position:x", _original_position.x + 2, 0.03)
	tween.tween_property(self, "position:x", _original_position.x - 2, 0.03)
	tween.tween_property(self, "position:x", _original_position.x, 0.03)

	if current_hits >= hits_to_break:
		_break()
	queue_redraw()

func _break() -> void:
	is_broken = true
	PlayerData.add_coins(coin_reward)
	ScreenEffects.shake(1.5, 0.1)
	# Break apart effect
	collision.set_deferred("disabled", true)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", scale * 1.2, 0.15)
	tween.chain().tween_callback(queue_free)
