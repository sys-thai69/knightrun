extends Area2D

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return

    if body.has_method("take_damage"):
        body.take_damage(1)
    else:
        # Fallback: go through proper death pipeline
        PlayerData.take_damage(1)

func _on_timer_timeout() -> void:
    Engine.time_scale = 1
    get_tree().reload_current_scene()
