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
	coins_label.text = "Coins: %d" % PlayerData.coins

	# Sword
	var sc = PlayerData.get_upgrade_cost("sword")
	if sc == -1:
		sword_btn.text = "Sword: MAX"
		sword_btn.disabled = true
	else:
		sword_btn.text = "Sword Lv%d → Lv%d (%d coins)" % [PlayerData.sword_level, PlayerData.sword_level + 1, sc]
		sword_btn.disabled = not PlayerData.can_upgrade("sword")

	# Shield
	var shc = PlayerData.get_upgrade_cost("shield")
	if shc == -1:
		shield_btn.text = "Shield: MAX"
		shield_btn.disabled = true
	else:
		shield_btn.text = "Shield Lv%d → Lv%d (%d coins)" % [PlayerData.shield_level, PlayerData.shield_level + 1, shc]
		shield_btn.disabled = not PlayerData.can_upgrade("shield")

	# Health
	var hc = PlayerData.get_upgrade_cost("health")
	if hc == -1:
		health_btn.text = "Health: MAX"
		health_btn.disabled = true
	else:
		health_btn.text = "Health Lv%d → Lv%d (%d coins)" % [PlayerData.health_level, PlayerData.health_level + 1, hc]
		health_btn.disabled = not PlayerData.can_upgrade("health")

	# Speed
	var spc = PlayerData.get_upgrade_cost("speed")
	if spc == -1:
		speed_btn.text = "Speed: MAX"
		speed_btn.disabled = true
	else:
		speed_btn.text = "Speed Lv%d → Lv%d (%d coins)" % [PlayerData.speed_level, PlayerData.speed_level + 1, spc]
		speed_btn.disabled = not PlayerData.can_upgrade("speed")

	# Potion
	potion_btn.text = "Health Potion (%d coins) [HP: %d/%d]" % [POTION_COST, PlayerData.current_health, PlayerData.max_health]
	potion_btn.disabled = PlayerData.coins < POTION_COST or PlayerData.current_health >= PlayerData.max_health

	# Ranged Attack Unlock
	if ranged_btn:
		if PlayerData.has_ranged:
			ranged_btn.text = "Throwing Knife: OWNED"
			ranged_btn.disabled = true
		else:
			ranged_btn.text = "Throwing Knife (%d coins) [Press L]" % PlayerData.RANGED_COST
			ranged_btn.disabled = PlayerData.coins < PlayerData.RANGED_COST

	# Dash Unlock
	if dash_btn:
		if PlayerData.has_dash:
			dash_btn.text = "Dash: OWNED"
			dash_btn.disabled = true
		else:
			dash_btn.text = "Dash (%d coins) [Press Shift]" % PlayerData.DASH_COST
			dash_btn.disabled = PlayerData.coins < PlayerData.DASH_COST

	info_label.text = "ATK: %d | Shield: %d | HP: %d/%d | SPD: %d" % [
		PlayerData.get_attack_damage(),
		PlayerData.get_shield_durability(),
		PlayerData.current_health,
		PlayerData.max_health,
		100 + int(PlayerData.get_speed_bonus())
	]

func _on_sword() -> void:
	PlayerData.upgrade("sword")
	_update_ui()

func _on_shield() -> void:
	PlayerData.upgrade("shield")
	_update_ui()

func _on_health() -> void:
	PlayerData.upgrade("health")
	_update_ui()

func _on_speed() -> void:
	PlayerData.upgrade("speed")
	_update_ui()

func _on_potion() -> void:
	if PlayerData.spend_coins(POTION_COST):
		PlayerData.heal(1)
		_update_ui()

func _on_ranged() -> void:
	if not PlayerData.has_ranged and PlayerData.spend_coins(PlayerData.RANGED_COST):
		PlayerData.has_ranged = true
		_update_ui()

func _on_dash() -> void:
	if not PlayerData.has_dash and PlayerData.spend_coins(PlayerData.DASH_COST):
		PlayerData.has_dash = true
		_update_ui()

func _on_close() -> void:
	get_tree().paused = false
	SaveManager.save_game()
	shop_closed.emit()
	queue_free()
