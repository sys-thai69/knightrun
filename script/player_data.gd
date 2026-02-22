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
var has_sword: bool = false    # Unlocked via shop
var has_shield: bool = false   # Unlocked via shop
var has_ranged: bool = false   # Unlocked via shop
var has_dash: bool = false     # Unlocked via shop

# --- Checkpoint ---
var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false

# --- Stats Tracking ---
var death_count: int = 0
var total_coins_earned: int = 0

# --- New Game+ ---
var ng_plus_level: int = 0  # 0 = normal, 1+ = NG+ cycles

# --- Achievements ---
var achievements_unlocked: Array = []  # Array of achievement IDs (strings)

# --- Time Trial ---
var best_time: float = 0.0  # Best completion time in seconds
var time_trial_active: bool = false
var time_trial_elapsed: float = 0.0

# --- Lore Scrolls ---
var lore_scrolls_found: Array = []  # Array of scroll IDs
const TOTAL_LORE_SCROLLS = 5

# --- Upgrade Costs ---
const UPGRADE_COSTS = {
	"sword": [5, 10, 20],
	"shield": [5, 10, 20],
	"health": [8, 15, 25],
	"speed": [5, 10, 15],
}
const MAX_UPGRADE_LEVEL = 3
const SWORD_COST = 8
const SHIELD_COST = 8
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
	has_sword = false
	has_shield = false
	has_ranged = false
	has_dash = false
	death_count = 0
	total_coins_earned = 0
	ng_plus_level = 0
	achievements_unlocked = []
	best_time = 0.0
	time_trial_active = false
	time_trial_elapsed = 0.0
	lore_scrolls_found = []
	has_checkpoint = false
	checkpoint_position = Vector2.ZERO
	max_health = 3
	current_health = 3
	coins_changed.emit(coins)
	health_changed.emit(current_health, max_health)

func reset_health_only() -> void:
	max_health = get_max_health()
	current_health = max_health
	health_changed.emit(current_health, max_health)

# --- New Game+ ---
func get_enemy_hp_multiplier() -> float:
	return 1.0 + ng_plus_level * 0.5  # 1.0, 1.5, 2.0, ...

func get_enemy_damage_multiplier() -> int:
	return 1 + ng_plus_level  # 1, 2, 3, ...

func start_new_game_plus() -> void:
	ng_plus_level += 1
	# Keep upgrades, unlocks — reset health/coins/checkpoint
	coins = 0
	death_count = 0
	total_coins_earned = 0
	has_checkpoint = false
	checkpoint_position = Vector2.ZERO
	max_health = get_max_health()
	current_health = max_health
	coins_changed.emit(coins)
	health_changed.emit(current_health, max_health)

# --- Achievements ---
func unlock_achievement(id: String) -> bool:
	if id in achievements_unlocked:
		return false
	achievements_unlocked.append(id)
	return true

func has_achievement(id: String) -> bool:
	return id in achievements_unlocked

# --- Lore Scrolls ---
func collect_scroll(scroll_id: String) -> bool:
	if scroll_id in lore_scrolls_found:
		return false
	lore_scrolls_found.append(scroll_id)
	return true

func has_scroll(scroll_id: String) -> bool:
	return scroll_id in lore_scrolls_found

# --- Time Trial ---
func start_time_trial() -> void:
	time_trial_active = true
	time_trial_elapsed = 0.0

func stop_time_trial() -> float:
	time_trial_active = false
	if best_time == 0.0 or time_trial_elapsed < best_time:
		best_time = time_trial_elapsed
	return time_trial_elapsed

func update_time_trial(delta: float) -> void:
	if time_trial_active:
		# Use unscaled delta so slow-motion doesn't affect the timer
		var real_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta
		time_trial_elapsed += real_delta