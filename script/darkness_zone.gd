# darkness_zone.gd — Overlays darkness on the screen. Player gets a small glow radius.
# Place this Area2D over any section of the level to make it dark.
# IMAGE KEYWORD: "pixel art darkness fog shadow overlay tile sprite 16x16"
extends Area2D

## Radius of the player's glow (in pixels)
@export var glow_radius: float = 48.0
## Darkness opacity (0 = transparent, 1 = fully black)
@export var darkness_alpha: float = 0.92

var _light: PointLight2D = null
var _canvas_mod: CanvasModulate = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_enable_darkness(body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_disable_darkness(body)

func _enable_darkness(player: Node2D) -> void:
	# Add a CanvasModulate to darken everything
	if not _canvas_mod:
		_canvas_mod = CanvasModulate.new()
		_canvas_mod.color = Color(darkness_alpha * 0.08, darkness_alpha * 0.08, darkness_alpha * 0.12)
		get_tree().current_scene.add_child(_canvas_mod)

	# Add a PointLight2D to the player ONLY if they have a torch
	if not _light and player and "has_torch" in player and player.has_torch:
		_light = PointLight2D.new()
		_light.energy = 1.5
		_light.texture_scale = glow_radius / 64.0
		# Create a simple gradient texture for the light
		var grad_tex = GradientTexture2D.new()
		grad_tex.width = 128
		grad_tex.height = 128
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		grad_tex.fill_from = Vector2(0.5, 0.5)
		grad_tex.fill_to = Vector2(0.5, 0.0)
		var grad = Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad_tex.gradient = grad
		_light.texture = grad_tex
		_light.color = Color(1.0, 0.9, 0.7)
		player.add_child(_light)

func _disable_darkness(_player: Node2D) -> void:
	if _canvas_mod and is_instance_valid(_canvas_mod):
		_canvas_mod.queue_free()
		_canvas_mod = null
	if _light and is_instance_valid(_light):
		_light.queue_free()
		_light = null

# Placeholder visual — a dark overlay square
func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.05, 0.05, 0.1, 0.8))
	# Eye symbol
	draw_arc(Vector2(0, 0), 3.0, 0, PI, 8, Color(0.5, 0.3, 0.8, 0.6), 1.0)
	draw_circle(Vector2(0, 0), 1.0, Color(0.6, 0.4, 0.9, 0.6))
