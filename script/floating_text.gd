# floating_text.gd — A Node2D that renders floating damage/text numbers
# Works correctly with Camera2D and pixel-art (nearest-neighbor) settings
extends Node2D

var display_text: String = ""
var text_color: Color = Color.WHITE
var font_size: int = 8
var elapsed: float = 0.0
var lifetime: float = 0.8
var float_speed: float = 20.0

func setup(text: String, color: Color = Color.WHITE, size: int = 8) -> void:
    display_text = text
    text_color = color
    font_size = size

func _ready() -> void:
    # Force the texture filter to LINEAR so text renders cleanly at small sizes
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed >= lifetime:
        queue_free()
        return
    position.y -= float_speed * delta
    var t: float = elapsed / lifetime
    modulate.a = clamp(1.0 - t * t, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    var font: Font = ThemeDB.fallback_font
    if font == null:
        return
    # Draw black outline for readability
    var offsets = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
                   Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
    for off in offsets:
        draw_string(font, off, display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)
    # Draw main colored text
    draw_string(font, Vector2.ZERO, display_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)
