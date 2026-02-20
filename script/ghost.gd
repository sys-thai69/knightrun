# ghost.gd — Invisible enemy that becomes visible when player is near, passes through walls
# IMAGE KEYWORD: "pixel art ghost enemy sprite sheet transparent fade 32x32"
extends CharacterBody2D

const SPEED = 45.0
const REVEAL_RANGE = 80.0
const DETECTION_RANGE = 150.0
const COIN_DROP = 5

var health: int = 2
var is_dead: bool = false
var player_ref: CharacterBody2D = null
var is_visible_to_player: bool = false
var _visibility_tween: Tween = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
	# Scale HP with NG+
	health = int(health * PlayerData.get_enemy_hp_multiplier())
	# Ghosts don't collide with terrain — they float through walls
	set_collision_mask_value(1, false)
	modulate = Color(1, 1, 1, 0.05)  # Start nearly invisible (whole node)
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
	# Ghostly blue shape
	draw_rect(Rect2(-10, -10, 20, 20), Color(0.4, 0.6, 1.0, 0.7))
	# "Eyes"
	draw_rect(Rect2(-6, -6, 4, 4), Color.WHITE)
	draw_rect(Rect2(2, -6, 4, 4), Color.WHITE)
	draw_rect(Rect2(-10, -10, 20, 20), Color(0.6, 0.8, 1.0), false, 1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player_ref and not player_ref.is_dead:
		var dist = global_position.distance_to(player_ref.global_position)

		# Visibility based on distance
		if dist < REVEAL_RANGE and not is_visible_to_player:
			is_visible_to_player = true
			if _visibility_tween:
				_visibility_tween.kill()
			_visibility_tween = create_tween()
			_visibility_tween.tween_property(self, "modulate:a", 0.8, 0.3)
		elif dist >= REVEAL_RANGE and is_visible_to_player:
			is_visible_to_player = false
			if _visibility_tween:
				_visibility_tween.kill()
			_visibility_tween = create_tween()
			_visibility_tween.tween_property(self, "modulate:a", 0.05, 0.5)

		# Chase if in detection range
		if dist < DETECTION_RANGE:
			var dir = (player_ref.global_position - global_position).normalized()
			velocity = dir * SPEED
			sprite.flip_h = dir.x < 0
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 50 * delta)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func take_hit(damage: int, _source_type: String = "melee") -> void:
	if is_dead:
		return
	health -= damage
	sprite.modulate = Color(1, 0.3, 0.3, 0.8)
	get_tree().create_timer(0.1).timeout.connect(func(): sprite.modulate = Color.WHITE)
	ScreenEffects.spawn_damage_number(global_position, damage, Color.PURPLE)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	PlayerData.add_coins(COIN_DROP)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.5)
	tween.tween_callback(queue_free)

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
