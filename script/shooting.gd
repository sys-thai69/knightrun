extends Area2D
const FIREBALL_SCENE = preload("res://enemy/fireball.tscn")
@onready var fire_timer: Timer = $FireTimer
@onready var timer: Timer = $Timer
@onready var muzzle_node: Marker2D = $Marker2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@export var shoot_direction: Vector2 = Vector2.LEFT

var health: int = 3
var is_dead: bool = false
const COIN_DROP = 3

func _on_animated_sprite_2d_animation_finished() -> void:
    animated_sprite_2d.animation_finished.disconnect(_on_animated_sprite_2d_animation_finished)
    animated_sprite_2d.play("idle")

func _ready():
    add_to_group("enemy")
    # Scale HP with New Game+ level
    health = int(health * PlayerData.get_enemy_hp_multiplier())
    animated_sprite_2d.play("idle")
    fire_timer.start()
    if shoot_direction.x > 0:
        animated_sprite_2d.flip_h = false
    elif shoot_direction.x < 0:
        animated_sprite_2d.flip_h = true

func _on_fire_timer_timeout():
    if is_dead:
        return
    animated_sprite_2d.play("shooting")
    var fireball = FIREBALL_SCENE.instantiate()
    get_parent().add_child(fireball)
    fireball.global_position = muzzle_node.global_position
    fireball.direction = shoot_direction
    if not animated_sprite_2d.animation_finished.is_connected(_on_animated_sprite_2d_animation_finished):
        animated_sprite_2d.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
    fire_timer.start()

func _on_body_entered(body: Node2D) -> void:
    if not body.is_in_group("player"):
        return
    if body.has_method("take_damage"):
        body.take_damage(1)

func take_hit(damage: int, _source_type: String = "melee") -> void:
    if is_dead:
        return
    health -= damage
    ScreenEffects.spawn_damage_number(global_position, damage, Color.WHITE)
    # White flash on hit
    animated_sprite_2d.modulate = Color(3, 3, 3)
    var flash_tw = create_tween()
    flash_tw.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.12)
    # Scale pop
    var pop_tw = create_tween()
    pop_tw.tween_property(animated_sprite_2d, "scale", Vector2(1.4, 1.4), 0.05)
    pop_tw.tween_property(animated_sprite_2d, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
    if health <= 0:
        die()

func die() -> void:
    is_dead = true
    fire_timer.stop()
    PlayerData.add_coins(COIN_DROP)
    ScreenEffects.spawn_coin_text(global_position, COIN_DROP)
    AchievementManager.check_and_unlock("first_kill")
    AchievementManager.check_coin_achievements()
    _spawn_death_particles()
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(animated_sprite_2d, "modulate:a", 0.0, 0.3)
    tween.tween_property(animated_sprite_2d, "scale", Vector2.ZERO, 0.3)
    tween.chain().tween_callback(queue_free)

func _spawn_death_particles() -> void:
    for i in range(6):
        var p = Label.new()
        p.text = "*"
        p.add_theme_font_size_override("font_size", 8)
        p.add_theme_color_override("font_color", Color.MEDIUM_PURPLE)
        p.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
        p.z_index = 50
        get_parent().add_child(p)
        var tw = p.create_tween()
        tw.set_parallel(true)
        tw.tween_property(p, "position", p.position + Vector2(randf_range(-20, 20), randf_range(-30, -10)), 0.4)
        tw.tween_property(p, "modulate:a", 0.0, 0.4)
        tw.chain().tween_callback(p.queue_free)
