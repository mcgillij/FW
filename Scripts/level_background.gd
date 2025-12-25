extends TextureRect

@export var require_spin_shader := false

@onready var shader_bg: ColorRect = %ShaderBG
@onready var background: TextureRect = %background

# Resource paths for deferred loading
var background_paths := [
	"res://Level_backgrounds/pom_mountain.png",
	"res://Level_backgrounds/pom_mountain2.png",
	"res://Level_backgrounds/pom_graveyard.png",
	"res://Level_backgrounds/pom_graveyard2.png",
	"res://Level_backgrounds/pom_swamp.png",
	"res://Level_backgrounds/pom_swamp2.png",
	"res://Level_backgrounds/draculas_castle.png",
	"res://Level_backgrounds/pom_and_dragon.png",
	"res://Level_backgrounds/pom_castle.png",
	"res://Level_backgrounds/pom_forest4.png",
	"res://Level_backgrounds/pom_forest5.png",
	"res://Level_backgrounds/pom_napping3.png",
	"res://Level_backgrounds/pom_napping.png",
	"res://Level_backgrounds/pom_napping_armored.png",
	"res://Level_backgrounds/pom_silouette.png",
	"res://Level_backgrounds/world1_background.png"
]

var shader_paths := {
	"apollonian": "res://Shaders/backgrounds/apollonian.gdshader",
	"aurora_swirl": "res://Shaders/backgrounds/aurora_swirl.gdshader",
	"balatro": "res://Shaders/backgrounds/balatro.gdshader",
	"basic_plasma": "res://Shaders/backgrounds/basic_plasma.gdshader",
	"clouds2": "res://Shaders/backgrounds/clouds2.gdshader",
	"combustible": "res://Shaders/backgrounds/combustible.gdshader",
	"corner_void": "res://Shaders/backgrounds/corner_void.gdshader",
	"electric": "res://Shaders/backgrounds/electric.gdshader",
	"flux": "res://Shaders/backgrounds/flux.gdshader",
	"galaxy": "res://Shaders/backgrounds/galaxy.gdshader",
	"gradient_wave": "res://Shaders/backgrounds/gradient_wave.gdshader",
	"grid": "res://Shaders/backgrounds/grid.gdshader",
	"hyperspace": "res://Shaders/backgrounds/hyperspace.gdshader",
	"kinetic": "res://Shaders/backgrounds/kinetic.gdshader",
	"mandlebulb": "res://Shaders/backgrounds/mandlebulb.gdshader",
	"nebula_storm": "res://Shaders/backgrounds/nebula_storm.gdshader",
	"octagrams": "res://Shaders/backgrounds/octagrams.gdshader",
	"phantom": "res://Shaders/backgrounds/phantom.gdshader",
	"plasma": "res://Shaders/backgrounds/plasma.gdshader",
	"spheres": "res://Shaders/backgrounds/spheres.gdshader",
	"spiral": "res://Shaders/backgrounds/spiral.gdshader",
	"starfield": "res://Shaders/backgrounds/starfield.gdshader",
	"starfield2": "res://Shaders/backgrounds/starfield2.gdshader",
	"synapse": "res://Shaders/backgrounds/synapse.gdshader",
	"water": "res://Shaders/backgrounds/water.gdshader",
	"water2": "res://Shaders/backgrounds/water2.gdshader",
}

var spin_compatible_shaders := ["balatro", "aurora_swirl", "nebula_storm"]

# Cache for materials and loaded resources
var shader_materials := {}
var texture_cache := {}
var shader_cache := {}

# Static variable to track current shader for testing
static var current_shader_index := 0

