# res://ui/pause_menu.gd (Attached to the CanvasLayer root of the menu)
extends CanvasLayer

# --- Menu Button Functions ---

func _on_resume_pressed() -> void:
    get_tree().paused = false
    queue_free()

func _on_restart_pressed() -> void:
    # 1. Unpause the game (crucial before restarting)
    get_tree().paused = false  
    # 2. Reset health before reload
    PlayerData.reset_health_only()
    # 3. Reload the main game scene
    get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
    get_tree().quit() # Replace with function body.
