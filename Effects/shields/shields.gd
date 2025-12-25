extends Node2D

@onready var shield_animation: AnimatedSprite2D = %shield_animation

var iterations := 1
var shader_values = FW_Utils.ShaderValues.new()

func _ready() -> void:
    shield_animation.scale = Vector2(1.5, 1.5)
    shield_animation.play()

func _process(delta: float) -> void:
    shader_values.muck_with_shader_values(delta, shield_animation)

func _on_shield_animation_animation_looped() -> void:
    if iterations <= 0:
        queue_free()
    iterations -= 1
