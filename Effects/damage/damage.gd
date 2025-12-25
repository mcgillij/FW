extends Node2D

@onready var damage_animation: AnimatedSprite2D = %damage_animation

var iterations := 1
var shader_values = FW_Utils.ShaderValues.new()

func _ready() -> void:
	damage_animation.scale = Vector2(1.5, 1.5)
	damage_animation.play()

func _process(delta: float) -> void:
	shader_values.muck_with_shader_values(delta, damage_animation)

func _on_damage_animation_animation_looped() -> void:
	if iterations <= 0:
		queue_free()
	iterations -= 1
