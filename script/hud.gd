# hud.gd — Main HUD showing health hearts and coin count
extends CanvasLayer

@onready var coin_label: Label = $CoinLabel
@onready var hp_container: HBoxContainer = $HPContainer

var heart_nodes: Array[Label] = []

func _ready() -> void:
    PlayerData.coins_changed.connect(_on_coins_changed)
    PlayerData.health_changed.connect(_on_health_changed)
    coin_label.text = "Coins: %d" % PlayerData.coins
    _rebuild_hearts()

func _on_coins_changed(new_count: int) -> void:
    coin_label.text = "Coins: %d" % new_count

func _on_health_changed(_current_hp: int, _max_hp: int) -> void:
    _rebuild_hearts()

func _rebuild_hearts() -> void:
    # Clear old hearts
    for child in hp_container.get_children():
        child.queue_free()
    heart_nodes.clear()

    var max_hp = PlayerData.max_health
    var current_hp = PlayerData.current_health

    for i in range(max_hp):
        var heart = Label.new()
        heart.add_theme_font_size_override("font_size", 16)
        if i < current_hp:
            heart.text = "♥"
            heart.add_theme_color_override("font_color", Color.RED)
        else:
            heart.text = "♡"
            heart.add_theme_color_override("font_color", Color.DARK_RED)
        hp_container.add_child(heart)
