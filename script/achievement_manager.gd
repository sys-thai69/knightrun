# achievement_manager.gd — Autoload for managing and displaying achievements
extends Node

# Achievement definitions: id -> {name, description, icon}
const ACHIEVEMENTS = {
	"game_complete": {"name": "Victory!", "desc": "Complete the game"},
	"deathless": {"name": "Untouchable", "desc": "Beat the game without dying"},
	"ng_plus_complete": {"name": "Eternal Knight", "desc": "Complete New Game+"},
	"first_kill": {"name": "First Blood", "desc": "Defeat your first enemy"},
	"boss_slayer": {"name": "Boss Slayer", "desc": "Defeat the final boss"},
	"coin_hoarder": {"name": "Coin Hoarder", "desc": "Collect 50 coins total"},
	"max_sword": {"name": "Master Swordsman", "desc": "Max out sword upgrades"},
	"max_shield": {"name": "Iron Wall", "desc": "Max out shield upgrades"},
	"full_upgrade": {"name": "Fully Loaded", "desc": "Buy all upgrades"},
	"lore_finder": {"name": "Lore Finder", "desc": "Find your first lore scroll"},
	"lore_master": {"name": "Lore Master", "desc": "Find all lore scrolls"},
	"speedrunner": {"name": "Speedrunner", "desc": "Beat the game in under 5 minutes"},
	"parry_master": {"name": "Parry Master", "desc": "Successfully parry 10 times"},
	"no_shop": {"name": "Purist", "desc": "Beat the game without buying upgrades"},
}

var popup_queue: Array = []
var showing_popup: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func check_and_unlock(id: String) -> void:
	if not id in ACHIEVEMENTS:
		return
	if PlayerData.unlock_achievement(id):
		_queue_popup(id)

func _queue_popup(id: String) -> void:
	popup_queue.append(id)
	if not showing_popup:
		_show_next_popup()

func _show_next_popup() -> void:
	if popup_queue.is_empty():
		showing_popup = false
		return
	showing_popup = true
	var id = popup_queue.pop_front()
	var data = ACHIEVEMENTS.get(id, {"name": id, "desc": ""})

	# Create achievement toast notification
	var canvas = CanvasLayer.new()
	canvas.layer = 110
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(220, 50)
	panel.position = Vector2(10, -60)  # Start off-screen (top)
	canvas.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	var icon_label = Label.new()
	icon_label.text = "🏆"
	icon_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(icon_label)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label = Label.new()
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = data["desc"]
	desc_label.add_theme_font_size_override("font_size", 8)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(desc_label)

	get_tree().root.add_child(canvas)

	# Animate: slide in from top, pause, slide out
	var tween = panel.create_tween()
	tween.tween_property(panel, "position:y", 10.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(2.5)
	tween.tween_property(panel, "position:y", -60.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func():
		canvas.queue_free()
		_show_next_popup()
	)

# --- Periodic checks (call from game logic) ---
func check_coin_achievements() -> void:
	if PlayerData.total_coins_earned >= 50:
		check_and_unlock("coin_hoarder")

func check_upgrade_achievements() -> void:
	if PlayerData.sword_level >= PlayerData.MAX_UPGRADE_LEVEL:
		check_and_unlock("max_sword")
	if PlayerData.shield_level >= PlayerData.MAX_UPGRADE_LEVEL:
		check_and_unlock("max_shield")
	if PlayerData.sword_level >= PlayerData.MAX_UPGRADE_LEVEL and \
		PlayerData.shield_level >= PlayerData.MAX_UPGRADE_LEVEL and \
		PlayerData.health_level >= PlayerData.MAX_UPGRADE_LEVEL and \
		PlayerData.speed_level >= PlayerData.MAX_UPGRADE_LEVEL and \
		PlayerData.has_ranged and PlayerData.has_dash:
		check_and_unlock("full_upgrade")

func check_time_achievement() -> void:
	if PlayerData.best_time > 0 and PlayerData.best_time < 300.0:  # 5 minutes
		check_and_unlock("speedrunner")
