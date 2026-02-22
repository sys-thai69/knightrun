# spike_damage.gd — Triggers 1 damage to player when touched (non-lethal spikes)
# Also damages enemies that walk into spikes
extends Area2D

@export var damage: int = 1
@export var affects_enemies: bool = true
var _hit_cooldown: Dictionary = {}  # Track per-body cooldown to prevent rapid hits
const HIT_COOLDOWN_TIME: float = 0.5  # Half second between hits

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
    # Cooldown tick
    var to_remove: Array = []
    for body in _hit_cooldown.keys():
        if not is_instance_valid(body):
            to_remove.append(body)
            continue
        _hit_cooldown[body] -= delta
        if _hit_cooldown[body] <= 0:
            to_remove.append(body)
    for body in to_remove:
        _hit_cooldown.erase(body)
    
    # Continuously damage bodies that are standing on the spike
    for body in get_overlapping_bodies():
        _try_damage(body)

func _on_body_entered(body: Node2D) -> void:
    _try_damage(body)

func _try_damage(body: Node2D) -> void:
    # Check cooldown
    if body in _hit_cooldown:
        return
    
    # Damage player
    if body.is_in_group("player"):
        if body.has_method("take_damage"):
            body.take_damage(damage)
            _hit_cooldown[body] = HIT_COOLDOWN_TIME
    # Optionally damage enemies too
    elif affects_enemies and body.is_in_group("enemy"):
        if body.has_method("take_hit"):
            body.take_hit(damage, "spike")
            _hit_cooldown[body] = HIT_COOLDOWN_TIME
