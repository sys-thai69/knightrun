# homing_projectile.gd — Slow homing projectile that tracks the player
extends Area2D

const SPEED: float = 60.0  # Slow speed for fairness
const TURN_SPEED: float = 1.5  # How fast it can turn (radians per second)
const LIFETIME: float = 8.0  # Disappears after this many seconds
const DAMAGE: int = 1

var direction: Vector2 = Vector2.RIGHT
var player_ref: CharacterBody2D = null
var lifetime_timer: float = LIFETIME
var is_active: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

func _ready() -> void:
	add_to_group("projectile")
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# Off-screen optimization - destroy projectile if it goes too far off screen
	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-20, -20, 40, 40)
	add_child(notifier)
	notifier.screen_exited.connect(func(): 
		# Give it 2 seconds off-screen before destroying
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(self):
			queue_free()
	)
	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func _process(delta: float) -> void:
	if not is_active:
		return
	
	# Lifetime countdown
	lifetime_timer -= delta
	if lifetime_timer <= 0:
		_fade_out()
		return
	
	# Home toward player
	if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
		var target_dir = (player_ref.global_position - global_position).normalized()
		# Smoothly rotate toward player
		var angle_diff = direction.angle_to(target_dir)
		var max_turn = TURN_SPEED * delta
		if abs(angle_diff) < max_turn:
			direction = target_dir
		else:
			direction = direction.rotated(sign(angle_diff) * max_turn)
	
	# Move in current direction
	position += direction * SPEED * delta
	
	# Rotate sprite to match direction
	rotation = direction.angle()
	
	# Visual pulse effect
	if sprite:
		var pulse = sin(lifetime_timer * 8) * 0.1 + 1.0
		sprite.scale = Vector2(pulse, pulse)

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	# Check if we're a reflected/player projectile hitting enemies
	if is_in_group("player_projectile"):
		if body.is_in_group("enemy") and body.has_method("take_hit"):
			body.take_hit(DAMAGE, "ranged")
			_explode()
			return
		elif body.is_in_group("terrain"):
			_explode()
			return
	# Original enemy projectile behavior
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
		_explode()
	elif body.is_in_group("terrain"):
		_explode()

func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	# Can be parried/reflected
	if area.get_parent().is_in_group("player"):
		pass  # Handled by body_entered

func reflect() -> void:
	# Called when player parries - send projectile back
	if player_ref:
		direction = -direction
		# Change to friendly projectile
		remove_from_group("enemy_projectile")
		add_to_group("player_projectile")
		# Target nearest enemy instead
		var enemies = get_tree().get_nodes_in_group("enemy")
		var closest: Node2D = null
		var closest_dist = INF
		for enemy in enemies:
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = enemy
		if closest:
			direction = (closest.global_position - global_position).normalized()
		# Visual change
		modulate = Color(0.3, 1.0, 0.3)  # Green tint

func _explode() -> void:
	is_active = false
	# Quick explosion effect
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)

func _fade_out() -> void:
	is_active = false
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

# Placeholder drawing
func _draw() -> void:
	# Purple glowing orb
	draw_circle(Vector2.ZERO, 6, Color(0.6, 0.2, 0.8, 0.8))
	draw_circle(Vector2.ZERO, 4, Color(0.8, 0.4, 1.0, 0.9))
	draw_circle(Vector2.ZERO, 2, Color(1.0, 0.8, 1.0, 1.0))
