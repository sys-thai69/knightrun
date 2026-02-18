extends Area2D
@onready var gamemanager: Node = $"../Gamemanager"


# Called when the node enters the scene tree for the first tim

func _on_body_entered(_body: Node2D) -> void:
    gamemanager.add_coins(1)
    queue_free() # Replace with function body.
