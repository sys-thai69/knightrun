extends Area2D
const WIN_SCREEN_SCENE = preload("res://scences/win_screen.tscn")

var triggered: bool = false

# Called when the node enters the scene tree for the first time

# Assuming your player's root node is a CharacterBody2D named "Player"
func _ready():
    # You can customize this if you need to set up anything initially
    pass

func _on_body_entered(body: Node2D) -> void:
    if triggered:
        return
    if not body.is_in_group("player"):
        return
    triggered = true
    handle_win()

func handle_win():
    # Store elapsed time before stopping, so win screen can display it
    var _elapsed = PlayerData.time_trial_elapsed
    if PlayerData.time_trial_active:
        AchievementManager.check_time_achievement()
        # Don't call stop_time_trial() here — let win_screen handle it
    
    get_tree().paused = true
    
    # 2. Instantiate the Win Screen
    var win_screen = WIN_SCREEN_SCENE.instantiate()
    
    # 3. Add the screen to the root of the current scene tree
    get_tree().root.add_child(win_screen)
