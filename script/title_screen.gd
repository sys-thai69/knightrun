# title_screen.gd — Main menu with New Game, Continue, and Quit
# IMAGE KEYWORD: "pixel art dark fantasy title screen background knight castle"
extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	# Update continue button state
	if has_node("VBoxContainer/ContinueBtn"):
		$VBoxContainer/ContinueBtn.disabled = not SaveManager.has_save()

func _on_new_game_pressed() -> void:
	PlayerData.reset_all()
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scences/game.tscn")

func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scences/game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
