# destructible_wall.gd — Breakable wall that hides secret areas
# IMAGE KEYWORD: "pixel art breakable cracked wall bricks sprite 32x32"
extends StaticBody2D

@export var hits_to_break: int = 3
@export var coin_reward: int = 3

var current_hits: int = 0
var is_broken: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	if is_broken:
		return
	var crack_ratio = float(current_hits) / float(hits_to_break)
	var color = Color(0.45, 0.3, 0.2).lerp(Color(0.7, 0.3, 0.2), crack_ratio)
	draw_rect(Rect2(-8, -16, 16, 32), color)
	# Brick pattern
	draw_line(Vector2(-8, -8), Vector2(8, -8), Color.BLACK, 1.0)
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color.BLACK, 1.0)
	draw_line(Vector2(-8, 8), Vector2(8, 8), Color.BLACK, 1.0)
	draw_line(Vector2(0, -16), Vector2(0, -8), Color.BLACK, 1.0)
	draw_line(Vector2(-4, -8), Vector2(-4, 0), Color.BLACK, 1.0)
	draw_line(Vector2(4, 0), Vector2(4, 8), Color.BLACK, 1.0)
	draw_rect(Rect2(-8, -16, 16, 32), Color.BLACK, false, 1.0)

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_broken:
		return
	current_hits += damage
	# Crack effect
	var crack_ratio = float(current_hits) / float(hits_to_break)
	sprite.modulate = Color(1, 1 - crack_ratio * 0.5, 1 - crack_ratio * 0.5)
	# Shake
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x + 2, 0.03)
	tween.tween_property(self, "position:x", position.x - 2, 0.03)
	tween.tween_property(self, "position:x", position.x, 0.03)

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
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	tween.chain().tween_callback(queue_free)
