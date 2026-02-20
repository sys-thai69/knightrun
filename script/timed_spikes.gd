# timed_spikes.gd — Spikes that retract/extend on a timer
# IMAGE KEYWORD: "pixel art retractable spikes trap animation sprite sheet 16x16"
extends Node2D

@export var extend_time: float = 2.0    # Time spikes are up
@export var retract_time: float = 1.5   # Time spikes are down
@export var start_extended: bool = true

var is_extended: bool = true
var timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $KillArea/CollisionShape2D

func _ready() -> void:
	is_extended = start_extended
	timer = extend_time if is_extended else retract_time
	_update_visuals()

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	if is_extended:
		# Red spikes pointing up
		draw_rect(Rect2(-8, -6, 16, 12), Color(0.85, 0.15, 0.15))
		# Spike points
		var spike_color = Color(0.95, 0.25, 0.25)
		draw_rect(Rect2(-6, -9, 4, 3), spike_color)
		draw_rect(Rect2(2, -9, 4, 3), spike_color)
	else:
		# Retracted: flat gray
		draw_rect(Rect2(-8, 2, 16, 4), Color(0.4, 0.3, 0.3))
	draw_rect(Rect2(-8, -6, 16, 12), Color.BLACK, false, 1.0)

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		is_extended = not is_extended
		timer = extend_time if is_extended else retract_time
		_update_visuals()
		queue_redraw()

		# Warning flash before extending
		if is_extended:
			ScreenEffects.shake(1.0, 0.05)

func _update_visuals() -> void:
	if is_extended:
		sprite.modulate = Color(1, 1, 1, 1)
		collision.set_deferred("disabled", false)
		# Pop up animation
		var tween = create_tween()
		sprite.scale.y = 0
		tween.tween_property(sprite, "scale:y", 1.0, 0.1)
	else:
		collision.set_deferred("disabled", true)
		# Retract animation
		var tween = create_tween()
		tween.tween_property(sprite, "scale:y", 0.0, 0.15)
		tween.tween_property(sprite, "modulate:a", 0.3, 0.1)

func _on_kill_area_body_entered(body: Node2D) -> void:
	if is_extended and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
