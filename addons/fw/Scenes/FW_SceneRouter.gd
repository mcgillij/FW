extends Node
class_name FW_SceneRouter

const _PLATFORM_SCRIPT := preload("res://addons/fw/Platform/FW_Platform.gd")

signal rotation_changed(is_rotated: bool)
signal transition_started(path: String)
signal transition_finished(path: String, ok: bool)

const SECTION_DISPLAY := &"display"
const KEY_ROTATED := &"rotated"

const TRANSITION_PRESETS := {
	"Directional Wipe": { "transition_type": 0, "grid_size": Vector2(1, 0) },
	"Corner Wipe": { "transition_type": 0, "grid_size": Vector2(1, 1) },
	"Diagonal Wipe": { "transition_type": 0, "grid_size": Vector2(1, 1), "rotation_angle": 45.0 },
	"Cross-shaped Transition": { "transition_type": 0, "from_center": true, "stagger": Vector2(1, 1) },
	"Iris Transition": { "transition_type": 2, "from_center": true, "edges": 64, "shape_feather": 0.1 },
	"Spike Transition": { "transition_type": 2, "from_center": true, "edges": 3, "grid_size": Vector2(0.5, 0), "rotation_angle": 0.0 },
	"Overlapping Diamonds": { "transition_type": 2, "from_center": true, "grid_size": Vector2(0.5, 50), "edges": 3, "shape_feather": 0.0 },
	"Center-Clock Transition": { "sectors": 2, "transition_type": 3, "invert": false, "from_center": true, "grid_size": Vector2(1, 1) },
	"Corner-Clock Transition3": { "sectors": 3, "transition_type": 3, "invert": false, "grid_size": Vector2(1, 1), "from_center": false },
	"Seamless Striped Flower": { "transition_type": 3, "invert": false, "grid_size": Vector2(5, 5), "flip_frequency": Vector2(2, 2), "sectors": 16 },
}

@export var base_size: Vector2i = Vector2i(720, 1280)
@export var enable_rotation: bool = false
@export var force_rotation_on_steam_deck: bool = true
@export var reparent_popups_to_host: bool = true

# Transition configuration: all optional (no hard-coded res:// assets)
@export var overlay_layer: int = 128
@export var transition_shader: Shader
@export var fallback_transition_texture: Texture2D
@export var lightweight_transition_on_mobile: bool = true

var is_rotated: bool = false

var scene_host: SubViewport
var rotator_rig: Node2D
var current_scene_path: String
var main_scene_node: Node

var transition_rect: TextureRect
var transition_material: ShaderMaterial
var fade_rect: ColorRect
var is_transitioning: bool = false
var lightweight_transition: bool = false

var _config: FW_ConfigService

func configure(config: FW_ConfigService) -> void:
	_config = config
	if _config != null and not _config.changed.is_connected(_on_config_changed):
		_config.changed.connect(_on_config_changed)

func _ready() -> void:
	lightweight_transition = lightweight_transition_on_mobile and (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"))

	_apply_rotation_from_config()

	# Transition overlay setup (always safe; shader is optional)
	var transition_layer := CanvasLayer.new()
	transition_layer.layer = overlay_layer
	add_child(transition_layer)

	transition_rect = TextureRect.new()
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.size = get_viewport().get_size()
	transition_rect.visible = false
	transition_layer.add_child(transition_rect)

	fade_rect = ColorRect.new()
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color.BLACK
	fade_rect.modulate = Color(1, 1, 1, 0)
	fade_rect.size = transition_rect.size
	fade_rect.visible = false
	transition_layer.add_child(fade_rect)

	get_window().size_changed.connect(_on_window_size_changed)

	if transition_shader != null:
		transition_material = ShaderMaterial.new()
		transition_material.shader = transition_shader
		transition_rect.material = transition_material

	if enable_rotation and is_rotated:
		if reparent_popups_to_host and not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)
		call_deferred("setup_rotation_rig")
	else:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

func _on_window_size_changed() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if is_instance_valid(transition_rect):
		transition_rect.size = viewport_size
	if is_instance_valid(fade_rect):
		fade_rect.size = viewport_size

func _on_node_added(node: Node) -> void:
	if not reparent_popups_to_host:
		return
	if node is Popup or node is Window:
		if node.get_parent() == get_tree().root and is_instance_valid(scene_host):
			node.get_parent().remove_child(node)
			scene_host.add_child(node)

func set_rotated(value: bool, persist: bool = true) -> void:
	if is_rotated == value:
		return
	is_rotated = value
	rotation_changed.emit(is_rotated)
	if persist and _config != null:
		_config.set_value(SECTION_DISPLAY, KEY_ROTATED, is_rotated, true)

	if not enable_rotation:
		return

	if is_rotated:
		if reparent_popups_to_host and not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)
		call_deferred("setup_rotation_rig")
	else:
		call_deferred("teardown_rotation_rig")

func toggle_rotation(persist: bool = true) -> void:
	set_rotated(not is_rotated, persist)

