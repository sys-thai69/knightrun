# summoner.gd — Boss enemy that spawns minions and teleports away (beta boss)
# Animations: idle, walk, summoning, pre-teleport, teleported, dead
extends CharacterBody2D

signal boss_defeated

const SUMMON_INTERVAL = 3.0       # Summon every 3 seconds
const TELEPORT_RANGE = 50.0       # Teleport if player this close
const TELEPORT_DISTANCE = 60.0    # Short teleport distance
const TELEPORT_COOLDOWN = 4.0     # Cooldown between teleports
const MAX_TELEPORTS = 2           # Can only teleport 2 times total
const COIN_DROP = 15              # Boss drops more coins
const SPAWN_SPREAD = 50.0         # How far left/right minions can spawn
const MAX_HEALTH = 25             # Boss health
const WALK_SPEED = 8.0            # Very slow walk speed (avoids fighting)

var health: int = MAX_HEALTH
var scaled_max_health: int = MAX_HEALTH
var is_dead: bool = false
var summon_timer: float = 1.5     # First summon after 1.5 seconds
var teleport_cooldown: float = 0.0
var teleport_count: int = 0       # How many times we've teleported
var _is_teleporting: bool = false
var _is_summoning: bool = false
var _original_scale: Vector2 = Vector2.ONE  # Store original sprite scale
var minions: Array = []
var player_ref: CharacterBody2D = null
var gravity: float = 800.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Only summon these 4 enemy types
var _minion_scenes: Array[PackedScene] = [
	preload("res://enemy/Slime.tscn"),
	preload("res://enemy/ghost.tscn"),
	preload("res://enemy/skeleton_archer.tscn"),
	preload("res://enemy/shooting_slime_ver2.tscn"),
]

# Pushable block to drop on death
var _pushable_block_scene: PackedScene = preload("res://scenes/mechanics/pushable_block.tscn")

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	# Scale boss HP with NG+ level
	health = int(MAX_HEALTH * PlayerData.get_enemy_hp_multiplier())
	scaled_max_health = health
	randomize()
	
	# Play idle animation
	_play_anim("idle")
	
	# Store original sprite scale
	if sprite:
		_original_scale = sprite.scale
	
	# Find player after one frame
	_find_player.call_deferred()
	
	# Show boss HP bar when ready
	_show_boss_hp_bar.call_deferred()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func _show_boss_hp_bar() -> void:
	await get_tree().process_frame
	var hp_bar = get_parent().get_node_or_null("BossHPBar")
	if hp_bar and hp_bar.has_method("set_boss"):
		hp_bar.set_boss(self)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity - boss stays on ground
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	move_and_slide()

	# Cooldowns
	if teleport_cooldown > 0:
		teleport_cooldown -= delta

	# Face player
	if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
		sprite.flip_h = player_ref.global_position.x < global_position.x

	# Clean up dead minion refs
	minions = minions.filter(func(m): return is_instance_valid(m) and not m.is_dead)

	# Summon timer — unlimited summons every 2 seconds
	summon_timer -= delta
	if summon_timer <= 0 and not _is_summoning and not _is_teleporting:
		summon_timer = SUMMON_INTERVAL
		_try_summon()

	# Teleport if player too close (only if on ground, cooldown done, not busy, and under limit)
	if not _is_teleporting and not _is_summoning and teleport_cooldown <= 0 and teleport_count < MAX_TELEPORTS:
		if is_on_floor() and player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < TELEPORT_RANGE:
				_teleport_away()
	
	# Slow walk AWAY from player when not busy (to avoid fighting and keep summoning)
	if not _is_summoning and not _is_teleporting:
		if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
			var dist = global_position.distance_to(player_ref.global_position)
			var dir_away_from_player = sign(global_position.x - player_ref.global_position.x)
			if dist < 100:  # Walk away if player is close
				velocity.x = dir_away_from_player * WALK_SPEED
				_play_anim("walk")
			else:
				velocity.x = 0
				if sprite.animation != "idle":
					_play_anim("idle")
		else:
			velocity.x = 0
			if sprite.animation != "idle":
				_play_anim("idle")

