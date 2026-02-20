# screen_effects.gd — Autoload for screen shake, hit freeze, and floating damage numbers
extends Node

# --- Screen Shake ---
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var camera_ref: Camera2D = null

# --- Hit Freeze ---
var freeze_timer: float = 0.0

func _process(delta: float) -> void:
	# Hit freeze
	if freeze_timer > 0:
		freeze_timer -= delta / Engine.time_scale if Engine.time_scale > 0 else delta
		if freeze_timer <= 0:
			Engine.time_scale = 1.0

	# Screen shake
	if shake_timer > 0 and camera_ref:
		shake_timer -= delta
		var offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		camera_ref.offset = offset
		if shake_timer <= 0:
			camera_ref.offset = Vector2.ZERO

func register_camera(cam: Camera2D) -> void:
	camera_ref = cam

func shake(intensity: float = 4.0, duration: float = 0.2) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration

func hit_freeze(duration: float = 0.05) -> void:
	Engine.time_scale = 0.05
	freeze_timer = duration

func spawn_damage_number(pos: Vector2, damage: int, color: Color = Color.WHITE) -> void:
	# Create a floating damage number at the given world position
	var label = Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.z_index = 100
	label.global_position = pos - Vector2(10, 20)

	# We need to add it to the current scene tree
	var scene_root = get_tree().current_scene
	if scene_root:
		scene_root.add_child(label)
	else:
		return

	# Animate: float up and fade out
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)
