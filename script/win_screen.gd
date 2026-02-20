# res://ui/win_screen.gd
extends CanvasLayer

func _ready() -> void:
    # Show stats
    if has_node("StatsLabel"):
        $StatsLabel.text = "Deaths: %d\nCoins Earned: %d\nSword Lv: %d\nShield Lv: %d" % [
            PlayerData.death_count,
            PlayerData.total_coins_earned,
            PlayerData.sword_level,
            PlayerData.shield_level
        ]
    SaveManager.save_game()

func _on_restart_pressed() -> void:
    get_tree().paused = false
    PlayerData.reset_all()
    get_tree().change_scene_to_file("res://scences/game.tscn")
    queue_free()

func _on_main_menu_pressed() -> void:
    get_tree().paused = false
    PlayerData.reset_all()
    get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
    queue_free()

func _on_exit_pressed() -> void:
    get_tree().quit()
