extends Area2D

func _on_body_entered(_body: Node2D) -> void:
    PlayerData.add_coins(1)
    queue_free()
