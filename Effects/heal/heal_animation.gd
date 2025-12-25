extends Node2D

@onready var heal_animation: AnimatedSprite2D = %heal_animation

var iterations := 3
var shader_values = FW_Utils.ShaderValues.new()

func _ready() -> void:
	heal_animation.scale = Vector2(1.5, 1.5)
	heal_animation.play()

func _process(delta: float) -> void:
	shader_values.muck_with_shader_values(delta, heal_animation)

func _on_heal_animation_animation_looped() -> void:
	if iterations <= 0:
		queue_free()
	iterations -= 1
