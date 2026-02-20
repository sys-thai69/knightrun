# player_projectile.gd — Throwing knife / ranged attack projectile
# IMAGE KEYWORD: "pixel art throwing knife sprite sheet 16x16" or "pixel art kunai projectile"
extends Area2D

var direction: int = 1
const SPEED = 180.0
var damage: int = 1

func _ready() -> void:
	add_to_group("projectile")
	# Create placeholder visuals if no sprite assigned
	if not has_node("Sprite2D"):
		var sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	# Auto-destroy after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func set_direction(dir: int) -> void:
	direction = dir
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = dir < 0
	scale.x = dir

# Placeholder visual — remove when real sprites are added
func _draw() -> void:
	draw_rect(Rect2(-4, -2, 8, 4), Color(0.0, 0.85, 1.0))
	draw_rect(Rect2(-4, -2, 8, 4), Color.WHITE, false, 1.0)

func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(damage, "ranged")
		ScreenEffects.spawn_damage_number(body.global_position, damage, Color.CYAN)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Don't collide with other player projectiles
	if area.is_in_group("projectile"):
		return
	if area.has_method("take_hit"):
		area.take_hit(damage, "ranged")
	queue_free()

func reflect() -> void:
	direction *= -1
	scale.x = direction
	# Reflected projectiles damage enemies
	damage = 2
	# Remove from projectile group so player doesn't re-reflect
	remove_from_group("projectile")
