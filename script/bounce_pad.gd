# bounce_pad.gd — Launches the player upward when stepped on
# IMAGE KEYWORD: "pixel art spring bounce pad jump pad sprite sheet 16x16" or "pixel art mushroom trampoline"
extends Area2D

@export var bounce_force: float = -350.0  # Negative = upward
@export var animate_on_bounce: bool = true

@onready var sprite: Sprite2D = $Sprite2D

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	# Green spring pad
	draw_rect(Rect2(-8, -3, 16, 6), Color(0.2, 0.8, 0.2))
	# Spring coil lines
	draw_line(Vector2(-5, 0), Vector2(-3, -2), Color(0.1, 0.5, 0.1), 1.5)
	draw_line(Vector2(-3, -2), Vector2(-1, 0), Color(0.1, 0.5, 0.1), 1.5)
	draw_line(Vector2(1, 0), Vector2(3, -2), Color(0.1, 0.5, 0.1), 1.5)
	draw_line(Vector2(3, -2), Vector2(5, 0), Color(0.1, 0.5, 0.1), 1.5)
	draw_rect(Rect2(-8, -3, 16, 6), Color.BLACK, false, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body is CharacterBody2D:
		body.velocity.y = bounce_force
		# Reset jump count so player can double-jump after bouncing
		if "jump_count" in body:
			body.jump_count = 0
		if animate_on_bounce and sprite:
			_bounce_animation()

func _bounce_animation() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "scale:y", 0.5, 0.05)
	tween.tween_property(sprite, "scale:y", 1.3, 0.1)
	tween.tween_property(sprite, "scale:y", 1.0, 0.1)
