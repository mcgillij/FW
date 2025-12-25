extends Resource
class_name FW_AbilityVisualEffect

@export var effect_name: String = ""
@export var effect_scene: Resource = null
@export var shader_path: String = "" # Optional: a path to a shader resource (res://...)
@export var duration: float = 1.0
@export var is_fullscreen: bool = false
@export var attach_to_owner: bool = false
@export var shader_params: Dictionary = {}
@export var z_index: int = 0
@export var effect_type: String = "scene" # "scene" or "shader"

func validate() -> bool:
	# Basic validation: must have a name and either a scene/resource or a shader path when appropriate
	if effect_name == "":
		return false
	if effect_type == "scene":
		return effect_scene != null
	elif effect_type == "shader":
		# Allow either an explicit shader_path string or an assigned shader resource in effect_scene
		return shader_path != "" or effect_scene != null
	# Fallback: accept if either is present
	return effect_scene != null or shader_path != ""
