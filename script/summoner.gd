# summoner.gd — Stationary enemy that spawns varied minions and teleports away
# IMAGE KEYWORD: "pixel art necromancer mage summoner enemy sprite 16x16 purple"
extends CharacterBody2D

const SUMMON_INTERVAL = 5.0       # Seconds between each summon
const TELEPORT_RANGE = 40.0       # Teleport if player this close
const TELEPORT_DISTANCE = 80.0    # How far to teleport
const TELEPORT_COOLDOWN = 3.0     # Can't teleport again for this many seconds
const MAX_TELEPORTS = 2           # Maximum number of teleports allowed
const MAX_MINIONS = 3             # Max alive minions at once
const COIN_DROP = 5
const SPAWN_SPREAD = 40.0         # How far left/right minions can spawn

var health: int = 3
var is_dead: bool = false
var summon_timer: float = 3.0     # First summon after 3 seconds
var teleport_cooldown: float = 0.0
var teleport_count: int = 0       # How many times we've teleported
var _is_teleporting: bool = false
var minions: Array = []
var player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Preload all possible minion scenes for variety
var _minion_scenes: Array[PackedScene] = [
	preload("res://enemy/Slime.tscn"),
	preload("res://enemy/bat.tscn"),
	preload("res://enemy/crawler.tscn"),
]

func _ready() -> void:
	add_to_group("enemy")
	health = int(health * PlayerData.get_enemy_hp_multiplier())
	# Ensure fresh random seed (important after scene reloads)
	randomize()

	# Off-screen optimization
	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-20, -20, 40, 40)
	add_child(notifier)
	notifier.screen_exited.connect(func(): if is_instance_valid(self): set_physics_process(false))
	notifier.screen_entered.connect(func(): if is_instance_valid(self): set_physics_process(true))

	# Find player after one frame (so all nodes are ready)
	_find_player.call_deferred()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

# Placeholder visual
func _draw() -> void:
	# Dark robe body
	draw_rect(Rect2(-6, -8, 12, 16), Color(0.3, 0.1, 0.4))
	# Hood
	draw_rect(Rect2(-5, -10, 10, 6), Color(0.2, 0.05, 0.3))
	# Glowing eyes
	draw_circle(Vector2(-2, -7), 1.0, Color(0.0, 1.0, 0.5))
	draw_circle(Vector2(2, -7), 1.0, Color(0.0, 1.0, 0.5))
	# Staff
	draw_line(Vector2(6, -6), Vector2(6, 8), Color(0.5, 0.3, 0.15), 1.5)
	draw_circle(Vector2(6, -7), 2.0, Color(0.8, 0.2, 1.0))

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Cooldowns
	if teleport_cooldown > 0:
		teleport_cooldown -= delta

	# Face player
	if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
		sprite.flip_h = player_ref.global_position.x < global_position.x

	# Clean up dead minion refs
	minions = minions.filter(func(m): return is_instance_valid(m) and not m.is_dead)

	# Summon timer — only summons ONE minion each interval
	summon_timer -= delta
	if summon_timer <= 0:
		summon_timer = SUMMON_INTERVAL
		_try_summon()

	# Teleport if player too close (only if cooldown is done, not mid-teleport, and under limit)
	if not _is_teleporting and teleport_cooldown <= 0 and teleport_count < MAX_TELEPORTS:
		if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < TELEPORT_RANGE:
				_teleport_away()

func _try_summon() -> void:
	if minions.size() >= MAX_MINIONS:
		return
	if _minion_scenes.is_empty():
		return

	# Pick a random enemy type each summon
	var scene = _minion_scenes.pick_random()
	var minion = scene.instantiate()

	# Spawn to the left or right with good spread (never on top of summoner)
	# Check for walls to avoid spawning inside terrain
	var spawn_pos = _find_safe_spawn_position()
	if spawn_pos == Vector2.ZERO:
		minion.queue_free()  # No valid spot found
		return
	get_parent().add_child(minion)
	minion.global_position = spawn_pos
	minions.append(minion)

	# Summon visual effect
	_summon_effect()

