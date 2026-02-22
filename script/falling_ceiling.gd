# falling_ceiling.gd — A ceiling block that falls when the player walks under it.
# DAMAGES the player if it lands on them!
# IMAGE KEYWORD: "pixel art falling stone ceiling trap block sprite 16x16"
extends Node2D

## How fast the ceiling falls (pixels/sec)
@export var fall_speed: float = 300.0
## Damage dealt to player on hit
@export var damage: int = 1
## Time before the ceiling resets (0 = never resets)
@export var reset_time: float = 3.0

enum State { IDLE, SHAKING, FALLING, LANDED }

var state: int = State.IDLE
var _shake_timer: float = 0.0
var _start_position: Vector2
var _body: StaticBody2D
var _hit_area: Area2D

const SHAKE_DURATION = 0.5

func _ready() -> void:
	_start_position = position

	# Create the solid body (blocks the player after landing)
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var body_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	body_shape.shape = rect
	_body.add_child(body_shape)
	add_child(_body)

	# Create the hit detection area
	_hit_area = Area2D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 2
	var hit_shape = CollisionShape2D.new()
	var hit_rect = RectangleShape2D.new()
	hit_rect.size = Vector2(14, 14)
	hit_shape.shape = hit_rect
	_hit_area.add_child(hit_shape)
	add_child(_hit_area)
	_hit_area.body_entered.connect(_on_hit_body)

	# Trigger zone — wider area below the ceiling to detect when player walks under
	var trigger = Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	var trigger_shape = CollisionShape2D.new()
	var trigger_rect = RectangleShape2D.new()
	trigger_rect.size = Vector2(16, 80)
	trigger_shape.shape = trigger_rect
	trigger_shape.position = Vector2(0, 48)  # Below the ceiling block
	trigger.add_child(trigger_shape)
	add_child(trigger)
	trigger.body_entered.connect(_on_trigger_entered)

# Placeholder visual
func _draw() -> void:
	# Stone ceiling block
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.45, 0.4, 0.35))
	# Crack lines
	draw_line(Vector2(-4, -6), Vector2(0, -2), Color(0.3, 0.25, 0.2), 1.0)
	draw_line(Vector2(0, -2), Vector2(3, 0), Color(0.3, 0.25, 0.2), 1.0)
	draw_line(Vector2(2, 3), Vector2(5, 6), Color(0.3, 0.25, 0.2), 1.0)
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.25, 0.2, 0.15), false, 1.0)
	# Warning indicator (small red triangle at bottom)
	if state == State.IDLE:
		draw_line(Vector2(-2, 7), Vector2(0, 4), Color(1.0, 0.3, 0.3, 0.5), 1.0)
		draw_line(Vector2(0, 4), Vector2(2, 7), Color(1.0, 0.3, 0.3, 0.5), 1.0)

func _on_trigger_entered(body: Node2D) -> void:
	if body.is_in_group("player") and state == State.IDLE:
		state = State.SHAKING
		_shake_timer = 0.0

func _physics_process(delta: float) -> void:
	match state:
		State.SHAKING:
			_shake_timer += delta
			# Shake effect
			position.x = _start_position.x + sin(_shake_timer * 60) * 1.5
			if _shake_timer >= SHAKE_DURATION:
				position.x = _start_position.x
				state = State.FALLING
		State.FALLING:
			position.y += fall_speed * delta
			# Check if we've fallen far enough (hit the floor or max distance)
			if position.y - _start_position.y > 200:
				_land()
		State.LANDED:
			pass  # Static until reset

func _on_hit_body(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		if state == State.FALLING:
			body.take_damage(damage)
			# Small screen shake on impact
			ScreenEffects.shake(3.0, 0.15)
			_land()

func _land() -> void:
	state = State.LANDED
	# Small impact dust visual
	_spawn_dust()
	if reset_time > 0:
		var timer = Timer.new()
		timer.wait_time = reset_time
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_reset)
		timer.start()

func _reset() -> void:
	state = State.IDLE
	var tw = create_tween()
	tw.tween_property(self, "position", _start_position, 0.5).set_ease(Tween.EASE_OUT)

func _spawn_dust() -> void:
	for i in range(4):
		var p = Label.new()
		p.text = "."
		p.add_theme_font_size_override("font_size", 6)
		p.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
		p.global_position = global_position + Vector2(randf_range(-8, 8), 6)
		p.z_index = 50
		get_parent().add_child(p)
		var tw = p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector2(randf_range(-12, 12), randf_range(-8, -2)), 0.3)
		tw.tween_property(p, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(p.queue_free)
