# res://ui/pause_menu.gd (Attached to the CanvasLayer root of the menu)
extends CanvasLayer

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

# --- Menu Button Functions ---

func _on_resume_pressed() -> void:
    get_tree().paused = false
    queue_free()

func _on_respawn_pressed() -> void:
    # Go back to checkpoint (keep upgrades, coins, progress)
    get_tree().paused = false
    PlayerData.reset_health_only()
    SaveManager.save_game()
    get_tree().reload_current_scene()  # player._ready() will move to checkpoint

func _on_restart_pressed() -> void:
    # Full restart — reset everything
    get_tree().paused = false
    PlayerData.reset_all()
    SaveManager.delete_save()
    get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
    get_tree().quit()
