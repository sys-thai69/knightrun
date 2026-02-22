extends Area2D

const MAGNET_RANGE = 40.0
const MAGNET_SPEED = 120.0
var being_collected: bool = false

func _physics_process(delta: float) -> void:
    if being_collected:
        return
    # Find player and check distance
    var players = get_tree().get_nodes_in_group("player")
    if players.size() == 0:
        return
    var player = players[0]
    var dist = global_position.distance_to(player.global_position)
    if dist < MAGNET_RANGE and dist > 2.0:
        # Lerp toward player
        var dir = (player.global_position - global_position).normalized()
        global_position += dir * MAGNET_SPEED * delta

func _on_body_entered(_body: Node2D) -> void:
    if being_collected or not _body.is_in_group("player"):
        return
    being_collected = true
    PlayerData.add_coins(1)
    # Collect effect: pop and fade
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
    tween.tween_property(self, "modulate:a", 0.0, 0.15)
    tween.chain().tween_callback(queue_free)
