# checkpoint.gd — Checkpoint (save point + heal). Shop is separate.
extends Area2D

var activated: bool = false

func _ready() -> void:
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    if not activated:
        activated = true
        PlayerData.full_heal()
        PlayerData.checkpoint_position = global_position + Vector2(0, -15)
        PlayerData.has_checkpoint = true
        SaveManager.save_game()
        # Visual feedback: change color to show it's activated
        if has_node("AnimatedSprite2D"):
            $AnimatedSprite2D.modulate = Color(0.5, 1.0, 0.5)
