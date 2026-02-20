# crumbling_platform.gd — Platform that breaks after player steps on it, then respawns
# IMAGE KEYWORD: "pixel art crumbling cracked platform breaking sprite sheet 32x8"
extends StaticBody2D

const CRUMBLE_DELAY = 0.5  # Time before platform breaks after stepping on
const RESPAWN_TIME = 3.0   # Time before platform comes back

var is_crumbling: bool = false
var original_position: Vector2

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	original_position = global_position

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	if not is_crumbling:
		draw_rect(Rect2(-16, -4, 32, 8), Color(0.55, 0.45, 0.33))
		# Crack lines
		draw_line(Vector2(-5, -2), Vector2(3, 2), Color(0.35, 0.25, 0.15), 1.0)
		draw_line(Vector2(8, -3), Vector2(12, 1), Color(0.35, 0.25, 0.15), 1.0)
		draw_rect(Rect2(-16, -4, 32, 8), Color.BLACK, false, 1.0)

func start_crumble() -> void:
	if is_crumbling:
		return
	is_crumbling = true
	queue_redraw()
	# Shake before falling
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x + 2, 0.05)
	tween.tween_property(self, "position:x", position.x - 2, 0.05)
	tween.tween_property(self, "position:x", position.x + 2, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)
	get_tree().create_timer(CRUMBLE_DELAY).timeout.connect(_crumble)

func _crumble() -> void:
	# Disable collision and hide
	collision.set_deferred("disabled", true)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "position:y", position.y + 10, 0.2)
	tween.chain().tween_callback(_start_respawn_timer)

func _start_respawn_timer() -> void:
	visible = false
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)

func _respawn() -> void:
	is_crumbling = false
	global_position = original_position
	collision.set_deferred("disabled", false)
	visible = true
	sprite.modulate.a = 1.0
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		start_crumble()