func _try_summon() -> void:
	if _minion_scenes.is_empty():
		return
	
	_is_summoning = true
	_play_anim("summoning")
	
	# Wait for summon animation
	await get_tree().create_timer(0.5).timeout
	if is_dead or not is_instance_valid(self):
		return
	
	# Pick a random enemy type
	var scene: PackedScene = _minion_scenes.pick_random()
	var minion = scene.instantiate()

	# Spawn to the left or right
	var spawn_pos = _find_safe_spawn_position()
	if spawn_pos == Vector2.ZERO:
		minion.queue_free()
		_is_summoning = false
		return
	get_parent().add_child(minion)
	minion.global_position = spawn_pos
	minions.append(minion)

	# Summon visual effect
	_summon_effect()
	
	await get_tree().create_timer(0.3).timeout
	if is_dead or not is_instance_valid(self):
		return
	_is_summoning = false
	_play_anim("idle")

func _summon_effect() -> void:
	sprite.modulate = Color(1.5, 0.5, 2.0)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _find_safe_spawn_position() -> Vector2:
	# Try spawning on either side, with better collision checking
	var space = get_world_2d().direct_space_state
	var directions = [1, -1]
	directions.shuffle()
	
	for side in directions:
		var offset_x = side * randf_range(30, SPAWN_SPREAD)
		var candidate = global_position + Vector2(offset_x, 0)
		
		# Check if path to spawn point is blocked by wall
		var wall_query = PhysicsRayQueryParameters2D.create(global_position, candidate, 1)
		wall_query.exclude = [get_rid()]
		var wall_result = space.intersect_ray(wall_query)
		if wall_result:
			# Wall in the way, position just before wall with margin
			candidate = wall_result.position - Vector2(side * 16, 0)
			if global_position.distance_to(candidate) < 24:
				continue
		
		# Check there's floor below
		var ground_query = PhysicsRayQueryParameters2D.create(candidate, candidate + Vector2(0, 48), 1)
		ground_query.exclude = [get_rid()]
		var ground_result = space.intersect_ray(ground_query)
		if not ground_result:
			continue
		
		var spawn_y = ground_result.position.y - 12
		var final_pos = Vector2(candidate.x, spawn_y)
		
		# Extra check: make sure spawn position itself is not inside a wall
		# Cast rays left and right from spawn point
		var left_check = PhysicsRayQueryParameters2D.create(final_pos, final_pos + Vector2(-10, 0), 1)
		var right_check = PhysicsRayQueryParameters2D.create(final_pos, final_pos + Vector2(10, 0), 1)
		left_check.exclude = [get_rid()]
		right_check.exclude = [get_rid()]
		
		var left_hit = space.intersect_ray(left_check)
		var right_hit = space.intersect_ray(right_check)
		
		# If both directions hit walls very close, we're in a tight space
		if left_hit and right_hit:
			var left_dist = final_pos.distance_to(left_hit.position)
			var right_dist = final_pos.distance_to(right_hit.position)
			if left_dist < 8 or right_dist < 8:
				continue
		
		return final_pos
	
	# Fallback: spawn above summoner on same ground
	return global_position + Vector2(0, -8)

func _teleport_away() -> void:
	if not player_ref or _is_teleporting or not is_on_floor():
		return

	_is_teleporting = true
	teleport_cooldown = TELEPORT_COOLDOWN
	teleport_count += 1

	# Play pre-teleport animation
	_play_anim("pre-teleport")
	
	# Wait for pre-teleport animation
	await get_tree().create_timer(0.3).timeout
	if is_dead or not is_instance_valid(self):
		return

	# Try to find a valid ground position
	var away_dir = (global_position - player_ref.global_position).normalized()
	var target_pos = _find_safe_teleport(away_dir)

	# Teleport effect (shrink, move, grow) - preserve original scale
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.1)
	tw.tween_callback(func(): 
		if is_instance_valid(self): 
			global_position = target_pos
			_play_anim("teleported")
	)
	tw.tween_property(sprite, "scale", _original_scale, 0.15)
	tw.tween_callback(func(): 
		if is_instance_valid(self): 
			_is_teleporting = false
			_play_anim("idle")
	)

