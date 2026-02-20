# save_manager.gd — Autoload for saving/loading game progress
extends Node

const SAVE_PATH = "user://knightfall_save.dat"

func save_game() -> void:
	var save_data = {
		"coins": PlayerData.coins,
		"sword_level": PlayerData.sword_level,
		"shield_level": PlayerData.shield_level,
		"health_level": PlayerData.health_level,
		"speed_level": PlayerData.speed_level,
		"has_ranged": PlayerData.has_ranged,
		"has_dash": PlayerData.has_dash,
		"death_count": PlayerData.death_count,
		"total_coins_earned": PlayerData.total_coins_earned,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var save_data = file.get_var()
	file.close()
	if save_data is Dictionary:
		PlayerData.coins = save_data.get("coins", 0)
		PlayerData.sword_level = save_data.get("sword_level", 0)
		PlayerData.shield_level = save_data.get("shield_level", 0)
		PlayerData.health_level = save_data.get("health_level", 0)
		PlayerData.speed_level = save_data.get("speed_level", 0)
		PlayerData.has_ranged = save_data.get("has_ranged", false)
		PlayerData.has_dash = save_data.get("has_dash", false)
		PlayerData.death_count = save_data.get("death_count", 0)
		PlayerData.total_coins_earned = save_data.get("total_coins_earned", 0)
		PlayerData.full_heal()
		PlayerData.coins_changed.emit(PlayerData.coins)
		return true
	return false

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
