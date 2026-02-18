extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -200.0

var jump_count = 0
const MAX_JUMPS = 2
var is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    sprite.animation_finished.connect(_on_sprite_animation_finished)

func _on_sprite_animation_finished() -> void:
    if sprite.animation == "jump1" and not is_on_floor():
        sprite.play("idle")

func _physics_process(delta: float) -> void:
    # Always apply gravity
    if not is_on_floor():
        velocity += get_gravity() * delta

    # If dead, stop input and let gravity do its thing
    if is_dead:
        velocity.x = 0
        move_and_slide()
        return

    # Jump logic
    if is_on_floor():
        jump_count = 0
        if velocity.x == 0 and sprite.animation != "idle":
            sprite.play("idle")

    if Input.is_action_just_pressed("jump"):
        if is_on_floor() or jump_count < MAX_JUMPS:
            velocity.y = JUMP_VELOCITY
            jump_count += 1
            if jump_count == 1:
                sprite.play("jump")
            else:
                sprite.play("jump1")

    # Movement
    var direction := Input.get_axis("move_left", "move_right")

    if direction:
        velocity.x = direction * SPEED
        if direction > 0:
            sprite.flip_h = false
        elif direction < 0:
            sprite.flip_h = true
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    # Animation
    if not is_on_floor():
        if (sprite.animation != "jump" and sprite.animation != "jump1") and velocity.y > 0:
            sprite.play("jump")
    elif direction != 0:
        sprite.play("run")
    else:
        sprite.play("idle")

    move_and_slide()
