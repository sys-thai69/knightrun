# shield_knight.gd — Can only be damaged from behind; blocks frontal attacks
# IMAGE KEYWORD: "pixel art shield knight enemy sprite sheet sword shield 32x32"
extends CharacterBody2D

const SPEED = 35.0
const COIN_DROP = 6
const GRAVITY_VAL = 600.0

var health: int = 4
var is_dead: bool = false
var direction: int = 1
var player_ref: CharacterBody2D = null
var facing_right: bool = true

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

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	# Gray armored body
	draw_rect(Rect2(-7, -11, 14, 22), Color(0.65, 0.65, 0.7))
	# Shield on front side
	var shield_x = 5 if facing_right else -9
	draw_rect(Rect2(shield_x, -8, 4, 16), Color(0.4, 0.4, 0.5))
	draw_rect(Rect2(-7, -11, 14, 22), Color.BLACK, false, 1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY_VAL * delta
	else:
		velocity.y = 0

	# Always face the player
	if player_ref and not player_ref.is_dead:
		var dir_to_player = sign(player_ref.global_position.x - global_position.x)
		if dir_to_player != 0:
			facing_right = dir_to_player > 0
			sprite.flip_h = not facing_right
			direction = int(dir_to_player)
			queue_redraw()

	# Patrol toward player
	if ray_cast_right.is_colliding():
		direction *= -1
	if not ray_cast_down.is_colliding():
		direction *= -1

	velocity.x = direction * SPEED
	move_and_slide()

	if sprite and sprite.sprite_frames:
		if abs(velocity.x) > 1:
			sprite.play("run")
		else:
			sprite.play("idle")

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return

	# Check if attack is from behind (player is behind the shield)
	if player_ref:
		var player_side = sign(player_ref.global_position.x - global_position.x)
		var shield_facing = 1 if facing_right else -1

		if player_side == shield_facing:
			# Attack from front — BLOCKED!
			sprite.modulate = Color(0.5, 0.5, 1.0)
			get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color.WHITE)
			ScreenEffects.spawn_damage_number(global_position, 0, Color.GRAY)
			return

	# Attack from behind — takes damage!
	health -= damage
	sprite.modulate = Color.RED
	get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color.WHITE)
	ScreenEffects.spawn_damage_number(global_position, damage, Color.YELLOW)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	PlayerData.add_coins(COIN_DROP)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
	tween.chain().tween_callback(queue_free)

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
