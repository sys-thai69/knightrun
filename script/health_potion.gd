# health_potion.gd — Pickup that restores 1 HP
extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if PlayerData.current_health < PlayerData.max_health:
		PlayerData.heal(1)
		queue_free()