# Configuration for randomizing shader parameters
var shader_param_configs := {
	"balatro": [
		{"name": "colour_1", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "colour_2", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "colour_3", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "spin_rotation_speed", "type": "float", "min": 1.0, "max": 4.0},
		{"name": "move_speed", "type": "float", "min": 5.0, "max": 10.0},
		{"name": "contrast", "type": "float", "min": 2.5, "max": 4.5},
		{"name": "lighting", "type": "float", "min": 0.2, "max": 0.6},
		{"name": "spin_amount", "type": "float", "min": 0.1, "max": 0.4},
	],
	"plasma": [
		{"name": "wave_color", "type": "color", "hue_variation": 0.2, "sat_variation": 0.3, "val_variation": 0.3},
		{"name": "wave_transparency", "type": "float", "min": 0.8, "max": 1.0},
	],
	"apollonian": [
		{"name": "N", "type": "float", "min": 2.0, "max": 5.0},
		{"name": "max_iterations", "type": "int", "min": 10, "max": 30},
		{"name": "quality", "type": "float", "min": 0.5, "max": 1.0},
	],
	"clouds2": [
		{"name": "color1", "type": "vec3_color", "variation": 0.2},
		{"name": "color2", "type": "vec3_color", "variation": 0.2},
	],
	"combustible": [
		{"name": "red_colour", "type": "float", "min": 0.0, "max": 24.0},
		{"name": "green_colour", "type": "float", "min": 0.0, "max": 24.0},
		{"name": "blue_colour", "type": "float", "min": 0.0, "max": 24.0},
		{"name": "kelvin", "type": "float", "min": 0.0, "max": 10000.0},
	],
	"electric": [
		{"name": "background_color", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "line_color", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
	],
	"gradient_wave": [
		{"name": "color1", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "color2", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "color3", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
	],
	"kinetic": [
		{"name": "color", "type": "vec3_color", "variation": 0.2},
	],
	"mandlebulb": [
		{"name": "color1", "type": "vec3_color", "variation": 0.2},
		{"name": "color2", "type": "vec3_color", "variation": 0.2},
		#{"name": "background_color", "type": "vec3_color", "variation": 0.1},
		{"name": "light_direction", "type": "vec3_color", "variation": 0.1},
	],
	"spiral": [
		{"name": "color_choice", "type": "int", "min": 0, "max": 5},
	],
	"starfield": [
		{"name": "color1", "type": "vec3_color", "variation": 0.2},
		{"name": "color2", "type": "vec3_color", "variation": 0.2},
		{"name": "color3", "type": "vec3_color", "variation": 0.2},
		{"name": "color4", "type": "vec3_color", "variation": 0.2},
	],
	"water": [
		{"name": "water_colour", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "foam_colour", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "sky_colour", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
		{"name": "specular_colour", "type": "color", "hue_variation": 0.1, "sat_variation": 0.2, "val_variation": 0.2},
	],
	"water2": [
		{"name": "tint", "type": "vec3_color", "variation": 0.2},
	],
	"aurora_swirl": [
		{"name": "base_color", "type": "color", "hue_variation": 0.08, "sat_variation": 0.15, "val_variation": 0.12},
		{"name": "accent_color", "type": "color", "hue_variation": 0.08, "sat_variation": 0.2, "val_variation": 0.15},
		{"name": "highlight_color", "type": "color", "hue_variation": 0.08, "sat_variation": 0.25, "val_variation": 0.2},
		{"name": "warp_strength", "type": "float", "min": 0.2, "max": 0.55},
		{"name": "streak_density", "type": "float", "min": 2.2, "max": 5.0},
		{"name": "grain_amount", "type": "float", "min": 0.02, "max": 0.15},
	],
	"nebula_storm": [
		{"name": "dusk_color", "type": "color", "hue_variation": 0.05, "sat_variation": 0.2, "val_variation": 0.1},
		{"name": "core_color", "type": "color", "hue_variation": 0.05, "sat_variation": 0.2, "val_variation": 0.15},
		{"name": "rim_color", "type": "color", "hue_variation": 0.05, "sat_variation": 0.2, "val_variation": 0.15},
		{"name": "turbulence", "type": "float", "min": 0.3, "max": 1.0},
		{"name": "lightning_intensity", "type": "float", "min": 0.1, "max": 0.6},
	],
}

#func _ready() -> void:
	#if GDM.is_vs_mode():
		#setup_cycling_shader_background()
	#else:
		#setup_random_background()

#func setup_random_background() -> void:
func _ready() -> void:
	if require_spin_shader:
		_apply_spin_safe_shader()
		return
	if GDM.is_vs_mode() or GDM.game_mode == GDM.game_types.solitaire:
		var bg_or_shader := randi() % 2
		if bg_or_shader == 0 or ConfigManager.animated_bg == false:
			background.visible = true
			shader_bg.visible = false
			texture = _get_random_background()
		else:
			var shader_keys := shader_paths.keys()
			var shader_name: String = shader_keys[randi() % shader_keys.size()]
			_apply_shader(shader_name)
	else:
		texture = _get_random_background()

func setup_cycling_shader_background() -> void:
	background.visible = false
	var shader_keys := shader_paths.keys()
	var shader_name: String = shader_keys[current_shader_index % shader_keys.size()]
	_apply_shader(shader_name)

	# Move to next shader for next load
	current_shader_index += 1

func _apply_spin_safe_shader() -> void:
	var candidates := _get_spin_safe_shader_names()
	if candidates.is_empty():
		push_warning("No spin-compatible shaders found; falling back to static background")
		background.visible = true
		shader_bg.visible = false
		texture = _get_random_background()
		return
	var shader_name: String = candidates[randi() % candidates.size()]
	_apply_shader(shader_name)

func _get_spin_safe_shader_names() -> Array[String]:
	var safe: Array[String] = []
	for shader_name in spin_compatible_shaders:
		if shader_paths.has(shader_name):
			var shader: Shader = _get_shader(shader_name)
			if shader != null:
				safe.append(shader_name)
	return safe

func _apply_shader(shader_name: String) -> void:
	var shader: Shader = _get_shader(shader_name)
	if shader == null:
		return
	background.visible = false
	shader_bg.visible = true
	if not shader_materials.has(shader_name):
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = shader
		shader_materials[shader_name] = shader_mat
	shader_bg.material = shader_materials[shader_name]
	randomize_shader_params(shader_name, shader_bg.material)

func _get_random_background() -> Texture2D:
	var path: String = background_paths[randi() % background_paths.size()]
	return _load_texture(path)

func _load_texture(path: String) -> Texture2D:
	if not texture_cache.has(path):
		var texture_resource := load(path)
		if texture_resource is Texture2D:
			texture_cache[path] = texture_resource
			return texture_resource
		return Texture2D.new()
	return texture_cache[path]

func _get_shader(shader_name: String) -> Shader:
	if not shader_cache.has(shader_name):
		var path: String = shader_paths.get(shader_name, "")
		if path == "":
			return null
		var shader_resource := load(path)
		if shader_resource is Shader:
			shader_cache[shader_name] = shader_resource
			return shader_resource
		return null
	return shader_cache.get(shader_name, null)

func randomize_shader_params(shader_name: String, shader_material: ShaderMaterial) -> void:
	if not shader_param_configs.has(shader_name):
		return

	for param_config in shader_param_configs[shader_name]:
		var param_name = param_config["name"]
		var param_type = param_config["type"]

		if param_type == "color":
			var current_color = shader_material.get_shader_parameter(param_name)
			if current_color is Color:
				var h = current_color.h
				var s = current_color.s
				var v = current_color.v
				var hue_var = param_config.get("hue_variation", 0.1)
				var sat_var = param_config.get("sat_variation", 0.2)
				var val_var = param_config.get("val_variation", 0.2)

				h = clamp(h + randf_range(-hue_var, hue_var), 0.0, 1.0)
				s = clamp(s + randf_range(-sat_var, sat_var), 0.0, 1.0)
				v = clamp(v + randf_range(-val_var, val_var), 0.0, 1.0)

				shader_material.set_shader_parameter(param_name, Color.from_hsv(h, s, v, current_color.a))
			else:
				# If no current color, set a random one
				var h = randf()
				var s = randf_range(0.5, 1.0)
				var v = randf_range(0.5, 1.0)
				shader_material.set_shader_parameter(param_name, Color.from_hsv(h, s, v, 1.0))

		elif param_type == "float":
			var min_val = param_config.get("min", 0.0)
			var max_val = param_config.get("max", 1.0)
			shader_material.set_shader_parameter(param_name, randf_range(min_val, max_val))

		elif param_type == "int":
			var min_val = param_config.get("min", 0)
			var max_val = param_config.get("max", 10)
			shader_material.set_shader_parameter(param_name, randi_range(min_val, max_val))

		elif param_type == "vec3_color":
			var current_vec = shader_material.get_shader_parameter(param_name)
			if current_vec is Vector3:
				var variation = param_config.get("variation", 0.2)
				var r = clamp(current_vec.x + randf_range(-variation, variation), 0.0, 1.0)
				var g = clamp(current_vec.y + randf_range(-variation, variation), 0.0, 1.0)
				var b = clamp(current_vec.z + randf_range(-variation, variation), 0.0, 1.0)
				shader_material.set_shader_parameter(param_name, Vector3(r, g, b))
			else:
				# If no current vec, set a random one
				var r = randf()
				var g = randf()
				var b = randf()
				shader_material.set_shader_parameter(param_name, Vector3(r, g, b))
