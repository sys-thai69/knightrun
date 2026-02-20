extends Area2D

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return

    if body.has_method("take_damage"):
        body.take_damage(1)
    else:
        # Fallback for old behavior
        body.is_dead = true
        Engine.time_scale = 0.5
        body.velocity.y = -200
        body.set_collision_mask_value(1, false)
        body.set_collision_layer_value(1, false)
        if body.has_node("AnimatedSprite2D"):
            body.get_node("AnimatedSprite2D").play("jump")
        get_tree().create_timer(1.0, true, false, true).timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
    Engine.time_scale = 1
    get_tree().reload_current_scene()
