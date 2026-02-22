# shield_knight.gd — Armored knight with a shield; slow to turn, frontal attacks deal reduced damage
# Strategy: Get behind it while it's slow to turn, or chip away with frontal attacks
# IMAGE KEYWORD: "pixel art shield knight enemy sprite sheet sword shield 32x32"
extends CharacterBody2D

const SPEED = 35.0
const COIN_DROP = 6
const GRAVITY_VAL = 600.0
const DETECTION_RANGE: float = 150.0  # Only chase player when within this range
const TURN_DELAY: float = 0.6  # Time it takes to turn around (vulnerability window)
const FRONTAL_DAMAGE_MULT: float = 0.5  # Frontal attacks deal 50% damage

var health: int = 4
var is_dead: bool = false
var direction: int = 1
var player_ref: CharacterBody2D = null
var facing_right: bool = true
var is_activated: bool = false
var turn_timer: float = 0.0  # Countdown while turning
var is_turning: bool = false
var target_facing_right: bool = true  # What direction we WANT to face

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_down: RayCast2D = $RayCastDown

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
	_update_raycast_direction()

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	# Gray armored body
	draw_rect(Rect2(-7, -11, 14, 22), Color(0.65, 0.65, 0.7))
	# Shield on front side (flickers when turning)
	var shield_alpha = 0.5 if is_turning else 1.0
	var shield_x = 5 if facing_right else -9
	draw_rect(Rect2(shield_x, -8, 4, 16), Color(0.4, 0.4, 0.5, shield_alpha))
	draw_rect(Rect2(-7, -11, 14, 22), Color.BLACK, false, 1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY_VAL * delta
	else:
		velocity.y = 0

	# Handle turning delay
	if is_turning:
		turn_timer -= delta
		velocity.x = 0  # Stop moving while turning
		if turn_timer <= 0:
			is_turning = false
			facing_right = target_facing_right
			sprite.flip_h = not facing_right
			direction = 1 if facing_right else -1
			_update_raycast_direction()
			queue_redraw()
		move_and_slide()
		if sprite and sprite.sprite_frames:
			sprite.play("idle")  # Stand still while turning
		return

	# Check if player is close enough to activate
	if player_ref and not player_ref.is_dead:
		var dist = global_position.distance_to(player_ref.global_position)
		if not is_activated and dist > DETECTION_RANGE:
			# Not activated yet — just idle
			velocity.x = 0
			move_and_slide()
			if sprite and sprite.sprite_frames:
				sprite.play("idle")
			return
		else:
			is_activated = true

		# Check if we need to turn (player is behind us)
		var dir_to_player = sign(player_ref.global_position.x - global_position.x)
		var should_face_right = dir_to_player > 0
		
		if should_face_right != facing_right and not is_turning:
			# Need to turn around — this takes time!
			is_turning = true
			turn_timer = TURN_DELAY
			target_facing_right = should_face_right
			queue_redraw()
			return

	# Walk toward player (with edge/wall checks)
	var should_flip = false
	if ray_cast_right.is_colliding():
		should_flip = true
	if not ray_cast_down.is_colliding():
		should_flip = true
	if should_flip:
		direction *= -1
		facing_right = direction > 0
		sprite.flip_h = not facing_right
		_update_raycast_direction()
		queue_redraw()

	velocity.x = direction * SPEED
	move_and_slide()

	if sprite and sprite.sprite_frames:
		if abs(velocity.x) > 1:
			sprite.play("run")
		else:
			sprite.play("idle")

func _update_raycast_direction() -> void:
	# Point raycasts in the current movement direction
	if ray_cast_right:
		ray_cast_right.target_position = Vector2(direction * 16, 0)
	if ray_cast_down:
		ray_cast_down.target_position = Vector2(direction * 8, 16)

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return

	var actual_damage = damage
	var from_behind = false
	
	# Check attack direction
	if player_ref:
		var player_side = sign(player_ref.global_position.x - global_position.x)
		var shield_facing = 1 if facing_right else -1

		if player_side == shield_facing and not is_turning:
			# Attack from front while shield is up — REDUCED damage
			actual_damage = max(1, int(damage * FRONTAL_DAMAGE_MULT))
			sprite.modulate = Color(0.5, 0.5, 1.0)
			ScreenEffects.spawn_text_popup(global_position + Vector2(0, -15), "Blocked!", Color.GRAY)
		else:
			# Attack from behind OR while turning — FULL damage
			from_behind = true
			sprite.modulate = Color.RED

	health -= actual_damage
	
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(self) and sprite:
			sprite.modulate = Color.WHITE
	)
	
	ScreenEffects.spawn_damage_number(global_position, actual_damage, Color.YELLOW if from_behind else Color.GRAY)
	
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
