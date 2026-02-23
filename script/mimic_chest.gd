# mimic_chest.gd — Looks like a treasure chest, attacks when player gets close
# IMAGE KEYWORD: "pixel art treasure chest mimic enemy sprite sheet open close 32x32"
extends CharacterBody2D

const SPEED = 90.0
const DETECTION_RANGE = 35.0
const CHASE_RANGE = 120.0
const COIN_DROP = 8
const GRAVITY_VAL = 600.0

var health: int = 5
var is_dead: bool = false
var is_awake: bool = false
var player_ref: CharacterBody2D = null
var attack_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
	# Scale HP with NG+
	health = int(health * PlayerData.get_enemy_hp_multiplier())
	# Start looking like a normal chest
	if sprite and sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
		sprite.play("closed")
	# Off-screen optimization
	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-20, -20, 40, 40)
	add_child(notifier)
	notifier.screen_exited.connect(func(): set_physics_process(false))
	notifier.screen_entered.connect(func(): set_physics_process(true))
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY_VAL * delta
	else:
		velocity.y = 0

	attack_cooldown -= delta

	if not is_awake:
		velocity.x = 0
		# Detect player getting close
		if player_ref and not player_ref.is_dead:
			var dist = global_position.distance_to(player_ref.global_position)
			if dist < DETECTION_RANGE:
				_wake_up()
		move_and_slide()
		return

	# Awake — chase player aggressively
	if player_ref and not player_ref.is_dead:
		var dist = global_position.distance_to(player_ref.global_position)
		var dir = sign(player_ref.global_position.x - global_position.x)

		if dist < CHASE_RANGE:
			velocity.x = dir * SPEED
			sprite.flip_h = dir < 0
			if sprite and sprite.sprite_frames:
				sprite.play("run")

			# Bite attack at close range
			if dist < 20 and attack_cooldown <= 0:
				attack_cooldown = 1.0
				pass  # Damage handled by hurt area only
		else:
			velocity.x = 0
			if sprite and sprite.sprite_frames:
				sprite.play("idle")
	else:
		velocity.x = 0

	move_and_slide()

func _wake_up() -> void:
	is_awake = true
	# Surprise! Jump up
	velocity.y = -150
	if sprite and sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
		sprite.play("open")
	queue_redraw()

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return
	if not is_awake:
		_wake_up()
	health -= damage
	# White flash + scale pop on hit
	sprite.modulate = Color(3, 3, 3)
	var flash_tw = create_tween()
	flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	var pop_tw = create_tween()
	pop_tw.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.05)
	pop_tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	ScreenEffects.spawn_damage_number(global_position, damage, Color.GOLD)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	PlayerData.add_coins(COIN_DROP)
	ScreenEffects.spawn_coin_text(global_position, COIN_DROP)
	AchievementManager.check_and_unlock("first_kill")
	AchievementManager.check_coin_achievements()
	# Drop extra coins as reward for defeating a mimic
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
	tween.chain().tween_callback(queue_free)

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage") and is_awake:
		body.take_damage(1)
