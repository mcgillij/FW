extends Node

var is_rotated = false
const SAVE_PATH = "user://save/rotation.cfg"
const BASE_SIZE = Vector2i(720, 1280)
const FALLBACK_TRANSITION_TEXTURE := preload("res://title.png")

const TRANSITION_PRESETS = {
	"Directional Wipe": { "transition_type": 0, "grid_size": Vector2(1, 0) },
	"Corner Wipe": { "transition_type": 0, "grid_size": Vector2(1, 1) },
	"Diagonal Wipe": { "transition_type": 0, "grid_size": Vector2(1, 1), "rotation_angle": 45.0 },
	"Cross-shaped Transition": { "transition_type": 0, "from_center": true, "stagger": Vector2(1, 1) },
	"Iris Transition": { "transition_type": 2, "from_center": true, "edges": 64, "shape_feather": 0.1 },
	"Spike Transition": { "transition_type": 2, "from_center": true, "edges": 3, "grid_size": Vector2(0.5, 0), "rotation_angle": 0.0 },
	"Overlapping Diamonds": { "transition_type": 2, "from_center": true, "grid_size": Vector2(0.5, 50), "edges": 3, "shape_feather": 0.0 },
	"Center-Clock Transition": { "sectors": 2, "transition_type": 3, "invert": false, "from_center": true, "grid_size": Vector2(1, 1) },
	"Center-Clock Transition1": { "sectors": 1, "transition_type": 3, "invert": false, "from_center": true, "grid_size": Vector2(1, 1) },
	"Center-Clock Transition3": { "sectors": 3, "transition_type": 3, "invert": false, "from_center": true, "grid_size": Vector2(1, 1) },
	"Corner-Clock Transition3": { "sectors": 3, "transition_type": 3, "invert": false, "grid_size": Vector2(1, 1), "from_center": false },
	"Corner-Clock Transition2": { "sectors": 2, "transition_type": 3, "invert": false, "grid_size": Vector2(1, 1), "from_center": false },
	"Corner-Clock Transition1": { "sectors": 1, "transition_type": 3, "invert": false, "grid_size": Vector2(1, 1), "from_center": false },
	"Seamless Striped Flower": { "transition_type": 3, "invert": false, "grid_size": Vector2(5, 5), "flip_frequency": Vector2(2, 2), "sectors": 16 },
}

var scene_host: SubViewport
var rotator_rig: Node2D
var current_scene_path: String
var main_scene_node: Node

var transition_rect: TextureRect
var transition_material: ShaderMaterial
var fade_rect: ColorRect
var is_transitioning := false
var lightweight_transition := false

func _ready():
	load_setting()
	save_setting()
	lightweight_transition = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")

	if is_rotated:
		get_tree().node_added.connect(_on_node_added)
		# Defer setup to ensure the scene tree is ready
		call_deferred("setup_rotation_rig")
	else:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

	# Transition setup
	var transition_layer = CanvasLayer.new()
	transition_layer.layer = 128 # High value to ensure it's on top
	add_child(transition_layer)

	transition_rect = TextureRect.new()
	transition_rect.texture = FALLBACK_TRANSITION_TEXTURE
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Make sure the rect covers the whole screen.
	transition_rect.size = get_viewport().get_size()
	get_window().size_changed.connect(_on_window_size_changed)

	transition_material = ShaderMaterial.new()
	transition_material.shader = load("res://Shaders/transition/transition.gdshader")
	transition_rect.material = transition_material
	transition_layer.add_child(transition_rect)

	fade_rect = ColorRect.new()
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color.BLACK
	fade_rect.modulate = Color(1, 1, 1, 0)
	fade_rect.size = transition_rect.size
	fade_rect.visible = false
	transition_layer.add_child(fade_rect)

	# Start with the transition rect invisible
	transition_rect.visible = false

func _on_window_size_changed():
	var viewport_size = get_viewport().get_size()
	if is_instance_valid(transition_rect):
		transition_rect.size = viewport_size
	if is_instance_valid(fade_rect):
		fade_rect.size = viewport_size

func _on_node_added(node):
	# Popups are added to the root, so we need to reparent them to our scene_host.
	if node is Popup or node is Window:
		if node.get_parent() == get_tree().root and is_instance_valid(scene_host):
			node.get_parent().remove_child(node)
			scene_host.add_child(node)

func setup_rotation_rig():
	if is_instance_valid(rotator_rig): return # Already setup

	# This is the key: Take full control from Godot's automatic scaling.
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var window = get_window()
	window.size = Vector2i(BASE_SIZE.y, BASE_SIZE.x)

	rotator_rig = Node2D.new()
	rotator_rig.name = "ScreenRotatorRig"
	rotator_rig.process_mode = Node.PROCESS_MODE_ALWAYS

	var container = SubViewportContainer.new()
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	container.stretch = true
	container.size = BASE_SIZE
	container.position = -BASE_SIZE / 2.0

	scene_host = SubViewport.new()
	scene_host.size = BASE_SIZE
	scene_host.handle_input_locally = true
	scene_host.set_as_audio_listener_2d(true)
	scene_host.name = "SceneHost"
	scene_host.process_mode = Node.PROCESS_MODE_ALWAYS

	container.add_child(scene_host)
	rotator_rig.add_child(container)
	get_tree().root.add_child(rotator_rig)

	rotator_rig.position = window.size / 2.0
	rotator_rig.rotation_degrees = 90

	# Reparent the current scene instead of reloading it
	main_scene_node = get_tree().current_scene
	current_scene_path = main_scene_node.scene_file_path
	main_scene_node.get_parent().remove_child(main_scene_node)
	scene_host.add_child(main_scene_node)

	var achievement_slide_in = get_node_or_null("/root/AchievementSlideIn")
	if achievement_slide_in:
		achievement_slide_in.get_parent().remove_child(achievement_slide_in)
		scene_host.add_child(achievement_slide_in)

