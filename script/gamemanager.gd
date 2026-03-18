# GameManager.gd — Pause menu controller (coins now handled by PlayerData autoload)
extends Node

const PAUSE_MENU_SCENE = preload("uid://dms0s7esxb355")
const EASTER_EGG_SCENE_PATH = "res://scences/game.tscn"
const EASTER_EGG_POS = Vector2(58, -236)
const EASTER_EGG_REWARD = 20

var pause_menu_instance: CanvasLayer = null
var easter_egg_area: Area2D = null
var player_in_easter_egg: bool = false

func _process(_delta: float) -> void:
    _ensure_easter_egg_zone()

func _ensure_easter_egg_zone() -> void:
    var scene := get_tree().current_scene
    if not scene:
        return
    if scene.scene_file_path != EASTER_EGG_SCENE_PATH:
        if easter_egg_area and is_instance_valid(easter_egg_area):
            easter_egg_area.queue_free()
            easter_egg_area = null
            player_in_easter_egg = false
        return
    if PlayerData.easter_egg_found:
        if easter_egg_area and is_instance_valid(easter_egg_area):
            easter_egg_area.queue_free()
            easter_egg_area = null
        return
    if easter_egg_area and is_instance_valid(easter_egg_area):
        return

    easter_egg_area = Area2D.new()
    easter_egg_area.name = "EasterEggShrine"
    easter_egg_area.collision_layer = 0
    easter_egg_area.collision_mask = 2
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(20, 20)
    shape.shape = rect
    easter_egg_area.add_child(shape)
    easter_egg_area.global_position = EASTER_EGG_POS
    scene.add_child(easter_egg_area)
    easter_egg_area.body_entered.connect(_on_easter_egg_body_entered)
    easter_egg_area.body_exited.connect(_on_easter_egg_body_exited)

func _on_easter_egg_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and not PlayerData.easter_egg_found:
        player_in_easter_egg = true
        ScreenEffects.spawn_text_popup(EASTER_EGG_POS, "A hidden shrine... Press E", Color.MEDIUM_PURPLE)

func _on_easter_egg_body_exited(body: Node2D) -> void:
    if body.is_in_group("player"):
        player_in_easter_egg = false

func _claim_easter_egg() -> void:
    if PlayerData.easter_egg_found:
        return
    PlayerData.easter_egg_found = true
    PlayerData.add_coins(EASTER_EGG_REWARD)
    PlayerData.full_heal()
    AchievementManager.check_and_unlock("secret_finder")
    SaveManager.save_game()
    ScreenEffects.spawn_text_popup(EASTER_EGG_POS, "Secret Found! +20 coins", Color.GOLD)
    if easter_egg_area and is_instance_valid(easter_egg_area):
        easter_egg_area.queue_free()
        easter_egg_area = null
    player_in_easter_egg = false

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and player_in_easter_egg and not PlayerData.easter_egg_found:
        _claim_easter_egg()
        return
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
