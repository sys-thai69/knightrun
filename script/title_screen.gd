# title_screen.gd — Main menu with New Game, Continue, Time Trial, and Quit
# IMAGE KEYWORD: "pixel art dark fantasy title screen background knight castle"
extends CanvasLayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().paused = false
    # Update continue button state
    if has_node("VBoxContainer/ContinueBtn"):
        $VBoxContainer/ContinueBtn.disabled = not SaveManager.has_save()
    # Show best time on time trial button
    if has_node("VBoxContainer/TimeTrialBtn"):
        if SaveManager.has_save() and PlayerData.best_time > 0:
            var mins = int(PlayerData.best_time) / 60
            var secs = int(PlayerData.best_time) % 60
            $VBoxContainer/TimeTrialBtn.text = "Time Trial (Best: %02d:%02d)" % [mins, secs]

func _on_new_game_pressed() -> void:
    PlayerData.reset_all()
    SaveManager.delete_save()
    get_tree().change_scene_to_file("res://scences/game.tscn")

func _on_continue_pressed() -> void:
    if SaveManager.load_game():
        get_tree().change_scene_to_file("res://scences/game.tscn")

func _on_time_trial_pressed() -> void:
    # Start a time trial run — fresh game with timer
    PlayerData.reset_all()
    PlayerData.start_time_trial()
    get_tree().change_scene_to_file("res://scences/game.tscn")

func _on_quit_pressed() -> void:
    get_tree().quit()
