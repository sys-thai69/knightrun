extends Area2D

const MAGNET_RANGE = 20.0  # Reduced from 40
const MAGNET_SPEED = 120.0
var being_collected: bool = false
var coin_id: String = ""

func _ready() -> void:
    # Generate unique ID based on position
    coin_id = "coin_%d_%d" % [int(global_position.x), int(global_position.y)]
    # Check if already collected
    if PlayerData.collected_coins.has(coin_id):
        queue_free()
        return

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
    # Mark as collected permanently
    if coin_id != "" and not PlayerData.collected_coins.has(coin_id):
        PlayerData.collected_coins.append(coin_id)
    PlayerData.add_coins(1)
    # Collect effect: pop and fade
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
    tween.tween_property(self, "modulate:a", 0.0, 0.15)
    tween.chain().tween_callback(queue_free)
