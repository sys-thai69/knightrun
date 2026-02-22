# mud_block.gd — Muddy/tarry surface: player moves at half speed, jump weakened
# IMAGE KEYWORD: "pixel art mud tar swamp tile sprite 16x16 brown"
extends Area2D

## Speed multiplier when in mud (0.5 = half speed)
@export var speed_mult: float = 0.5
## Jump power multiplier when in mud
@export var jump_mult: float = 0.75
## Extra drag applied each frame
@export var sticky_drag: float = 0.1

var _bubble_timer: float = 0.0
var _players_in_mud: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	# Apply sticky drag and spawn bubbles
	_bubble_timer -= delta
	for body in _players_in_mud:
		if is_instance_valid(body) and body.is_in_group("player"):
			# Extra sticky drag
			body.velocity.x *= (1.0 - sticky_drag)
			# Spawn mud bubbles when moving
			if _bubble_timer <= 0 and abs(body.velocity.x) > 10:
				_spawn_mud_bubble(body.global_position)
				_bubble_timer = 0.3

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.on_mud = true
		_players_in_mud.append(body)
		# Immediate slowdown effect
		body.velocity.x *= 0.5
		ScreenEffects.spawn_text_popup(body.global_position, "Stuck!", Color(0.5, 0.35, 0.2))

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.on_mud = false
		_players_in_mud.erase(body)

func _spawn_mud_bubble(pos: Vector2) -> void:
	var p = Label.new()
	p.text = "o"
	p.add_theme_font_size_override("font_size", 5)
	p.add_theme_color_override("font_color", Color(0.45, 0.3, 0.15, 0.7))
	p.global_position = pos + Vector2(randf_range(-6, 6), randf_range(0, 4))
	p.z_index = 30
	get_tree().current_scene.add_child(p)
	var tw = p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "position:y", p.position.y - randf_range(8, 16), 0.4)
	tw.tween_property(p, "scale", Vector2(1.5, 1.5), 0.2)
	tw.chain().tween_property(p, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(p.queue_free)

# Placeholder visual
func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.35, 0.22, 0.1))
	# Bubbles
	draw_circle(Vector2(-3, -2), 1.5, Color(0.45, 0.3, 0.15))
	draw_circle(Vector2(3, 1), 1.0, Color(0.45, 0.3, 0.15))
	draw_circle(Vector2(0, 3), 1.2, Color(0.4, 0.26, 0.12))
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.2, 0.12, 0.05), false, 1.0)
