# boss_hp_bar.gd — Boss health bar displayed at the top of screen
extends CanvasLayer

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var name_label: Label = $NameLabel
var boss_ref: Node = null

func _ready() -> void:
	visible = false

func set_boss(boss: Node) -> void:
	boss_ref = boss
	progress_bar.max_value = boss.MAX_HEALTH
	progress_bar.value = boss.health
	name_label.text = "Guardian of the Trial"
	visible = true

func _process(_delta: float) -> void:
	if boss_ref and not boss_ref.is_dead:
		progress_bar.value = boss_ref.health
	elif boss_ref and boss_ref.is_dead:
		visible = false
