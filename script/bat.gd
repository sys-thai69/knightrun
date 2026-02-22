# bat.gd — Flying enemy that moves in sine wave, chases player when close
# IMAGE KEYWORD: "pixel art bat enemy sprite sheet flying animation 32x32"
extends CharacterBody2D

const SPEED = 50.0
const CHASE_SPEED = 80.0
const CHASE_RANGE = 120.0
const SINE_AMPLITUDE = 30.0
const SINE_FREQUENCY = 2.5
const COIN_DROP = 3

var health: int = 2
var is_dead: bool = false
var direction: int = 1
var time: float = 0.0
var start_y: float = 0.0
var player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	start_y = global_position.y
	add_to_group("enemy")
	# Scale HP with NG+
	health = int(health * PlayerData.get_enemy_hp_multiplier())
	# Off-screen optimization
	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-20, -20, 40, 40)
	add_child(notifier)
	notifier.screen_exited.connect(func(): set_physics_process(false))
	notifier.screen_entered.connect(func(): set_physics_process(true))
	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]
	if sprite and sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
		sprite.play("fly")

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	# Purple bat body
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.6, 0.15, 0.9))
	# Wings
	draw_rect(Rect2(-14, -4, 6, 8), Color(0.5, 0.1, 0.8))
	draw_rect(Rect2(8, -4, 6, 8), Color(0.5, 0.1, 0.8))
	draw_rect(Rect2(-14, -8, 28, 16), Color.BLACK, false, 1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	time += delta

	if player_ref and not player_ref.is_dead:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist < CHASE_RANGE:
			# Chase player
			var dir_to_player = (player_ref.global_position - global_position).normalized()
			velocity = dir_to_player * CHASE_SPEED
			sprite.flip_h = dir_to_player.x < 0
		else:
			# Sine wave patrol
			velocity.x = direction * SPEED
			global_position.y = start_y + sin(time * SINE_FREQUENCY) * SINE_AMPLITUDE
			velocity.y = 0
			sprite.flip_h = direction < 0
	else:
		velocity.x = direction * SPEED
		global_position.y = start_y + sin(time * SINE_FREQUENCY) * SINE_AMPLITUDE
		velocity.y = 0

	move_and_slide()

	# Reverse at walls
	if is_on_wall():
		direction *= -1

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

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
