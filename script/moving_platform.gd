# moving_platform.gd — Platform that moves horizontally and reverses on wall collision
extends AnimatableBody2D

@export var speed: float = 40.0  # Movement speed in pixels/second
@export var initial_direction: int = 1  # 1 = right, -1 = left

var direction: int = 1
var _raycast_left: RayCast2D
var _raycast_right: RayCast2D

func _ready() -> void:
	direction = initial_direction
	# Get platform width based on scale (base platform is ~32px wide)
	var platform_width = 32.0 * scale.x
	
	# Create raycasts for wall detection
	_raycast_left = RayCast2D.new()
	_raycast_left.target_position = Vector2(-10, 0)
	_raycast_left.collision_mask = 1  # Terrain layer
	_raycast_left.enabled = true
	add_child(_raycast_left)
	
	_raycast_right = RayCast2D.new()
	_raycast_right.target_position = Vector2(platform_width + 10, 0)  # Extend past platform edge
	_raycast_right.collision_mask = 1  # Terrain layer
	_raycast_right.enabled = true
	add_child(_raycast_right)

func _physics_process(delta: float) -> void:
	# Check for wall collision
	if direction > 0 and _raycast_right.is_colliding():
		direction = -1
	elif direction < 0 and _raycast_left.is_colliding():
		direction = 1
	
	# Move the platform
	var movement = Vector2(direction * speed * delta, 0)
	global_position += movement
