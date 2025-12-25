extends Node2D

@export var damaged_texture: Texture2D
# health
@export var health: int
# Called when the node enters the scene tree for the first time.
func take_damage(damage: int) -> void:
    health -= damage
    $Sprite2D.texture = damaged_texture
    # can add a damage effect here
