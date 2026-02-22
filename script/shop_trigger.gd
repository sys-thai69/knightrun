# shop_trigger.gd — Interact-to-open shop area (separate from checkpoint)
extends Area2D

const SHOP_SCENE = preload("res://scences/shop.tscn")
var player_nearby: bool = false

func _ready() -> void:
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)
    if not body_exited.is_connected(_on_body_exited):
        body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    player_nearby = true
    if has_node("InteractLabel"):
        $InteractLabel.visible = true

func _on_body_exited(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    player_nearby = false
    if has_node("InteractLabel"):
        $InteractLabel.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and player_nearby:
        _open_shop()

func _open_shop() -> void:
    get_tree().paused = true
    var shop = SHOP_SCENE.instantiate()
    get_tree().root.add_child(shop)
