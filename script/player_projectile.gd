# player_projectile.gd — Player's glowing cyan arrow (uses skeleton archer Arrow.png sprite)
extends Area2D

var vel: Vector2 = Vector2.ZERO
const SPEED = 260.0  # Faster flight speed for stronger momentum
const GRAVITY = 360.0
var damage: int = 1

func _ready() -> void:
	add_to_group("projectile")
	add_to_group("player_projectile")
	var t = Timer.new()
	t.wait_time = 4.0
	t.one_shot = true
	t.autostart = true
	add_child(t)
	t.timeout.connect(queue_free)

func set_direction(dir: int) -> void:
	vel = Vector2(dir * SPEED, -70)
	rotation = vel.angle()

func _physics_process(delta: float) -> void:
	vel.y += GRAVITY * delta
	position += vel * delta
	rotation = vel.angle()

func _on_body_entered(body: Node2D) -> void:
	# Never hit the player who fired this
	if body.is_in_group("player"):
		return
	if body.has_method("take_hit"):
		body.take_hit(damage, "ranged")
		ScreenEffects.spawn_damage_number(body.global_position, damage, Color.CYAN)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile") or area.is_in_group("player_projectile"):
		return
	if area.has_method("take_hit"):
		area.take_hit(damage, "ranged")
	queue_free()

func reflect() -> void:
	vel = -vel
	damage = 2
	remove_from_group("projectile")
	remove_from_group("player_projectile")