func _summon_effect() -> void:
	sprite.modulate = Color(1.5, 0.5, 2.0)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _find_safe_spawn_position() -> Vector2:
	# Try spawning on either side, checking for walls
	var space = get_world_2d().direct_space_state
	var directions = [1, -1]
	directions.shuffle()  # Random order
	
	for side in directions:
		var offset_x = side * randf_range(24, SPAWN_SPREAD)
		var candidate = global_position + Vector2(offset_x, 0)
		
		# Check if path to spawn point is blocked by wall
		var wall_query = PhysicsRayQueryParameters2D.create(global_position, candidate, 1)
		wall_query.exclude = [get_rid()]
		var wall_result = space.intersect_ray(wall_query)
		if wall_result:
			# Wall in the way, try closer position
			candidate = wall_result.position - Vector2(side * 8, 0)
			if global_position.distance_to(candidate) < 16:
				continue  # Too close to summoner
		
		# Check there's floor below
		var ground_query = PhysicsRayQueryParameters2D.create(candidate, candidate + Vector2(0, 32), 1)
		ground_query.exclude = [get_rid()]
		var ground_result = space.intersect_ray(ground_query)
		if ground_result:
			return Vector2(candidate.x, ground_result.position.y - 8)
	
	# Fallback: spawn right next to summoner
	return global_position + Vector2(0, -4)

func _teleport_away() -> void:
	if not player_ref or _is_teleporting:
		return

	_is_teleporting = true
	teleport_cooldown = TELEPORT_COOLDOWN
	teleport_count += 1

	# Try to find a valid position that isn't inside a wall
	var away_dir = (global_position - player_ref.global_position).normalized()
	var target_pos = _find_safe_teleport(away_dir)

	# Teleport effect (shrink, move, grow)
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.1)
	tw.tween_callback(func(): if is_instance_valid(self): global_position = target_pos)
	tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
	tw.tween_callback(func(): if is_instance_valid(self): _is_teleporting = false)

func _find_safe_teleport(preferred_dir: Vector2) -> Vector2:
	# Use the physics space to check for walls at the target
	var space = get_world_2d().direct_space_state
	# Try the preferred direction first, then rotate if blocked
	# Only teleport horizontally to stay on the ground
	var horizontal_dirs = [
		Vector2(preferred_dir.x, 0).normalized(),
		Vector2(-preferred_dir.x, 0).normalized(),
	]
	if horizontal_dirs[0] == Vector2.ZERO:
		horizontal_dirs[0] = Vector2(1, 0)
		horizontal_dirs[1] = Vector2(-1, 0)

	for dir in horizontal_dirs:
		var candidate = global_position + dir * TELEPORT_DISTANCE
		# Raycast horizontally to check for walls
		var wall_query = PhysicsRayQueryParameters2D.create(global_position, candidate, 1)
		wall_query.exclude = [get_rid()]
		var wall_result = space.intersect_ray(wall_query)
		if wall_result:
			# Wall hit — try placing just before the wall with margin
			candidate = wall_result.position - dir * 12
			if global_position.distance_to(candidate) < 24:
				continue  # Too close, try other direction

		# Verify there's ground below the candidate position
		var ground_query = PhysicsRayQueryParameters2D.create(candidate, candidate + Vector2(0, 64), 1)
		ground_query.exclude = [get_rid()]
		var ground_result = space.intersect_ray(ground_query)
		if ground_result:
			# Place on ground
			return Vector2(candidate.x, ground_result.position.y - 8)

	# All directions failed — stay put
	return global_position

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return
	health -= damage
	sprite.modulate = Color(3, 3, 3)
	var flash_tw = create_tween()
	flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	var pop_tw = create_tween()
	pop_tw.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.05)
	pop_tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	ScreenEffects.spawn_damage_number(global_position, damage, Color.WHITE)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	PlayerData.add_coins(COIN_DROP)
	ScreenEffects.spawn_coin_text(global_position, COIN_DROP)
	AchievementManager.check_and_unlock("first_kill")
	AchievementManager.check_coin_achievements()
	set_physics_process(false)
	# Kill remaining minions
	for m in minions:
		if is_instance_valid(m) and not m.is_dead:
			m.die()
	minions.clear()
	# Death effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.4)
	tween.chain().tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
