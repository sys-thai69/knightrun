extends Area2D
const FIREBALL_SCENE = preload("res://enemy/fireball.tscn")# Or Vector2.RIGHT, Vector2.UP, etc.
# Called when the node enters the scene tree for the first time.
@onready var fire_timer: Timer = $FireTimer
@onready var timer: Timer = $Timer
@onready var muzzle_node: Marker2D = $Marker2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@export var shoot_direction: Vector2 = Vector2.LEFT
# Called every frame. 'delta' is the elapsed time since the previous frame.

## ⏯️ Animation Handler
## ⏯️ Animation Handler
func _on_animated_sprite_2d_animation_finished() -> void:
    # 1. Disconnect the signal immediately upon execution.
    # This prevents the signal from firing again until re-connected by the timer.
    animated_sprite_2d.animation_finished.disconnect(_on_animated_sprite_2d_animation_finished)
    
    # 2. Switch back to the idle animation
    animated_sprite_2d.play("idle")
         
func _ready():
    # Start the shooting cooldown immediately.
    animated_sprite_2d.play("idle")
    fire_timer.start() # Starts the timer based on its 'wait_time' property
    if shoot_direction.x > 0:
        animated_sprite_2d.flip_h = false  # Flip the sprite to face right
    # Check if the horizontal component is negative (LEFT)
    elif shoot_direction.x < 0:
        animated_sprite_2d.flip_h = true # Ensure the sprite faces left (default)
    
    
func _on_fire_timer_timeout():
    # 1. Instantiate the fireball scene
    animated_sprite_2d.play("shooting")
    var fireball = FIREBALL_SCENE.instantiate()


    # 2. Add the fireball to the main scene tree
    get_parent().add_child(fireball) 

    # 3. Calculate position 
    fireball.global_position = muzzle_node.global_position
    
    # 4. PASS the fixed direction to the fireball's script
    fireball.direction = shoot_direction 
    
    if not animated_sprite_2d.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
        animated_sprite_2d.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
    
    # 5. Restart the timer for the next shot
    fire_timer.start()
    
func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    
    print("You died!")
    Engine.time_scale = 0.5
    body.is_dead = true
    
    # Launch the player upward and disable collisions so they fall off the map
    body.velocity.y = -200
    body.set_collision_mask_value(1, false)
    body.set_collision_layer_value(1, false)
    
    if body.has_node("AnimatedSprite2D"):
        body.get_node("AnimatedSprite2D").play("jump")
    
    get_tree().create_timer(1.0, true, false, true).timeout.connect(_on_timer_timeout)


func _on_timer_timeout() -> void:
    Engine.time_scale = 1
    get_tree().reload_current_scene() # Replace
