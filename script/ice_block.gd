# ice_block.gd — Icy surface: player slides with heavy momentum, can't stop instantly
extends Area2D

## Preserves some velocity when entering ice
@export var momentum_boost: float = 1.2
@export var combo_grace_time: float = 0.2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.on_ice = true
		body.velocity.x *= momentum_boost
		body.set_meta("ice_combo_until", Time.get_ticks_msec() + int(combo_grace_time * 1000.0))

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.on_ice = false
		body.set_meta("ice_combo_until", Time.get_ticks_msec() + int(combo_grace_time * 1000.0))

# Simple transparent ice visual
func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.4, 0.7, 1.0, 0.5))
