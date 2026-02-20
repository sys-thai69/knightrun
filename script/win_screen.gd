# res://ui/win_screen.gd
extends CanvasLayer

func _ready() -> void:
    # Stop time trial if active
    if PlayerData.time_trial_active:
        var elapsed = PlayerData.stop_time_trial()
        if has_node("TimerLabel"):
            var mins = int(elapsed) / 60
            var secs = int(elapsed) % 60
            var ms = int(fmod(elapsed, 1.0) * 100)
            $TimerLabel.text = "Time: %02d:%02d.%02d" % [mins, secs, ms]
            if PlayerData.best_time == elapsed:
                $TimerLabel.text += " (NEW BEST!)"

    # Unlock achievements on win
    PlayerData.unlock_achievement("game_complete")
    if PlayerData.death_count == 0:
        PlayerData.unlock_achievement("deathless")
    if PlayerData.ng_plus_level > 0:
        PlayerData.unlock_achievement("ng_plus_complete")

    # Show stats
    if has_node("StatsLabel"):
        var stats_text = "Deaths: %d\nCoins Earned: %d\nSword Lv: %d\nShield Lv: %d" % [
            PlayerData.death_count,
            PlayerData.total_coins_earned,
            PlayerData.sword_level,
            PlayerData.shield_level
        ]
        if PlayerData.ng_plus_level > 0:
            stats_text += "\nNew Game+ Level: %d" % PlayerData.ng_plus_level
        if PlayerData.best_time > 0:
            var mins = int(PlayerData.best_time) / 60
            var secs = int(PlayerData.best_time) % 60
            stats_text += "\nBest Time: %02d:%02d" % [mins, secs]
        stats_text += "\nScrolls: %d/%d" % [PlayerData.lore_scrolls_found.size(), PlayerData.TOTAL_LORE_SCROLLS]
        stats_text += "\nAchievements: %d" % PlayerData.achievements_unlocked.size()
        $StatsLabel.text = stats_text
    SaveManager.save_game()

func _on_restart_pressed() -> void:
    get_tree().paused = false
    PlayerData.reset_all()
    get_tree().change_scene_to_file("res://scences/game.tscn")
    queue_free()

func _on_ng_plus_pressed() -> void:
    get_tree().paused = false
    PlayerData.start_new_game_plus()
    SaveManager.save_game()
    get_tree().change_scene_to_file("res://scences/game.tscn")
    queue_free()

func _on_main_menu_pressed() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
    queue_free()

func _on_exit_pressed() -> void:
    get_tree().quit()
