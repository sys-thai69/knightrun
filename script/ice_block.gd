# ice_block.gd — Icy surface: player slides with heavy momentum, can't stop instantly
# IMAGE KEYWORD: "pixel art ice block frozen tile sprite 16x16 blue"
extends Area2D

## How slippery the ice is (lower = more slippery)
@export var friction: float = 5.0
## Preserves some velocity when entering ice
@export var momentum_boost: float = 1.2

var _particles_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	# Spawn ice skid particles occasionally when player is sliding
	_particles_timer -= delta
	if _particles_timer <= 0:
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and abs(body.velocity.x) > 50:
				_spawn_ice_particle(body.global_position)
				_particles_timer = 0.15
				break

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.on_ice = true
		# Boost momentum when sliding onto ice
		body.velocity.x *= momentum_boost

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.on_ice = false

func _spawn_ice_particle(pos: Vector2) -> void:
	var p = Label.new()
	p.text = "*"
	p.add_theme_font_size_override("font_size", 6)
	p.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.8))
	p.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-2, 2))
	p.z_index = 30
	get_tree().current_scene.add_child(p)
	var tw = p.create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "position:y", p.position.y + randf_range(5, 15), 0.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(p.queue_free)

# Placeholder visual
func _draw() -> void:
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.6, 0.85, 1.0))
	# Ice shine lines
	draw_line(Vector2(-4, -5), Vector2(0, -2), Color(1.0, 1.0, 1.0, 0.7), 1.0)
	draw_line(Vector2(2, -1), Vector2(4, 2), Color(1.0, 1.0, 1.0, 0.5), 1.0)
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.3, 0.6, 0.9), false, 1.0)
