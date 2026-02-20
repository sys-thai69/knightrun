# Save this code in: res://enemy/fireball.gd
extends Area2D

# This variable is set by the Slime script
var direction: Vector2 = Vector2.ZERO:
    set(value):
        direction = value
        # Flip sprite based on direction when it's set
        if animated_sprite_2d:
            animated_sprite_2d.flip_h = direction.x < 0

const SPEED = 100 # Adjust as needed
@onready var timer: Timer = $Timer
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft

func _ready() -> void:
    add_to_group("projectile")


func _physics_process(delta):
    # Use the direction passed from the Slime
    position += direction * SPEED * delta

    # Check if raycast hits a wall/tilemap
    if ray_cast_right.is_colliding() or ray_cast_left.is_colliding():
        queue_free()


func _on_body_entered(body: Node2D) -> void:
    if body.name == "Player" or body.name == "player":
        if body.has_method("take_damage"):
            body.take_damage(1)
        set_physics_process(false)
        animated_sprite_2d.visible = false
        $CollisionShape2D.set_deferred("disabled", true)
        queue_free()
    elif body is StaticBody2D:
        queue_free()

func _on_timer_timeout() -> void:
    Engine.time_scale = 1

func reflect() -> void:
    direction = -direction
    if animated_sprite_2d:
        animated_sprite_2d.flip_h = direction.x < 0
    # Reflected fireballs damage enemies
    if is_in_group("projectile"):
        remove_from_group("projectile")
