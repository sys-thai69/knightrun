# GameManager.gd — Pause menu controller (coins now handled by PlayerData autoload)
extends Node

const PAUSE_MENU_SCENE = preload("uid://dms0s7esxb355")
var pause_menu_instance: CanvasLayer = null

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        toggle_pause_menu()

func toggle_pause_menu():
    if get_tree().paused:
        get_tree().paused = false
        if pause_menu_instance:
            pause_menu_instance.queue_free()
            pause_menu_instance = null
    else:
        get_tree().paused = true
        pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
        add_child(pause_menu_instance)
