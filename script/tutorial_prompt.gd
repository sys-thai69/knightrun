# tutorial_prompt.gd — Shows a helpful tip when player enters the area
# Place these around the beginning of the level
extends Area2D

@export var prompt_text: String = "Press W to Jump"
@export var show_once: bool = true

var already_shown: bool = false
var label: Label = null

func _ready() -> void:
	label = Label.new()
	label.text = prompt_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -30)
	label.modulate.a = 0.0
	add_child(label)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if show_once and already_shown:
		return
	already_shown = true
	_show_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hide_prompt()

func _show_prompt() -> void:
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)

func _hide_prompt() -> void:
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