func setup_rotation_rig() -> void:
	if is_instance_valid(rotator_rig):
		return
	if not enable_rotation:
		return

	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var window := get_window()
	window.size = Vector2i(base_size.y, base_size.x)

	rotator_rig = Node2D.new()
	rotator_rig.name = "ScreenRotatorRig"
	rotator_rig.process_mode = Node.PROCESS_MODE_ALWAYS

	var container := SubViewportContainer.new()
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	container.stretch = true
	container.size = base_size
	container.position = -base_size / 2.0

	scene_host = SubViewport.new()
	scene_host.size = base_size
	scene_host.handle_input_locally = true
	scene_host.set_as_audio_listener_2d(true)
	scene_host.name = "SceneHost"
	scene_host.process_mode = Node.PROCESS_MODE_ALWAYS

	container.add_child(scene_host)
	rotator_rig.add_child(container)
	get_tree().root.add_child(rotator_rig)

	rotator_rig.position = window.size / 2.0
	rotator_rig.rotation_degrees = 90

	# Reparent the current scene instead of reloading it.
	# Guard: if there is no current scene, do nothing.
	main_scene_node = get_tree().current_scene
	if main_scene_node != null and main_scene_node != self:
		current_scene_path = main_scene_node.scene_file_path
		if main_scene_node.get_parent() != null:
			main_scene_node.get_parent().remove_child(main_scene_node)
		scene_host.add_child(main_scene_node)

func teardown_rotation_rig() -> void:
	if not is_instance_valid(rotator_rig):
		return

	if is_instance_valid(main_scene_node):
		scene_host.remove_child(main_scene_node)
		get_tree().root.add_child(main_scene_node)
		get_tree().current_scene = main_scene_node
		main_scene_node = null

	rotator_rig.queue_free()
	rotator_rig = null
	scene_host = null

	var window := get_window()
	window.size = base_size
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func change_scene(path: String, transition_params: Dictionary = {}) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	transition_started.emit(path)

	if lightweight_transition:
		await _change_scene_fade(path)
	else:
		await _change_scene_with_optional_shader(path, transition_params)

	is_transitioning = false

func _change_scene_fade(path: String) -> void:
	if not is_instance_valid(fade_rect):
		var ok2 := await _swap_scene(path)
		transition_finished.emit(path, ok2)
		return

	fade_rect.size = get_viewport().get_size()
	fade_rect.position = Vector2.ZERO
	fade_rect.visible = true
	fade_rect.modulate = Color(1, 1, 1, 0)

	var fade_out := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 0.25)
	await fade_out.finished

	var swap_ok: bool = await _swap_scene(path)

	var fade_in := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 0.25)
	await fade_in.finished

	fade_rect.visible = false
	transition_finished.emit(path, swap_ok)

func _change_scene_with_optional_shader(path: String, transition_params: Dictionary) -> void:
	# If we don't have shader resources, fall back to fade.
	if transition_material == null or not is_instance_valid(transition_rect):
		await _change_scene_fade(path)
		return

	transition_rect.size = get_viewport().get_size()
	transition_rect.position = Vector2.ZERO

	await get_tree().process_frame
	var captured := false
	var viewport_tex := get_viewport().get_texture()
	if viewport_tex:
		var img := viewport_tex.get_image()
		if img:
			var tex := ImageTexture.create_from_image(img)
			if tex:
				transition_rect.texture = tex
				captured = true

	if not captured:
		transition_rect.texture = fallback_transition_texture

	transition_rect.visible = true

	var final_params := {}
	var preset_name := _get_random_preset_name()
	if TRANSITION_PRESETS.has(preset_name):
		final_params = TRANSITION_PRESETS[preset_name].duplicate()
	for key in transition_params:
		final_params[key] = transition_params[key]

	var duration := float(final_params.get("duration", 0.5))
	transition_material.set_shader_parameter("progress", 0.0)
	for param_name in final_params:
		if param_name != "duration":
			transition_material.set_shader_parameter(param_name, final_params[param_name])

	var fade_out := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(transition_material, "shader_parameter/progress", 1.0, duration)
	await fade_out.finished

	var swap_ok: bool = await _swap_scene(path)

	var fade_in := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(transition_material, "shader_parameter/progress", 0.0, duration)
	await fade_in.finished

	transition_rect.visible = false
	transition_rect.texture = fallback_transition_texture

	transition_finished.emit(path, swap_ok)

func _swap_scene(path: String) -> bool:
	current_scene_path = path

	if not enable_rotation or not is_rotated:
		var error := get_tree().change_scene_to_file(path)
		if error != OK:
			push_error("Failed to change scene to %s" % path)
			return false
		await get_tree().process_frame
		main_scene_node = get_tree().current_scene
		return true

	if not is_instance_valid(scene_host):
		push_error("Rotation enabled but scene_host is missing")
		return false

	if is_instance_valid(main_scene_node):
		main_scene_node.queue_free()

	var packed: Resource = load(path)
	if not packed:
		push_error("Failed to load scene resource %s" % path)
		return false
	if not (packed is PackedScene):
		push_error("Resource at %s is not a PackedScene" % path)
		return false

	var new_scene := (packed as PackedScene).instantiate()
	main_scene_node = new_scene
	scene_host.add_child(new_scene)
	return true

func get_main_scene() -> Node:
	if enable_rotation and is_rotated:
		return main_scene_node
	return get_tree().current_scene

func get_current_scene_path() -> String:
	return current_scene_path

func _get_random_preset_name() -> String:
	var keys := TRANSITION_PRESETS.keys()
	if keys.is_empty():
		return ""
	return str(keys[randi() % keys.size()])

func _apply_rotation_from_config() -> void:
	var rotated := false
	if force_rotation_on_steam_deck:
		var platform := _PLATFORM_SCRIPT.new()
		if platform.is_steam_deck():
			rotated = true
		elif _config != null:
			rotated = _config.get_bool(SECTION_DISPLAY, KEY_ROTATED, false)
		set_rotated(rotated, false)
		return
	elif _config != null:
		rotated = _config.get_bool(SECTION_DISPLAY, KEY_ROTATED, false)
	set_rotated(rotated, false)

func _on_config_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section != SECTION_DISPLAY or key != KEY_ROTATED:
		return
	_apply_rotation_from_config()
