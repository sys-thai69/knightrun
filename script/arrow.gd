# arrow.gd — Parabolic arrow projectile fired by Skeleton Archer
extends Area2D

var vel: Vector2 = Vector2.ZERO
const GRAVITY = 400.0
var damage: int = 1

func _ready() -> void:
	add_to_group("projectile")
	# Auto-destroy after 5 seconds
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func set_velocity(v: Vector2) -> void:
	vel = v
	rotation = vel.angle()

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	draw_rect(Rect2(-4, -2, 8, 4), Color(0.55, 0.27, 0.07))
	# Arrowhead
	draw_rect(Rect2(4, -3, 3, 6), Color(0.4, 0.4, 0.4))

func _physics_process(delta: float) -> void:
	vel.y += GRAVITY * delta
	position += vel * delta
	rotation = vel.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func reflect() -> void:
	vel = -vel
	damage = 2
	remove_from_group("projectile")
	# Now it damages enemies instead
	collision_mask = 2  # Enemy layer
