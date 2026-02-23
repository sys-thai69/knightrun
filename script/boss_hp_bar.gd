# boss_hp_bar.gd — Boss health bar displayed at the top of screen
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
	name_label.text = "Summoner"
	# Find player reference
	player_ref = get_tree().get_first_node_in_group("player")
	# Start hidden until player faces the boss
	visible = false

func _process(_delta: float) -> void:
	if boss_ref and is_instance_valid(boss_ref) and not boss_ref.is_dead:
		progress_bar.value = boss_ref.health
		# Only show HP bar when player is facing the boss AND within range
		if player_ref and is_instance_valid(player_ref):
			var dist = player_ref.global_position.distance_to(boss_ref.global_position)
			if dist > 300:
				visible = false
			else:
				var sprite = player_ref.get_node_or_null("AnimatedSprite2D")
				if sprite:
					var player_facing_right = not sprite.flip_h
					var boss_is_right = boss_ref.global_position.x > player_ref.global_position.x
					visible = (player_facing_right and boss_is_right) or (not player_facing_right and not boss_is_right)
				else:
					visible = true
		else:
			visible = false
	elif boss_ref and (not is_instance_valid(boss_ref) or boss_ref.is_dead):
		visible = false
