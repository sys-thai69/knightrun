# lore_scroll.gd — Collectible lore item that shows a popup when picked up
extends Area2D

@export var scroll_id: String = "scroll_1"
@export var scroll_title: String = "Ancient Text"
@export_multiline var scroll_text: String = "The knight descended into darkness..."

var collected: bool = false

func _ready() -> void:
	# Check if already collected
	if PlayerData.has_scroll(scroll_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if not body.is_in_group("player"):
		return
	collected = true
	PlayerData.collect_scroll(scroll_id)
	AchievementManager.check_and_unlock("lore_finder")
	if PlayerData.lore_scrolls_found.size() >= PlayerData.TOTAL_LORE_SCROLLS:
		AchievementManager.check_and_unlock("lore_master")
	SaveManager.save_game()
	_show_scroll_popup()
	# Collect effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)

func _show_scroll_popup() -> void:
	var popup = CanvasLayer.new()
	popup.layer = 100
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Dark overlay
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(bg)
	
	# Scroll panel
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(280, 140)
	panel.position = Vector2(-140, -70)
	popup.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = "📜 " + scroll_title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	var text_label = Label.new()
	text_label.text = scroll_text
	text_label.add_theme_font_size_override("font_size", 9)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(text_label)
	
	var count_label = Label.new()
	count_label.text = "Scrolls: %d/%d" % [PlayerData.lore_scrolls_found.size(), PlayerData.TOTAL_LORE_SCROLLS]
	count_label.add_theme_font_size_override("font_size", 8)
	count_label.add_theme_color_override("font_color", Color.DIM_GRAY)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(count_label)
	
	get_tree().root.add_child(popup)
	get_tree().paused = true
	
	# Auto-dismiss after 4 seconds or on any input
	var timer = get_tree().create_timer(4.0, true, false, true)
	timer.timeout.connect(func():
		if is_instance_valid(popup):
			get_tree().paused = false
			popup.queue_free()
	)
	
	# Also dismiss on input
	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton or event is InputEventKey:
			get_tree().paused = false
			if is_instance_valid(popup):
				popup.queue_free()
	)

func _draw() -> void:
	# Placeholder visual: golden scroll icon
	draw_rect(Rect2(-5, -6, 10, 12), Color.GOLDENROD)
	draw_rect(Rect2(-6, -6, 12, 2), Color.DARK_GOLDENROD)
	draw_rect(Rect2(-6, 4, 12, 2), Color.DARK_GOLDENROD)
