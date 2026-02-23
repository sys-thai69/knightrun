# hud.gd — Main HUD showing health hearts, coin count, and stamina bar
extends CanvasLayer

@onready var coin_label: Label = $CoinLabel
@onready var hp_container: HBoxContainer = $HPContainer

var heart_nodes: Array[Label] = []
var timer_label: Label = null
var stamina_bar: ProgressBar = null
var stamina_label: Label = null
var player_ref: CharacterBody2D = null

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
    timer_label.position = Vector2(10, 52)  # Below stamina bar
    timer_label.visible = false
    add_child(timer_label)
    # Create stamina bar
    _create_stamina_bar()
    # Get player reference
    await get_tree().process_frame
    var players = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        player_ref = players[0]

func _create_stamina_bar() -> void:
    # Label for stamina
    stamina_label = Label.new()
    stamina_label.name = "StaminaLabel"
    stamina_label.text = "ST"
    stamina_label.add_theme_font_size_override("font_size", 10)
    stamina_label.add_theme_color_override("font_color", Color.WHITE)
    stamina_label.position = Vector2(10, 32)
    add_child(stamina_label)
    # Progress bar for stamina
    stamina_bar = ProgressBar.new()
    stamina_bar.name = "StaminaBar"
    stamina_bar.min_value = 0
    stamina_bar.max_value = 100
    stamina_bar.value = 100
    stamina_bar.show_percentage = false
    stamina_bar.size = Vector2(80, 10)
    stamina_bar.position = Vector2(28, 34)
    # Style the stamina bar with green/yellow colors
    var style_bg = StyleBoxFlat.new()
    style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
    style_bg.corner_radius_top_left = 2
    style_bg.corner_radius_top_right = 2
    style_bg.corner_radius_bottom_left = 2
    style_bg.corner_radius_bottom_right = 2
    var style_fill = StyleBoxFlat.new()
    style_fill.bg_color = Color(0.2, 0.8, 0.3, 0.9)  # Green
    style_fill.corner_radius_top_left = 2
    style_fill.corner_radius_top_right = 2
    style_fill.corner_radius_bottom_left = 2
    style_fill.corner_radius_bottom_right = 2
    stamina_bar.add_theme_stylebox_override("background", style_bg)
    stamina_bar.add_theme_stylebox_override("fill", style_fill)
    add_child(stamina_bar)

func _process(_delta: float) -> void:
    # Update stamina bar
    if player_ref and is_instance_valid(player_ref) and stamina_bar:
        stamina_bar.value = player_ref.current_stamina
        # Change color based on stamina level
        var fill_style = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
        if fill_style:
            if player_ref.current_stamina < 30:
                fill_style.bg_color = Color(0.9, 0.3, 0.2, 0.9)  # Red when low
            elif player_ref.current_stamina < 60:
                fill_style.bg_color = Color(0.9, 0.8, 0.2, 0.9)  # Yellow when medium
            else:
                fill_style.bg_color = Color(0.2, 0.8, 0.3, 0.9)  # Green when high
    
    if PlayerData.time_trial_active and timer_label:
        timer_label.visible = true
        var t = PlayerData.time_trial_elapsed
        @warning_ignore("integer_division")
        var mins: int = int(t) / 60
        var secs: int = int(t) % 60
        var ms: int = int(fmod(t, 1.0) * 100)
        timer_label.text = "%02d:%02d.%02d" % [mins, secs, ms]
        if PlayerData.best_time > 0:
            @warning_ignore("integer_division")
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
        heart_nodes.append(heart)
