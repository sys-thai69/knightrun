# ladder.gd — Ladder climbable area detection
extends AnimatableBody2D

func _ready() -> void:
	# Create an Area2D for detecting the player
	var area = Area2D.new()
	area.name = "ClimbArea"
	area.collision_layer = 0
	area.collision_mask = 2  # Detect player (layer 2)
	
	# Use the same collision shape size as the body
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(15, 14)  # Match the ladder size
	shape.shape = rect
	shape.position = Vector2(0.7, -1.0)
	area.add_child(shape)
	add_child(area)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	# Add to ladder group for easy lookup
	add_to_group("ladder")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("enter_ladder"):
		body.enter_ladder()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("exit_ladder"):
		body.exit_ladder()
