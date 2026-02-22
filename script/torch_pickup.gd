# torch_pickup.gd — Player picks up a torch to light dark areas. Disables sword while held.
# Press interact (E) near torch to pick up. Press E again to drop.
# IMAGE KEYWORD: "pixel art torch fire flame item pickup sprite 16x16"
extends Area2D

## Light radius of the torch when held by the player
@export var light_radius: float = 64.0

var _is_picked_up: bool = false
var _torch_light: PointLight2D = null
var _player_ref: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_ref = null

func _process(_delta: float) -> void:
	if _player_ref and Input.is_action_just_pressed("interact"):
		if not _is_picked_up:
			_pick_up()
		else:
			_drop()

func _pick_up() -> void:
	if not _player_ref:
		return
	_is_picked_up = true
	_player_ref.has_torch = true
	visible = false

	# Create torch light on player
	_torch_light = PointLight2D.new()
	_torch_light.energy = 1.8
	_torch_light.texture_scale = light_radius / 64.0
	_torch_light.color = Color(1.0, 0.75, 0.3)
	# Gradient texture for soft glow
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
	_torch_light.texture = grad_tex
	_player_ref.add_child(_torch_light)

func _drop() -> void:
	_is_picked_up = false
	if _player_ref:
		_player_ref.has_torch = false
	visible = true
	# Place torch at player position
	if _player_ref:
		global_position = _player_ref.global_position + Vector2(0, 4)
	# Remove light from player
	if _torch_light and is_instance_valid(_torch_light):
		_torch_light.queue_free()
		_torch_light = null

# Cleanup if this torch gets freed while player holds it
func _exit_tree() -> void:
	if _is_picked_up and _player_ref and is_instance_valid(_player_ref):
		_player_ref.has_torch = false
	if _torch_light and is_instance_valid(_torch_light):
		_torch_light.queue_free()

# Placeholder visual
func _draw() -> void:
	if _is_picked_up:
		return
	# Torch handle
	draw_rect(Rect2(-2, -2, 4, 12), Color(0.5, 0.3, 0.15))
	# Flame
	draw_circle(Vector2(0, -4), 3.0, Color(1.0, 0.6, 0.1))
	draw_circle(Vector2(0, -5), 2.0, Color(1.0, 0.9, 0.3))
	# Glow
	draw_circle(Vector2(0, -4), 5.0, Color(1.0, 0.5, 0.0, 0.2))
