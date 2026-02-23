# wraith.gd — Floating enemy that shoots slow homing projectiles
# IMAGE KEYWORD: "pixel art wraith ghost dark magic enemy sprite sheet 32x32"
extends CharacterBody2D

const SPEED: float = 25.0  # Slow floating movement
const DETECTION_RANGE: float = 200.0
const ATTACK_RANGE: float = 180.0  # Range to start shooting
const PREFERRED_DISTANCE: float = 100.0  # Tries to maintain this distance
const SHOOT_COOLDOWN: float = 3.0  # Time between shots
const COIN_DROP: int = 8

var health: int = 3
var is_dead: bool = false
var player_ref: CharacterBody2D = null
var shoot_timer: float = 1.5  # Starts ready to shoot soon
var float_offset: float = 0.0  # For bobbing animation

@export var projectile_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
	# Scale HP with NG+
	health = int(health * PlayerData.get_enemy_hp_multiplier())
	# Load projectile scene if not set in inspector
	if not projectile_scene:
		projectile_scene = preload("res://scenes/homing_projectile.tscn")
	# Off-screen optimization
	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-30, -30, 60, 60)
	add_child(notifier)
	notifier.screen_exited.connect(func(): set_physics_process(false))
	notifier.screen_entered.connect(func(): set_physics_process(true))
	# Get player reference
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

# Placeholder visual
func _draw() -> void:
	# Dark hooded figure shape
	draw_polygon(PackedVector2Array([
		Vector2(0, -14),
		Vector2(-10, 0),
		Vector2(-8, 12),
		Vector2(8, 12),
		Vector2(10, 0)
	]), PackedColorArray([Color(0.15, 0.1, 0.2), Color(0.2, 0.15, 0.25), Color(0.15, 0.1, 0.2), Color(0.2, 0.15, 0.25), Color(0.15, 0.1, 0.2)]))
	# Glowing eyes
	draw_circle(Vector2(-3, -4), 2, Color(0.8, 0.2, 0.8, 0.9))
	draw_circle(Vector2(3, -4), 2, Color(0.8, 0.2, 0.8, 0.9))
	# Magic aura
	var aura_alpha = sin(float_offset * 3) * 0.2 + 0.3
	draw_circle(Vector2.ZERO, 16, Color(0.5, 0.2, 0.6, aura_alpha))

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Floating bob animation
	float_offset += delta * 2
	var bob = sin(float_offset) * 3
	if sprite:
		sprite.position.y = bob
	queue_redraw()  # Redraw placeholder
	
	shoot_timer -= delta
	
	if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
		var dist = global_position.distance_to(player_ref.global_position)
		var dir_to_player = sign(player_ref.global_position.x - global_position.x)
		
		# Face player
		if sprite:
			sprite.flip_h = dir_to_player < 0
		
		if dist < DETECTION_RANGE:
			# Try to maintain preferred distance
			if dist < PREFERRED_DISTANCE - 20:
				# Too close, back away
				var away_dir = (global_position - player_ref.global_position).normalized()
				velocity = away_dir * SPEED * 1.5
			elif dist > PREFERRED_DISTANCE + 20:
				# Too far, move closer
				var toward_dir = (player_ref.global_position - global_position).normalized()
				velocity = toward_dir * SPEED
			else:
				# Good distance, hover in place with slight movement
				velocity = velocity.move_toward(Vector2.ZERO, SPEED * delta * 2)
			
			# Shoot if in range and cooldown ready
			if dist < ATTACK_RANGE and shoot_timer <= 0:
				_shoot_projectile()
				shoot_timer = SHOOT_COOLDOWN
			
			# Slight vertical hovering
			velocity.y += sin(float_offset * 1.5) * 10 * delta
		else:
			velocity = velocity.move_toward(Vector2.ZERO, SPEED * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * delta)
	
	move_and_slide()

func _shoot_projectile() -> void:
	if not projectile_scene or not player_ref:
		return
	
	# Visual charge-up
	if sprite:
		sprite.modulate = Color(1.0, 0.5, 1.0)
		get_tree().create_timer(0.2).timeout.connect(func():
			if is_instance_valid(self) and sprite:
				sprite.modulate = Color.WHITE
		)
	
	# Spawn projectile
	var proj = projectile_scene.instantiate()
	proj.global_position = global_position
	proj.direction = (player_ref.global_position - global_position).normalized()
	get_parent().add_child(proj)

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return
	health -= damage
	# Flash red
	if sprite:
		sprite.modulate = Color(1, 0.3, 0.3)
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(self) and sprite:
				sprite.modulate = Color.WHITE
		)
	ScreenEffects.spawn_damage_number(global_position, damage, Color.PURPLE)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	PlayerData.add_coins(COIN_DROP)
	ScreenEffects.spawn_coin_text(global_position, COIN_DROP)
	AchievementManager.check_and_unlock("first_kill")
	AchievementManager.check_coin_achievements()
	# Fade out death
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.5)
	tw.tween_callback(queue_free)

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
