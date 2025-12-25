extends Node2D

# health
@export var health: int

func take_damage(damage: int) -> void:
    health -= damage
    # can add a damage effect here
