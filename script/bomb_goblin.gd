# bomb_goblin.gd — Runs toward player and explodes after a delay
# IMAGE KEYWORD: "pixel art goblin bomb enemy sprite sheet running 32x32"
# EXPLOSION IMAGE KEYWORD: "pixel art explosion effect sprite sheet 32x32"
extends CharacterBody2D

const SPEED = 70.0
const DETECTION_RANGE = 130.0
const EXPLODE_RANGE = 25.0
const EXPLODE_DELAY = 1.0
const EXPLODE_DAMAGE = 2
const EXPLODE_RADIUS = 40.0
const COIN_DROP = 3
const GRAVITY_VAL = 600.0

var health: int = 1
var is_dead: bool = false
var is_exploding: bool = false
var player_ref: CharacterBody2D = null

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

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	# Orange-red goblin body
	draw_rect(Rect2(-5, -7, 10, 14), Color(1.0, 0.4, 0.0))
	# Bomb on head (circle-ish)
	draw_rect(Rect2(-3, -11, 6, 4), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-5, -11, 10, 18), Color.BLACK, false, 1.0)

func _physics_process(delta: float) -> void:
	if is_dead or is_exploding:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY_VAL * delta
	else:
		velocity.y = 0

	if player_ref and not player_ref.is_dead:
		var dist = global_position.distance_to(player_ref.global_position)
		var dir = sign(player_ref.global_position.x - global_position.x)

		if dist < EXPLODE_RANGE:
			_start_explode()
			return

		if dist < DETECTION_RANGE:
			velocity.x = dir * SPEED
			sprite.flip_h = dir < 0
			if sprite and sprite.sprite_frames:
				sprite.play("run")
		else:
			velocity.x = 0
			if sprite and sprite.sprite_frames:
				sprite.play("idle")
	else:
		velocity.x = 0

	move_and_slide()

func _start_explode() -> void:
	is_exploding = true
	velocity = Vector2.ZERO
	# Flash red rapidly before exploding
	var tween = create_tween().set_loops(5)
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	get_tree().create_timer(EXPLODE_DELAY).timeout.connect(_explode)

func _explode() -> void:
	ScreenEffects.shake(6.0, 0.25)
	# Damage everything in radius
	# Check player distance
	if player_ref and not player_ref.is_dead:
		if global_position.distance_to(player_ref.global_position) < EXPLODE_RADIUS:
			player_ref.take_damage(EXPLODE_DAMAGE)

	# Visual explosion effect
	sprite.modulate = Color(1, 0.5, 0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(3, 3), 0.2)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return
	health -= damage
	ScreenEffects.spawn_damage_number(global_position, damage, Color.ORANGE)
	# White flash + scale pop on hit
	sprite.modulate = Color(3, 3, 3)
	var flash_tw = create_tween()
	flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	var pop_tw = create_tween()
	pop_tw.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.05)
	pop_tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	if health <= 0:
		# Killing it prevents explosion
		is_dead = true
		PlayerData.add_coins(COIN_DROP)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
		tween.chain().tween_callback(queue_free)
