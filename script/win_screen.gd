# res://script/win_screen.gd
extends CanvasLayer

@onready var stats_label: Label = $ColorRect/VBoxContainer/StatsLabel
@onready var timer_label: Label = $ColorRect/VBoxContainer/TimerLabel

func _ready() -> void:
    # Stop time trial if active
    if PlayerData.time_trial_active:
        var elapsed = PlayerData.stop_time_trial()
        if timer_label:
            @warning_ignore("integer_division")
            var mins: int = int(elapsed) / 60
            @warning_ignore("integer_division")
            var secs: int = int(elapsed) % 60
            var ms = int(fmod(elapsed, 1.0) * 100)
            timer_label.text = "Time: %02d:%02d.%02d" % [mins, secs, ms]
            if PlayerData.best_time == elapsed:
                timer_label.text += " (NEW BEST!)"
            timer_label.visible = true
    else:
        if timer_label:
            timer_label.visible = false

    # Unlock achievements on win
    AchievementManager.check_and_unlock("game_complete")
    if PlayerData.death_count == 0:
        AchievementManager.check_and_unlock("deathless")
    if PlayerData.ng_plus_level > 0:
        AchievementManager.check_and_unlock("ng_plus_complete")

    # Show stats
    if stats_label:
        var stats_text = "Deaths: %d\nCoins Earned: %d\nSword Lv: %d\nShield Lv: %d" % [
            PlayerData.death_count,
            PlayerData.total_coins_earned,
            PlayerData.sword_level,
            PlayerData.shield_level
        ]
        if PlayerData.ng_plus_level > 0:
            stats_text += "\nNew Game+ Level: %d" % PlayerData.ng_plus_level
        if PlayerData.best_time > 0:
            @warning_ignore("integer_division")
            var mins: int = int(PlayerData.best_time) / 60
            @warning_ignore("integer_division")
            var secs: int = int(PlayerData.best_time) % 60
            stats_text += "\nBest Time: %02d:%02d" % [mins, secs]
        stats_text += "\nScrolls: %d/%d" % [PlayerData.lore_scrolls_found.size(), PlayerData.TOTAL_LORE_SCROLLS]
        stats_text += "\nAchievements: %d" % PlayerData.achievements_unlocked.size()
        stats_label.text = stats_text
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
