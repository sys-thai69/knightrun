# shop.gd — Upgrade shop UI
extends CanvasLayer

signal shop_closed

@onready var sword_btn: Button = $Panel/VBoxContainer/SwordBtn
@onready var shield_btn: Button = $Panel/VBoxContainer/ShieldBtn
@onready var health_btn: Button = $Panel/VBoxContainer/HealthBtn
@onready var speed_btn: Button = $Panel/VBoxContainer/SpeedBtn
@onready var potion_btn: Button = $Panel/VBoxContainer/PotionBtn
@onready var ranged_btn: Button = $Panel/VBoxContainer/RangedBtn
@onready var dash_btn: Button = $Panel/VBoxContainer/DashBtn
@onready var close_btn: Button = $Panel/VBoxContainer/CloseBtn
@onready var coins_label: Label = $Panel/CoinsLabel
@onready var info_label: Label = $Panel/InfoLabel

const POTION_COST = 3

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _update_ui()
    sword_btn.pressed.connect(_on_sword)
    shield_btn.pressed.connect(_on_shield)
    health_btn.pressed.connect(_on_health)
    speed_btn.pressed.connect(_on_speed)
    potion_btn.pressed.connect(_on_potion)
    if ranged_btn:
        ranged_btn.pressed.connect(_on_ranged)
    if dash_btn:
        dash_btn.pressed.connect(_on_dash)
    close_btn.pressed.connect(_on_close)

func _update_ui() -> void:
    coins_label.text = "💰 Coins: %d" % PlayerData.coins

    # Sword
    if not PlayerData.has_sword:
        sword_btn.text = "⚔ Buy Sword (%d coins)" % PlayerData.SWORD_COST
        sword_btn.disabled = PlayerData.coins < PlayerData.SWORD_COST
    else:
        var sc = PlayerData.get_upgrade_cost("sword")
        if sc == -1:
            sword_btn.text = "⚔ Sword: MAX LEVEL"
            sword_btn.disabled = true
        else:
            sword_btn.text = "⚔ Sword Lv%d → Lv%d (%d coins)" % [PlayerData.sword_level, PlayerData.sword_level + 1, sc]
            sword_btn.disabled = not PlayerData.can_upgrade("sword")

    # Shield
    if not PlayerData.has_shield:
        shield_btn.text = "🛡 Buy Shield (%d coins)" % PlayerData.SHIELD_COST
        shield_btn.disabled = PlayerData.coins < PlayerData.SHIELD_COST
    else:
        var shc = PlayerData.get_upgrade_cost("shield")
        if shc == -1:
            shield_btn.text = "🛡 Shield: MAX LEVEL"
            shield_btn.disabled = true
        else:
            shield_btn.text = "🛡 Shield Lv%d → Lv%d (%d coins)" % [PlayerData.shield_level, PlayerData.shield_level + 1, shc]
            shield_btn.disabled = not PlayerData.can_upgrade("shield")

    # Health
    var hc = PlayerData.get_upgrade_cost("health")
    if hc == -1:
        health_btn.text = "❤ Health: MAX LEVEL"
        health_btn.disabled = true
    else:
        health_btn.text = "❤ Health Lv%d → Lv%d (%d coins)" % [PlayerData.health_level, PlayerData.health_level + 1, hc]
        health_btn.disabled = not PlayerData.can_upgrade("health")

    # Speed
    var spc = PlayerData.get_upgrade_cost("speed")
    if spc == -1:
        speed_btn.text = "⚡ Speed: MAX LEVEL"
        speed_btn.disabled = true
    else:
        speed_btn.text = "⚡ Speed Lv%d → Lv%d (%d coins)" % [PlayerData.speed_level, PlayerData.speed_level + 1, spc]
        speed_btn.disabled = not PlayerData.can_upgrade("speed")

    # Potion
    potion_btn.text = "🧪 Health Potion (%d coins) [%d/%d HP]" % [POTION_COST, PlayerData.current_health, PlayerData.max_health]
    potion_btn.disabled = PlayerData.coins < POTION_COST or PlayerData.current_health >= PlayerData.max_health

    # Ranged Attack Unlock - DISABLED
    if ranged_btn:
        ranged_btn.visible = false

    # Dash Unlock
    if dash_btn:
        if PlayerData.has_dash:
            dash_btn.text = "💨 Dash: OWNED"
            dash_btn.disabled = true
        else:
            dash_btn.text = "💨 Dash (%d coins)" % PlayerData.DASH_COST
            dash_btn.disabled = PlayerData.coins < PlayerData.DASH_COST

    var atk_text = str(PlayerData.get_attack_damage()) if PlayerData.has_sword else "--"
    var shd_text = str(PlayerData.get_shield_durability()) if PlayerData.has_shield else "--"
    info_label.text = "⚔ ATK: %s | 🛡 DEF: %s | ❤ HP: %d/%d | ⚡ SPD: %d" % [
        atk_text,
        shd_text,
        PlayerData.current_health,
        PlayerData.max_health,
        100 + int(PlayerData.get_speed_bonus())
    ]

