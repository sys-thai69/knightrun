# skeleton_archer.gd — Stationary archer that shoots arrows in an arc
# IMAGE KEYWORD: "pixel art skeleton archer sprite sheet bow arrow 32x32"
# ARROW IMAGE KEYWORD: "pixel art arrow projectile sprite 16x16"
extends CharacterBody2D

const COIN_DROP = 4
const ARROW_SPEED = 120.0
const FIRE_INTERVAL = 2.5
const DETECTION_RANGE = 200.0
const GRAVITY_VAL = 600.0

var health: int = 3
var is_dead: bool = false
var player_ref: CharacterBody2D = null
var fire_timer: float = FIRE_INTERVAL  # Start with a delay so it doesn't fire immediately

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
	# Scale HP with NG+
	health = int(health * PlayerData.get_enemy_hp_multiplier())
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
	if sprite and sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
		sprite.play("idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY_VAL * delta
	else:
		velocity.y = 0
	velocity.x = 0

	fire_timer -= delta

	if player_ref and not player_ref.is_dead:
		var dist = global_position.distance_to(player_ref.global_position)
		var dir = sign(player_ref.global_position.x - global_position.x)
		sprite.flip_h = dir < 0

		if dist < DETECTION_RANGE and fire_timer <= 0:
			_fire_arrow()
			fire_timer = FIRE_INTERVAL

	move_and_slide()

func _fire_arrow() -> void:
	if sprite and sprite.sprite_frames:
		sprite.play("attack")
	# Calculate arc to player
	var arrow_scene = preload("res://enemy/arrow.tscn")
	var arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)
	arrow.global_position = global_position + Vector2(0, -8)

	# Calculate velocity for parabolic arc
	var target = player_ref.global_position
	var diff = target - arrow.global_position
	var time_to_target = abs(diff.x) / ARROW_SPEED
	if time_to_target < 0.1:
		time_to_target = 0.5

	var vx = diff.x / time_to_target
	var vy = (diff.y - 0.5 * 400.0 * time_to_target * time_to_target) / time_to_target

	arrow.set_velocity(Vector2(vx, vy))

	await get_tree().create_timer(0.4).timeout
	if sprite and sprite.sprite_frames and not is_dead:
		sprite.play("idle")

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return
	health -= damage
	sprite.modulate = Color.RED
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(self) and sprite:
			sprite.modulate = Color.WHITE
	)
	ScreenEffects.spawn_damage_number(global_position, damage, Color.WHITE)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	PlayerData.add_coins(COIN_DROP)
	ScreenEffects.spawn_coin_text(global_position, COIN_DROP)
	AchievementManager.check_and_unlock("first_kill")
	AchievementManager.check_coin_achievements()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
	tween.chain().tween_callback(queue_free)

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
