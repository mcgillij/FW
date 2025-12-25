extends Node2D

@export var damaged_texture: Texture2D
@export var damaged_texture2: Texture2D

# health
@export var health: int
var hit: bool = false
# Called when the node enters the scene tree for the first time.
func take_damage(damage: int) -> void:
    health -= damage
    if hit:
        $Sprite2D.texture = damaged_texture2
    else:
        hit = true
        $Sprite2D.texture = damaged_texture
    # can add a damage effect here
