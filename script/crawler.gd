# crawler.gd — Enemy that crawls along walls/ceilings and drops onto the player
# IMAGE KEYWORD: "pixel art spider crawler bug enemy sprite 16x16 dark"
extends CharacterBody2D

const CRAWL_SPEED = 40.0
const DROP_SPEED = 250.0
const DETECT_RANGE_X = 32.0  # horizontal range to detect player below
const COIN_DROP = 3
const GRAVITY_VAL = 600.0

enum State { CRAWL, DROP, GROUNDED }

var state: int = State.CRAWL
var direction: int = 1
var health: int = 2
var is_dead: bool = false
var _flip_cooldown: float = 0.0
var player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
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

# Placeholder visual
func _draw() -> void:
	# Dark spider body
	draw_circle(Vector2(0, 0), 6.0, Color(0.25, 0.15, 0.1))
	# Legs
	for i in range(-2, 3):
		if i == 0:
			continue
		draw_line(Vector2(i * 3, 0), Vector2(i * 5, 5), Color(0.2, 0.1, 0.05), 1.0)
		draw_line(Vector2(i * 3, 0), Vector2(i * 5, -5), Color(0.2, 0.1, 0.05), 1.0)
	# Eyes
	draw_circle(Vector2(-2, -2), 1.0, Color(1.0, 0.2, 0.2))
	draw_circle(Vector2(2, -2), 1.0, Color(1.0, 0.2, 0.2))

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	match state:
		State.CRAWL:
			_crawl(delta)
		State.DROP:
			_drop(delta)
		State.GROUNDED:
			_grounded(delta)

func _crawl(delta: float) -> void:
	# Crawls upside-down on ceiling — uses gravity = 0, sticks to top
	velocity.y = -10  # Slight upward push to stay on ceiling
	velocity.x = direction * CRAWL_SPEED

	if _flip_cooldown > 0.0:
		_flip_cooldown -= delta
	elif is_on_wall():
		direction *= -1
		sprite.flip_h = direction < 0
		_flip_cooldown = 0.15

	# Check if player is below
	if player_ref and not player_ref.is_dead:
		var dx = abs(global_position.x - player_ref.global_position.x)
		var dy = player_ref.global_position.y - global_position.y
		if dx < DETECT_RANGE_X and dy > 0 and dy < 160:
			state = State.DROP

	move_and_slide()

func _drop(_delta: float) -> void:
	velocity.x = 0
	velocity.y = DROP_SPEED
	move_and_slide()

	if is_on_floor():
		state = State.GROUNDED
		velocity = Vector2.ZERO

func _grounded(delta: float) -> void:
	# After dropping, just sit still for a moment then patrol on ground
	if not is_on_floor():
		velocity.y += GRAVITY_VAL * delta
	velocity.x = direction * CRAWL_SPEED * 0.5

	if _flip_cooldown > 0.0:
		_flip_cooldown -= delta
	elif is_on_wall():
		direction *= -1
		sprite.flip_h = direction < 0
		_flip_cooldown = 0.15

	move_and_slide()

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return
	health -= damage
	sprite.modulate = Color(3, 3, 3)
	var flash_tw = create_tween()
	flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	var pop_tw = create_tween()
	pop_tw.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.05)
	pop_tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	# Knockback
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var kb_dir = sign(global_position.x - player.global_position.x)
		if kb_dir == 0:
			kb_dir = 1
		velocity.x = kb_dir * 100
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
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
	tween.chain().tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