func _find_safe_teleport(preferred_dir: Vector2) -> Vector2:
	# Simple horizontal teleport on same ground level - no going through walls
	var space = get_world_2d().direct_space_state
	
	# Determine teleport direction (away from player)
	var directions = [
		Vector2(1, 0) if preferred_dir.x >= 0 else Vector2(-1, 0),
		Vector2(-1, 0) if preferred_dir.x >= 0 else Vector2(1, 0),
	]
	
	for dir in directions:
		# Check for wall in the path
		var wall_query = PhysicsRayQueryParameters2D.create(
			global_position, 
			global_position + dir * TELEPORT_DISTANCE, 
			1
		)
		wall_query.exclude = [get_rid()]
		var wall_result = space.intersect_ray(wall_query)
		
		var target_x: float
		if wall_result:
			# Wall in the way - stop before wall with margin
			target_x = wall_result.position.x - dir.x * 16
			# Too close to current position, skip this direction
			if abs(target_x - global_position.x) < 30:
				continue
		else:
			target_x = global_position.x + dir.x * TELEPORT_DISTANCE
		
		# Check there's ground at the target position
		var ground_query = PhysicsRayQueryParameters2D.create(
			Vector2(target_x, global_position.y - 16),
			Vector2(target_x, global_position.y + 32),
			1
		)
		ground_query.exclude = [get_rid()]
		var ground_result = space.intersect_ray(ground_query)
		
		if ground_result:
			# Valid ground found
			var final_pos = Vector2(target_x, ground_result.position.y - 8)
			
			# Make sure target is away from player
			if player_ref and final_pos.distance_to(player_ref.global_position) < 40:
				continue
			
			return final_pos
	
	# No valid teleport found - stay in place
	return global_position

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return
	health -= damage
	sprite.modulate = Color(3, 3, 3)
	var flash_tw = create_tween()
	flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	var pop_tw = create_tween()
	var pop_scale = _original_scale * 1.3
	pop_tw.tween_property(sprite, "scale", pop_scale, 0.05)
	pop_tw.tween_property(sprite, "scale", _original_scale, 0.1).set_ease(Tween.EASE_OUT)
	ScreenEffects.spawn_damage_number(global_position, damage, Color.WHITE)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# Emit boss defeated signal
	boss_defeated.emit()
	
	# Play death animation
	_play_anim("dead")
	
	PlayerData.add_coins(COIN_DROP)
	ScreenEffects.spawn_coin_text(global_position, COIN_DROP)
	AchievementManager.check_and_unlock("first_kill")
	AchievementManager.check_and_unlock("boss_slayer")
	AchievementManager.check_coin_achievements()
	
	# Screen effects
	ScreenEffects.shake(2.0, 0.2)
	ScreenEffects.hit_freeze(0.05)
	
	# Kill remaining minions
	for m in minions:
		if is_instance_valid(m) and not m.is_dead:
			m.die()
	minions.clear()
	
	# Drop pushable block for player to use
	_drop_pushable_block()
	
	# Wait for death animation then fade out
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _drop_pushable_block() -> void:
	if _pushable_block_scene:
		var block = _pushable_block_scene.instantiate()
		get_parent().add_child(block)
		block.global_position = global_position + Vector2(0, -10)
		# Give it a small upward velocity
		if block.has_method("drop"):
			block.velocity = Vector2(0, -50)

func get_health_percent() -> float:
	return float(health) / float(scaled_max_health)

func _play_anim(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
