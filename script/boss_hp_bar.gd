# boss_hp_bar.gd — Boss health bar displayed at the top of screen (for final boss only)
extends CanvasLayer

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var name_label: Label = $NameLabel
var boss_ref: Node = null
var player_ref: Node = null

func _ready() -> void:
	visible = false

func set_boss(boss: Node) -> void:
	boss_ref = boss
	progress_bar.max_value = boss.scaled_max_health
	progress_bar.value = boss.health
	# Set name based on boss type
	if boss.is_in_group("mini_boss"):
		name_label.text = "Summoner"
	else:
		name_label.text = "Guardian"
	# Find player reference
	player_ref = get_tree().get_first_node_in_group("player")
	# Show immediately for final boss (boss.gd handles showing only when activated)
	visible = true

func _process(_delta: float) -> void:
	if boss_ref and is_instance_valid(boss_ref) and not boss_ref.is_dead:
		progress_bar.value = boss_ref.health
	elif boss_ref and (not is_instance_valid(boss_ref) or boss_ref.is_dead):
		visible = false
