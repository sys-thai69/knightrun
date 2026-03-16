# player_projectile.gd — Player's arrow projectile (glowing version of skeleton archer arrow)
extends Area2D

var vel: Vector2 = Vector2.ZERO
const SPEED = 160.0
const GRAVITY = 400.0  # Same as skeleton archer arrow
var damage: int = 1
var direction: int = 1

func _ready() -> void:
	add_to_group("projectile")
	add_to_group("player_projectile")
	# Auto-destroy after 4 seconds
	var t = Timer.new()
	t.wait_time = 4.0
	t.one_shot = true
	t.autostart = true
	add_child(t)
	t.timeout.connect(queue_free)

func set_direction(dir: int) -> void:
	direction = dir
	# Initial velocity - shoot in direction with slight upward arc
	vel = Vector2(dir * SPEED, -50)
	rotation = vel.angle()
	scale.x = 1  # Don't flip, rotation handles direction

# Glowing arrow visual - cyan/blue glow to distinguish from enemy arrows
func _draw() -> void:
	# Outer glow
	draw_circle(Vector2.ZERO, 6, Color(0.0, 0.8, 1.0, 0.3))
	# Arrow body
	draw_line(Vector2(-6, 0), Vector2(6, 0), Color(0.0, 0.9, 1.0), 2.0)
	# Arrow head
	draw_line(Vector2(6, 0), Vector2(3, -2), Color(0.0, 0.9, 1.0), 2.0)
	draw_line(Vector2(6, 0), Vector2(3, 2), Color(0.0, 0.9, 1.0), 2.0)
	# Inner bright core
	draw_line(Vector2(-4, 0), Vector2(4, 0), Color(1.0, 1.0, 1.0, 0.8), 1.0)

func _physics_process(delta: float) -> void:
	vel.y += GRAVITY * delta
	position += vel * delta
	rotation = vel.angle()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(damage, "ranged")
		ScreenEffects.spawn_damage_number(body.global_position, damage, Color.CYAN)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Don't collide with other player projectiles
	if area.is_in_group("projectile") or area.is_in_group("player_projectile"):
		return
	if area.has_method("take_hit"):
		area.take_hit(damage, "ranged")
	queue_free()

func reflect() -> void:
	vel = -vel
	direction *= -1
	damage = 2
	remove_from_group("projectile")
	remove_from_group("player_projectile")
