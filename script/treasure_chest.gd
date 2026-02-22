# treasure_chest.gd — A real treasure chest that gives the player coins when opened
# IMAGE KEYWORD: "pixel art treasure chest open gold coins sprite sheet 32x32"
extends Area2D

@export var coin_reward: int = 10
@export var gives_health: bool = false
var is_opened: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_opened:
		return
	if not body.is_in_group("player"):
		return
	_open(body)

func _open(_player: Node2D) -> void:
	is_opened = true
	# Give coins
	PlayerData.add_coins(coin_reward)
	# Give health if configured
	if gives_health and PlayerData.current_health < PlayerData.max_health:
		PlayerData.heal(1)
	# Floating text
	ScreenEffects.spawn_damage_number(global_position + Vector2(0, -10), coin_reward, Color.GOLD)
	# Open animation: lid pops up and coins scatter
	queue_redraw()
	_spawn_coin_particles()
	# Fade out after opening
	var tw = create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

func _spawn_coin_particles() -> void:
	for i in range(5):
		var p = Label.new()
		p.text = "o"
		p.add_theme_font_size_override("font_size", 6)
		p.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		p.global_position = global_position + Vector2(randf_range(-4, 4), -4)
		p.z_index = 50
		get_parent().add_child(p)
		var tw = p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-16, 16), randf_range(-20, -8)), 0.4)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(p.queue_free)

# Placeholder visual
func _draw() -> void:
	if is_opened:
		# Open chest
		draw_rect(Rect2(-8, -2, 16, 10), Color(0.6, 0.4, 0.15))  # Body
		# Open lid (tilted)
		draw_rect(Rect2(-8, -10, 16, 8), Color(0.7, 0.5, 0.2))
		draw_rect(Rect2(-2, -7, 4, 4), Color(1.0, 0.85, 0.0))  # Lock (open)
	else:
		# Closed chest
		draw_rect(Rect2(-8, -7, 16, 14), Color(0.6, 0.4, 0.15))  # Body
		draw_rect(Rect2(-8, -7, 16, 6), Color(0.7, 0.5, 0.2))  # Lid
		draw_rect(Rect2(-2, -3, 4, 4), Color(1.0, 0.85, 0.0))  # Lock
	draw_rect(Rect2(-8, -7, 16, 14), Color(0.4, 0.25, 0.1), false, 1.0)  # Outline
