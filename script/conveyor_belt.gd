# conveyor_belt.gd — Pushes player left or right while standing on it
# IMAGE KEYWORD: "pixel art conveyor belt animated sprite sheet 32x8"
extends Node2D

@export var belt_speed: float = 60.0  # Pixels per second
@export var belt_direction: int = 1   # 1 = right, -1 = left

var bodies_on_belt: Array[CharacterBody2D] = []

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
		sprite.play("move")
		sprite.flip_h = belt_direction < 0

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	# Gray belt
	draw_rect(Rect2(-24, -4, 48, 8), Color(0.4, 0.4, 0.5))
	# Direction arrows
	var arrow_color = Color(0.7, 0.7, 0.8)
	for i in range(-2, 3):
		var x = i * 10.0
		var dx = 3.0 * belt_direction
		draw_line(Vector2(x, 0), Vector2(x + dx, -2), arrow_color, 1.5)
		draw_line(Vector2(x, 0), Vector2(x + dx, 2), arrow_color, 1.5)
	draw_rect(Rect2(-24, -4, 48, 8), Color.BLACK, false, 1.0)

func _physics_process(_delta: float) -> void:
	for body in bodies_on_belt:
		if is_instance_valid(body) and body.is_on_floor():
			# Apply strong enough force to be noticeable over player's movement
			body.velocity.x += belt_direction * belt_speed * _delta * 10.0

func _on_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		bodies_on_belt.append(body)

func _on_area_body_exited(body: Node2D) -> void:
	if body in bodies_on_belt:
		bodies_on_belt.erase(body)
