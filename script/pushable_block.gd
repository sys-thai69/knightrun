# pushable_block.gd — A block the player can pick up, carry, and drop
# IMAGE KEYWORD: "pixel art stone crate push block puzzle sprite 16x16"
extends CharacterBody2D

const GRAVITY_VAL = 600.0
const PICKUP_RANGE = 30.0
var is_carried: bool = false
var player_nearby: bool = false
var player_ref: CharacterBody2D = null
var prompt_label: Label = null

func _ready() -> void:
	add_to_group("pushable")
	add_to_group("carriable")
	
	# Create the "Press E" prompt label
	prompt_label = Label.new()
	prompt_label.text = "Press E"
	prompt_label.add_theme_font_size_override("font_size", 10)
	prompt_label.add_theme_color_override("font_color", Color.YELLOW)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 2)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-20, -28)
	prompt_label.visible = false
	add_child(prompt_label)
	
	# Find player
	_find_player.call_deferred()

func _find_player() -> void:
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func _physics_process(delta: float) -> void:
	if is_carried:
		# While carried, the player controls our position
		prompt_label.visible = false
		return
	
	# Apply gravity when not carried
	if not is_on_floor():
		velocity.y += GRAVITY_VAL * delta
	else:
		velocity.y = 0
	velocity.x = move_toward(velocity.x, 0, 200 * delta)
	move_and_slide()
	
	# Check if player is nearby to show prompt
	if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
		var dist = global_position.distance_to(player_ref.global_position)
		player_nearby = dist < PICKUP_RANGE
		prompt_label.visible = player_nearby
	else:
		player_nearby = false
		prompt_label.visible = false

func pick_up(carrier: Node2D) -> void:
	is_carried = true
	prompt_label.visible = false
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
	prompt_label.visible = false
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
	# Re-find player reference after reparenting
	_find_player.call_deferred()
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

