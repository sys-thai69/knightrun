# hud.gd — Main HUD showing health hearts and coin count
extends CanvasLayer

@onready var coin_label: Label = $CoinLabel
@onready var hp_container: HBoxContainer = $HPContainer

var heart_nodes: Array[Label] = []
var timer_label: Label = null

func _ready() -> void:
    PlayerData.coins_changed.connect(_on_coins_changed)
    PlayerData.health_changed.connect(_on_health_changed)
    coin_label.text = "Coins: %d" % PlayerData.coins
    _rebuild_hearts()
    # Create time trial timer label
    timer_label = Label.new()
    timer_label.name = "TimerLabel"
    timer_label.add_theme_font_size_override("font_size", 12)
    timer_label.add_theme_color_override("font_color", Color.YELLOW)
    timer_label.position = Vector2(10, 50)
    timer_label.visible = false
    add_child(timer_label)

func _process(_delta: float) -> void:
    if PlayerData.time_trial_active and timer_label:
        timer_label.visible = true
        var t = PlayerData.time_trial_elapsed
        var mins = int(t) / 60
        var secs = int(t) % 60
        var ms = int(fmod(t, 1.0) * 100)
        timer_label.text = "%02d:%02d.%02d" % [mins, secs, ms]
        if PlayerData.best_time > 0:
            timer_label.text += "  Best: %02d:%02d" % [int(PlayerData.best_time) / 60, int(PlayerData.best_time) % 60]
    elif timer_label:
        timer_label.visible = false
    # Show NG+ indicator
    if PlayerData.ng_plus_level > 0:
        coin_label.text = "Coins: %d  [NG+%d]" % [PlayerData.coins, PlayerData.ng_plus_level]

func _on_coins_changed(new_count: int) -> void:
    if PlayerData.ng_plus_level > 0:
        coin_label.text = "Coins: %d  [NG+%d]" % [new_count, PlayerData.ng_plus_level]
    else:
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
