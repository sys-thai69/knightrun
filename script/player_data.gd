# player_data.gd — Autoload singleton for persistent player data across deaths/scenes
extends Node

# --- Signals ---
signal health_changed(current_hp: int, max_hp: int)
signal coins_changed(new_coin_count: int)
signal player_died

# --- Base Stats ---
var coins: int = 0
var max_health: int = 3
var current_health: int = 3

# --- Upgrade Levels (0 = base) ---
var sword_level: int = 0   # Each level: +1 damage
var shield_level: int = 0  # Each level: +1 block hits before break
var health_level: int = 0  # Each level: +1 max HP
var speed_level: int = 0   # Each level: +10 speed

# --- Unlockable Abilities ---
var has_ranged: bool = false   # Unlocked via shop
var has_dash: bool = false     # Unlocked via shop

# --- Checkpoint ---
var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false

# --- Stats Tracking ---
var death_count: int = 0
var total_coins_earned: int = 0

# --- Upgrade Costs ---
const UPGRADE_COSTS = {
	"sword": [5, 10, 20],
	"shield": [5, 10, 20],
	"health": [8, 15, 25],
	"speed": [5, 10, 15],
}
const MAX_UPGRADE_LEVEL = 3
const RANGED_COST = 12
const DASH_COST = 10

# --- Derived Stats ---
func get_attack_damage() -> int:
	return 1 + sword_level

func get_shield_durability() -> int:
	return 1 + shield_level

func get_max_health() -> int:
	return 3 + health_level

func get_speed_bonus() -> float:
	return speed_level * 10.0

# --- Coin Management ---
func add_coins(amount: int) -> void:
	coins += amount
	total_coins_earned += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_changed.emit(coins)
		return true
	return false

# --- Health Management ---
func heal(amount: int) -> void:
	max_health = get_max_health()
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func take_damage(amount: int = 1) -> void:
	current_health -= amount
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		death_count += 1
		player_died.emit()

func full_heal() -> void:
	max_health = get_max_health()
	current_health = max_health
	health_changed.emit(current_health, max_health)

# --- Upgrade System ---
func can_upgrade(stat: String) -> bool:
	var level = _get_level(stat)
	if level >= MAX_UPGRADE_LEVEL:
		return false
	var cost = UPGRADE_COSTS[stat][level]
	return coins >= cost

func upgrade(stat: String) -> bool:
	if not can_upgrade(stat):
		return false
	var level = _get_level(stat)
	var cost = UPGRADE_COSTS[stat][level]
	if not spend_coins(cost):
		return false
	match stat:
		"sword": sword_level += 1
		"shield": shield_level += 1
		"health":
			health_level += 1
			max_health = get_max_health()
			current_health += 1  # Gain the HP immediately
			health_changed.emit(current_health, max_health)
		"speed": speed_level += 1
	return true

func get_upgrade_cost(stat: String) -> int:
	var level = _get_level(stat)
	if level >= MAX_UPGRADE_LEVEL:
		return -1
	return UPGRADE_COSTS[stat][level]

func _get_level(stat: String) -> int:
	match stat:
		"sword": return sword_level
		"shield": return shield_level
		"health": return health_level
		"speed": return speed_level
	return 0

# --- Reset (new game) ---
func reset_all() -> void:
	coins = 0
	sword_level = 0
	shield_level = 0
	health_level = 0
	speed_level = 0
	has_ranged = false
	has_dash = false
	death_count = 0
	total_coins_earned = 0
	max_health = 3
	current_health = 3
	coins_changed.emit(coins)
	health_changed.emit(current_health, max_health)

func reset_health_only() -> void:
	max_health = get_max_health()
	current_health = max_health
	health_changed.emit(current_health, max_health)
