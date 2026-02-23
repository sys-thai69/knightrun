# gate.gd — A gate/door that opens and closes, controlled by a pressure plate
# IMAGE KEYWORD: "pixel art gate door iron bars portcullis sprite 16x32"
extends StaticBody2D

var _is_open: bool = false
var _open_tween: Tween = null
var _closed_y: float = 0.0
## How far the gate moves up when opened (in pixels)
@export var open_offset: float = 32.0

@onready var collision: CollisionShape2D = $CollisionShape2D
var _crush_area: Area2D = null

func _ready() -> void:
    _closed_y = position.y
    # Create an Area2D to detect bodies inside the gate when closing
    _crush_area = Area2D.new()
    _crush_area.collision_layer = 0
    _crush_area.collision_mask = 2  # Detect player and enemies
    _crush_area.monitoring = true
    _crush_area.monitorable = false
    var shape_node = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(16, 32)  # Same as gate collision
    shape_node.shape = shape
    _crush_area.add_child(shape_node)
    add_child(_crush_area)

func open_gate() -> void:
    if _is_open:
        return
    _is_open = true
    if _open_tween:
        _open_tween.kill()
    _open_tween = create_tween()
    _open_tween.tween_property(self, "position:y", _closed_y - open_offset, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func close_gate() -> void:
    if not _is_open:
        return
    _is_open = false
    if _open_tween:
        _open_tween.kill()
    # Push any bodies out of the gate's closed position (synchronous)
    _push_bodies_out()
    # Disable collision during closing animation, re-enable when done
    collision.set_deferred("disabled", true)
    _open_tween = create_tween()
    _open_tween.tween_property(self, "position:y", _closed_y, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    _open_tween.tween_callback(func(): collision.set_deferred("disabled", false))

func _push_bodies_out() -> void:
    # Move crush area to the closed position to check for bodies there
    _crush_area.global_position = Vector2(global_position.x, _closed_y)
    # Check overlapping bodies at the closed position
    for body in _crush_area.get_overlapping_bodies():
        if body is CharacterBody2D:
            # Push body to the nearest side of the gate
            var gate_center_x = global_position.x
            if body.global_position.x < gate_center_x:
                body.global_position.x = gate_center_x - 16  # Push left
            else:
                body.global_position.x = gate_center_x + 16  # Push right

# Placeholder visual
func _draw() -> void:
    # Iron bars gate (16x32)
    draw_rect(Rect2(-8, -16, 16, 32), Color(0.35, 0.35, 0.4))
    # Vertical bars
    for x_off in [-5, -1, 3]:
        draw_line(Vector2(x_off, -16), Vector2(x_off, 16), Color(0.5, 0.5, 0.55), 2.0)
    # Horizontal bars
    draw_line(Vector2(-8, -8), Vector2(8, -8), Color(0.5, 0.5, 0.55), 1.5)
    draw_line(Vector2(-8, 0), Vector2(8, 0), Color(0.5, 0.5, 0.55), 1.5)
    draw_line(Vector2(-8, 8), Vector2(8, 8), Color(0.5, 0.5, 0.55), 1.5)
    draw_rect(Rect2(-8, -16, 16, 32), Color(0.2, 0.2, 0.25), false, 1.0)
