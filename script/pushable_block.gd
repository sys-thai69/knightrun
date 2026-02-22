# pushable_block.gd — A block the player can pick up, carry, and drop
# IMAGE KEYWORD: "pixel art stone crate push block puzzle sprite 16x16"
extends CharacterBody2D

const GRAVITY_VAL = 600.0
var is_carried: bool = false

func _ready() -> void:
	add_to_group("pushable")
	add_to_group("carriable")

func _physics_process(delta: float) -> void:
	if is_carried:
		# While carried, the player controls our position
		return
	# Apply gravity when not carried
	if not is_on_floor():
		velocity.y += GRAVITY_VAL * delta
	else:
		velocity.y = 0
	velocity.x = move_toward(velocity.x, 0, 200 * delta)
	move_and_slide()

func pick_up(carrier: Node2D) -> void:
	is_carried = true
	# Disable collision so it doesn't push the player
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	# Re-parent to the carrier so it follows them
	get_parent().remove_child(self)
	carrier.add_child(self)
	# Position above the player's head
	position = Vector2(0, -20)
	queue_redraw()

func drop(drop_dir: int) -> void:
	is_carried = false
	var global_pos = global_position
	var old_parent = get_parent()
	old_parent.remove_child(self)
	# Re-add to the game scene
	var scene_root = old_parent
	while scene_root.get_parent() and scene_root.get_parent() != scene_root.get_tree().root:
		scene_root = scene_root.get_parent()
	scene_root.add_child(self)
	global_position = global_pos + Vector2(drop_dir * 12, 4)
	velocity = Vector2(drop_dir * 30, -20)
	# Restore collision
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	queue_redraw()

# Placeholder visual
func _draw() -> void:
	# Stone block (16x16)
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.5, 0.48, 0.45))
	# Stone texture lines
	draw_line(Vector2(-8, -2), Vector2(0, -2), Color(0.4, 0.38, 0.35), 1.0)
	draw_line(Vector2(-4, 2), Vector2(8, 2), Color(0.4, 0.38, 0.35), 1.0)
	draw_line(Vector2(2, -8), Vector2(2, -2), Color(0.4, 0.38, 0.35), 1.0)
	draw_line(Vector2(-3, -2), Vector2(-3, 2), Color(0.4, 0.38, 0.35), 1.0)
	# Outline
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.3, 0.28, 0.25), false, 1.0)
	if is_carried:
		# Glow when carried
		draw_rect(Rect2(-9, -9, 18, 18), Color(1.0, 1.0, 0.5, 0.3), false, 1.5)