func _on_sword() -> void:
    if not PlayerData.has_sword:
        if PlayerData.spend_coins(PlayerData.SWORD_COST):
            PlayerData.has_sword = true
            _update_ui()
            _show_unlock_popup("SWORD UNLOCKED!", "Press J to attack enemies.\nHold J for a charged strike!")
        return
    PlayerData.upgrade("sword")
    AchievementManager.check_upgrade_achievements()
    _update_ui()

func _on_shield() -> void:
    if not PlayerData.has_shield:
        if PlayerData.spend_coins(PlayerData.SHIELD_COST):
            PlayerData.has_shield = true
            _update_ui()
            _show_unlock_popup("SHIELD UNLOCKED!", "Hold K to block attacks.\nTap K with precise timing to parry!")
        return
    PlayerData.upgrade("shield")
    AchievementManager.check_upgrade_achievements()
    _update_ui()

func _on_health() -> void:
    PlayerData.upgrade("health")
    AchievementManager.check_upgrade_achievements()
    _update_ui()

func _on_speed() -> void:
    PlayerData.upgrade("speed")
    AchievementManager.check_upgrade_achievements()
    _update_ui()

func _on_potion() -> void:
    if PlayerData.spend_coins(POTION_COST):
        PlayerData.heal(1)
        _update_ui()

func _on_ranged() -> void:
    if not PlayerData.has_ranged and PlayerData.spend_coins(PlayerData.RANGED_COST):
        PlayerData.has_ranged = true
        _update_ui()
        _show_unlock_popup("THROWING KNIFE UNLOCKED!", "Press L to throw knives at enemies.\nCooldown: 0.6s")

func _on_dash() -> void:
    if not PlayerData.has_dash and PlayerData.spend_coins(PlayerData.DASH_COST):
        PlayerData.has_dash = true
        _update_ui()
        _show_unlock_popup("DASH UNLOCKED!", "Press Shift to dash.\nYou are invincible during dash!")

func _on_close() -> void:
    get_tree().paused = false
    SaveManager.save_game()
    shop_closed.emit()
    queue_free()

func _show_unlock_popup(title_text: String, desc_text: String) -> void:
    var popup = Panel.new()
    popup.name = "UnlockPopup"
    popup.custom_minimum_size = Vector2(250, 100)
    popup.position = Vector2(50, 20)
    popup.z_index = 200

    var vbox = VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 4)

    var title_label = Label.new()
    title_label.text = title_text
    title_label.add_theme_font_size_override("font_size", 14)
    title_label.add_theme_color_override("font_color", Color.GOLD)
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title_label)

    var desc_label = Label.new()
    desc_label.text = desc_text
    desc_label.add_theme_font_size_override("font_size", 10)
    desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(desc_label)

    popup.add_child(vbox)
    add_child(popup)

    # Auto-dismiss after 3 seconds
    get_tree().create_timer(3.0).timeout.connect(func():
        if is_instance_valid(popup):
            var tw = popup.create_tween()
            tw.tween_property(popup, "modulate:a", 0.0, 0.5)
            tw.tween_callback(popup.queue_free)
    )
