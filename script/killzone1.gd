extends Area2D

@onready var timer = $Timer

func _on_body_entered(body: Node2D) -> void:
    print("Spike hit detected!") # Does this print?
    print("Body name: ", body.name)
    print("You died1")
    Engine.time_scale = 0.5
    body.set_physics_process(false)
    timer.start()



func _on_timer_timeout() -> void:
    Engine.time_scale = 1
    get_tree().reload_current_scene()
