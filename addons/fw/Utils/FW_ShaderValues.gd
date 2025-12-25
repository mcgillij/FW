extends RefCounted
class_name FW_ShaderValues

var glow_intensity := 1.0
var speed := 2.0
var time_speed: float = 1.0
var zoom_speed: float = 0.05
var initial_zoom_factor: float = 2.0

func muck_with_shader_values(delta: float, item_with_shader: Variant) -> void:
	if item_with_shader:
		glow_intensity += delta * speed
		if glow_intensity >= 3.0 and speed > 0 or glow_intensity <= 1.0 and speed < 0:
			speed *= -1.0
		item_with_shader.get_material().set_shader_parameter("glow_intensity", glow_intensity)

func toggle_on_highlight_shader(item_with_shader: Variant) -> void:
	if item_with_shader:
		item_with_shader.get_material().set_shader_parameter("highlight_strength", 0.5)

func toggle_off_highlight_shader(item_with_shader: Variant) -> void:
	if item_with_shader:
		item_with_shader.get_material().set_shader_parameter("highlight_strength", 0)
