# pressure_plate.gd — Triggers a linked gate when stepped on
# IMAGE KEYWORD: "pixel art pressure plate floor switch button tile sprite 16x16"
extends Area2D

## Path to the Gate node this plate controls (optional — auto-detects if empty)
@export var gate_path: NodePath
## If gate_path is empty, search for a sibling/scene node with this name
@export var gate_node_name: String = "Gate"
## Stay open while player is on plate, or toggle permanently?
@export var toggle_mode: bool = false

var _pressed: bool = false
var _gate: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if gate_path:
		_gate = get_node_or_null(gate_path)
	else:
		# Auto-detect: search parent and scene for a node with open_gate()
		_auto_find_gate.call_deferred()

func _auto_find_gate() -> void:
	# 1) Check parent — maybe plate is a child of gate
	if get_parent().has_method("open_gate"):
		_gate = get_parent()
		return
	# 2) Search siblings for a node named gate_node_name
	if get_parent().has_node(gate_node_name):
		_gate = get_parent().get_node(gate_node_name)
		return
	# 3) Search entire scene for any node named gate_node_name
	var scene_root = get_tree().current_scene
	_gate = _find_node_recursive(scene_root, gate_node_name)

func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name and node.has_method("open_gate"):
		return node
	for child in node.get_children():
		var found = _find_node_recursive(child, target_name)
		if found:
			return found
	return null

func _is_activator(body: Node2D) -> bool:
	return body.is_in_group("player") or body.is_in_group("pushable")

func _on_body_entered(body: Node2D) -> void:
	if _is_activator(body):
		if toggle_mode:
			_pressed = not _pressed
			if _pressed:
				_activate()
			else:
				_deactivate()
		else:
			_pressed = true
			_activate()

func _on_body_exited(body: Node2D) -> void:
	if _is_activator(body) and not toggle_mode:
		# Only deactivate if no other activator is still on the plate
		for other in get_overlapping_bodies():
			if other != body and _is_activator(other):
				return
		_pressed = false
		_deactivate()

func _activate() -> void:
	if _gate and _gate.has_method("open_gate"):
		_gate.open_gate()
	queue_redraw()

func _deactivate() -> void:
	if _gate and _gate.has_method("close_gate"):
		_gate.close_gate()
	queue_redraw()

# Placeholder visual
func _draw() -> void:
	if _pressed:
		# Pressed down plate
		draw_rect(Rect2(-8, 1, 16, 4), Color(0.6, 0.55, 0.4))
		draw_rect(Rect2(-8, 1, 16, 4), Color(0.3, 0.28, 0.2), false, 1.0)
	else:
		# Raised plate
		draw_rect(Rect2(-8, -2, 16, 6), Color(0.75, 0.7, 0.55))
		draw_rect(Rect2(-8, -2, 16, 6), Color(0.4, 0.35, 0.25), false, 1.0)
		# Arrow indicator
		draw_line(Vector2(-2, 0), Vector2(2, 0), Color(0.4, 0.35, 0.25), 1.0)
		draw_line(Vector2(0, -2), Vector2(0, 2), Color(0.4, 0.35, 0.25), 1.0)
