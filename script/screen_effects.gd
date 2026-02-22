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

# --- Floating Text ---
const FloatingTextScript = preload("res://script/floating_text.gd")

func spawn_text_popup(pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	_create_floating_text(pos, text, color, 7)

func spawn_damage_number(pos: Vector2, damage: int, color: Color = Color.WHITE) -> void:
	_create_floating_text(pos, str(damage), color, 8)

func spawn_coin_text(pos: Vector2, amount: int) -> void:
	_create_floating_text(pos, "+" + str(amount), Color.GOLD, 8)

func _create_floating_text(pos: Vector2, text: String, color: Color, size: int) -> void:
	var scene_root = get_tree().current_scene
	if not scene_root:
		return
	var node = Node2D.new()
	node.set_script(FloatingTextScript)
	node.display_text = text
	node.text_color = color
	node.font_size = size
	node.global_position = pos + Vector2(0, -8)
	node.z_index = 100
	scene_root.add_child(node)
