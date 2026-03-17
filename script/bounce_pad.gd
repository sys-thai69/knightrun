# bounce_pad.gd — Launches the player upward when stepped on
extends Area2D

@export var bounce_force: float = -350.0  # Negative = upward
@export var animate_on_bounce: bool = true

@onready var sprite: Sprite2D = $Sprite2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body is CharacterBody2D:
		var bounce_mult = 1.0
		# Boost bounce height if player is on ice
		if body.on_ice:
			bounce_mult = 1.8  # 80% higher bounce on ice
		body.velocity.y = bounce_force * bounce_mult
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