func teardown_rotation_rig():
	if not is_instance_valid(rotator_rig): return # Nothing to teardown

	# Move the scene back to the root
	if is_instance_valid(main_scene_node):
		scene_host.remove_child(main_scene_node)
		get_tree().root.add_child(main_scene_node)
		get_tree().current_scene = main_scene_node
		main_scene_node = null

	var achievement_slide_in = get_node_or_null("/root/AchievementSlideIn")
	if achievement_slide_in:
		achievement_slide_in.get_parent().remove_child(achievement_slide_in)
		get_tree().root.add_child(achievement_slide_in)

	# Cleanup the rig
	rotator_rig.queue_free()
	rotator_rig = null
	scene_host = null

	# Restore window
	var window = get_window()
	window.size = BASE_SIZE
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

	# Disconnect popup handler
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

func change_scene(path: String, transition_params: Dictionary = {}):
	if is_transitioning:
		return

	is_transitioning = true

	if lightweight_transition:
		await _change_scene_lightweight(path, transition_params)
	else:
		await _change_scene_with_shader(path, transition_params)

	is_transitioning = false

func _change_scene_lightweight(path: String, transition_params: Dictionary) -> void:
	if not is_instance_valid(fade_rect):
		await _change_scene_with_shader(path, transition_params)
		return

	fade_rect.size = get_viewport().get_size()
	fade_rect.position = Vector2.ZERO
	fade_rect.visible = true
	fade_rect.modulate = Color(1, 1, 1, 0)

	var fade_out = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, 0.25)
	await fade_out.finished

	var swap_success: bool = await _swap_scene(path)

	var fade_in = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 0.25)
	await fade_in.finished

	fade_rect.visible = false

	if not swap_success:
		push_warning("Screen swap failed for %s" % path)

func _change_scene_with_shader(path: String, transition_params: Dictionary) -> void:
	if not is_instance_valid(transition_rect):
		await _swap_scene(path)
		return

	transition_rect.size = get_viewport().get_size()
	transition_rect.position = Vector2.ZERO

	await get_tree().process_frame
	var viewport_tex := get_viewport().get_texture()
	var captured := false
	if viewport_tex:
		var img := viewport_tex.get_image()
		if img:
			var tex := ImageTexture.create_from_image(img)
			if tex:
				transition_rect.texture = tex
				captured = true

	if not captured:
		transition_rect.texture = FALLBACK_TRANSITION_TEXTURE

	transition_rect.visible = true

	var final_params = {}
	var preset_name = get_random_preset_name()
	if TRANSITION_PRESETS.has(preset_name):
		final_params = TRANSITION_PRESETS[preset_name].duplicate()

	for key in transition_params:
		final_params[key] = transition_params[key]

	var duration = final_params.get("duration", 0.5)
	var mat: ShaderMaterial = transition_material if transition_material else transition_rect.material
	if mat:
		mat.set_shader_parameter("progress", 0.0)
		for param_name in final_params:
			if param_name != "duration":
				mat.set_shader_parameter(param_name, final_params[param_name])

	var fade_out = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if mat:
		fade_out.tween_property(mat, "shader_parameter/progress", 1.0, duration)
		await fade_out.finished
	else:
		fade_out.tween_property(transition_rect, "modulate:a", 1.0, duration)
		await fade_out.finished

	var swap_success: bool = await _swap_scene(path)

	var fade_in = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if mat:
		fade_in.tween_property(mat, "shader_parameter/progress", 0.0, duration)
	else:
		fade_in.tween_property(transition_rect, "modulate:a", 0.0, duration)
	await fade_in.finished

	transition_rect.visible = false
	transition_rect.texture = FALLBACK_TRANSITION_TEXTURE

	if not swap_success:
		push_warning("Screen swap failed for %s" % path)

func _swap_scene(path: String) -> bool:
	current_scene_path = path

	if not is_rotated:
		var error := get_tree().change_scene_to_file(path)
		if error != OK:
			push_error("Failed to change scene to %s" % path)
			return false
		await get_tree().process_frame
		main_scene_node = get_tree().current_scene
		return true

	if is_instance_valid(main_scene_node):
		main_scene_node.queue_free()
	var packed: Resource = load(path)
	if not packed:
		push_error("Failed to load scene resource %s" % path)
		return false
	if not (packed is PackedScene):
		push_error("Resource at %s is not a PackedScene" % path)
		return false
	var new_scene = packed.instantiate()
	main_scene_node = new_scene
	scene_host.add_child(new_scene)
	return true

func get_random_preset_name() -> String:
	var keys = TRANSITION_PRESETS.keys()
	return keys[randi() % keys.size()]

func get_main_scene() -> Node:
	if is_rotated:
		if is_instance_valid(scene_host) and scene_host.get_child_count() > 0:
			return scene_host.get_child(0)
		return null
	else:
		return get_tree().current_scene

func get_current_scene_path() -> String:
	return current_scene_path

func toggle_rotation():
	is_rotated = not is_rotated
	save_setting()

	if is_rotated:
		if not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)
		call_deferred("setup_rotation_rig")
	else:
		call_deferred("teardown_rotation_rig")

func save_setting():
	var config = ConfigFile.new()
	config.set_value("display", "rotated", is_rotated)
	config.save(SAVE_PATH)

func load_setting():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		if FW_Utils._is_steam_deck(): # always rotate on steamdeck
			is_rotated = true # testing on steamdeck
			config.set_value("display", "rotated", true)
		else:
			is_rotated = config.get_value("display", "rotated", false)
