extends Node

class_name FW_CombatVisualEffectsManager

# ===================================================================
# COMBAT VISUAL EFFECTS MANAGER - SIMPLIFIED & STABLE
# ===================================================================

# Constants for stability and maintainability
const MAX_OVERLAYS = 5
const BASE_LAYER = 100
const DEFAULT_DURATION = 0.6
const DEFAULT_FADE_DURATION = 0.7

# Core data structures
var registry: Dictionary = {} # effect_name -> {type, path, defaults}
var _loaded: Dictionary = {} # effect_name -> Resource
var _combat_cache: Dictionary = {} # per-combat cache

# Overlay pooling system
var _vfx_overlays: Array = [] # Pool of CanvasLayer objects
var _active_overlays: Dictionary = {} # handle -> CanvasLayer

# Active effects tracking
var _active: Dictionary = {} # handle -> effect info
var _next_handle: int = 1

# References
var fullscreen_overlay: TextureRect = null
var config_manager: Node = null

# ===================================================================
# UTILITY FUNCTIONS - COMMON OPERATIONS
# ===================================================================

func _get_target_root() -> Node:
	"""Get the appropriate root node for attaching VFX CanvasLayers"""
	if typeof(GDM) != TYPE_NIL and GDM and GDM.game_manager and GDM.game_manager.get_parent():
		return GDM.game_manager.get_parent()

	var screen_rotator = get_node_or_null("/root/ScreenRotator")
	if screen_rotator and screen_rotator.has_method("get_main_scene"):
		var scene_host = screen_rotator.get("scene_host")
		if scene_host and is_instance_valid(scene_host):
			return scene_host

	return get_tree().get_root()

func _is_valid_resource(res) -> bool:
	"""Safely check if a resource is valid and loaded"""
	return res != null and is_instance_valid(res)

func _safe_get_viewport() -> Viewport:
	"""Safely get the current viewport"""
	var vp = get_viewport()
	return vp if _is_valid_resource(vp) else null

func _create_white_texture() -> ImageTexture:
	"""Create a standard 1x1 white texture for shader effects"""
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex = ImageTexture.new()
	tex.set_image(img)
	return tex

func _ready() -> void:
	# Connect to ability visual effect events
	if EventBus.has_signal("ability_visual_effect_requested"):
		EventBus.ability_visual_effect_requested.connect(_on_ability_visual_effect_requested)

	# Cache config manager reference for performance
	config_manager = get_node_or_null("/root/ConfigManager")

func register_fullscreen_overlay(node: TextureRect) -> void:
	fullscreen_overlay = node

func _get_available_overlay() -> TextureRect:
	"""Get an available VFX overlay or create a new one. Returns null if limit reached."""
	# First try to reuse an available overlay
	while not _vfx_overlays.is_empty():
		var canvas_layer = _vfx_overlays.pop_back()
		if not _is_valid_resource(canvas_layer):
			continue

		# Re-add to scene tree using utility function
		var target_root = _get_target_root()
		if not target_root:
			push_warning("VFX: No valid target root for overlay reuse")
			continue

		target_root.add_child(canvas_layer)

		# Get the TextureRect from the CanvasLayer
		var overlay = canvas_layer.get_child(0) as TextureRect
		if _is_valid_resource(overlay):
			overlay.visible = true
			overlay.modulate = Color(1, 1, 1, 1)
			return overlay
		else:
			# Invalid overlay, clean up the canvas layer
			target_root.remove_child(canvas_layer)
			canvas_layer.queue_free()

	# Create a new overlay if we haven't hit the limit
	if _vfx_overlays.size() + _active_overlays.size() < MAX_OVERLAYS:
		return _create_new_overlay()

	# If we're at the limit, return null (effect will be skipped)
	push_warning("Maximum VFX overlays reached (%d). Effect will be skipped." % MAX_OVERLAYS)
	return null

func _create_new_overlay() -> TextureRect:
	"""Create a new VFX overlay with proper layering. Returns null if creation fails."""
	# Get the appropriate root node using utility function
	var target_root = _get_target_root()
	if not target_root:
		push_warning("VFX: No valid target root for new overlay creation")
		return null

	# Create a new CanvasLayer at a high layer (above all UI)
	var canvas_layer = CanvasLayer.new()
	if not canvas_layer:
		push_warning("VFX: Failed to create CanvasLayer")
		return null

	var layer_index = BASE_LAYER + _vfx_overlays.size() + _active_overlays.size()

	# If a registered fullscreen_overlay exists and is itself on a CanvasLayer,
	# make sure VFX overlays are created above it so shader overlays aren't
	# occluded by the fullscreen overlay (which is often used for booster tints).
	if _is_valid_resource(fullscreen_overlay):
		var parent = fullscreen_overlay.get_parent()
		if parent and parent is CanvasLayer:
			layer_index = max(layer_index, parent.layer + 1)

	canvas_layer.layer = layer_index
	target_root.add_child(canvas_layer)

	# Create the TextureRect for effects
	var overlay = TextureRect.new()
	if not overlay:
		push_warning("VFX: Failed to create TextureRect")
		target_root.remove_child(canvas_layer)
		canvas_layer.queue_free()
		return null

	overlay.name = "VFXOverlay_%d" % layer_index
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	overlay.modulate = Color(1, 1, 1, 0)  # Start transparent

	# Create a white texture for shaders to work with using utility function
	overlay.texture = _create_white_texture()

	canvas_layer.add_child(overlay)
	return overlay

func _apply_shader_parameters(mat: ShaderMaterial, effect_name: String, params: Dictionary) -> bool:
	"""Apply shader parameters safely. Returns false if any critical parameter fails."""
	if not mat:
		return false

	# Step 1: Copy static parameters from AbilityVisualEffect resource (stored in registry.defaults)
	var spec = registry.get(effect_name, {})
	var defaults = spec.get("defaults", {})
	for param_name in defaults.keys():
		if _material_has_parameter(mat, param_name):
			mat.set_shader_parameter(param_name, defaults[param_name])

	# Set positions and num_positions (Shader uses positions_0..positions_8)
	if params.has("positions"):
		var ps = params.positions
		for i in range(0, 9):
			var pname = "positions_%d" % i
			var pval = Vector2(-1.0, -1.0)
			if i < ps.size():
				pval = ps[i]
			mat.set_shader_parameter(pname, pval)
		mat.set_shader_parameter("num_positions", ps.size())

	# Step 2: Handle target positioning - SINGLE PATH FOR ALL SHADER EFFECTS
	if params.has("target_position"):
		var target_pos = params["target_position"]
		mat.set_shader_parameter("target_position", target_pos)
		mat.set_shader_parameter("column_x", target_pos.x)
		mat.set_shader_parameter("bottom_y", max(target_pos.y, 0.01))
		mat.set_shader_parameter("row_y", target_pos.y)

		# Special handling for multi-bolt lightning effects
		if effect_name.contains("lightning"):
			var bolt_count = defaults.get("bolt_count", 1)
			if bolt_count > 1:
				mat.set_shader_parameter("bolt_target_position_0", target_pos)
				mat.set_shader_parameter("bolt_target_position_1", target_pos)

	elif params.has("grid_cell"):
		var gp = params["grid_cell"]
		if typeof(gp) == TYPE_VECTOR2:
			var vp = get_viewport()
			if vp and GDM.grid:
				var normp = GDM.grid.grid_cell_to_normalized_target(int(gp.x), gp.y, vp)
				normp.x = clamp(normp.x, 0.0, 1.0)
				normp.y = clamp(normp.y, 0.0, 1.0)

				mat.set_shader_parameter("target_position", normp)
				mat.set_shader_parameter("column_x", normp.x)
				mat.set_shader_parameter("bottom_y", max(normp.y, 0.01))
				mat.set_shader_parameter("row_y", normp.y)

				# Special handling for multi-bolt lightning effects
				if effect_name.contains("lightning"):
					var bolt_count = defaults.get("bolt_count", 1)
					if bolt_count > 1:
						mat.set_shader_parameter("bolt_target_position_0", normp)
						mat.set_shader_parameter("bolt_target_position_1", normp)

	# Handle multiple positions from grid_cells
	if params.has("grid_cells"):
		var positions = []
		for cell in params.grid_cells:
			if typeof(cell) == TYPE_VECTOR2:
				var vp = get_viewport()
				if vp and GDM.grid:
					var normp = GDM.grid.grid_cell_to_normalized_target(int(cell.x), cell.y, vp)
					normp.x = clamp(normp.x, 0.0, 1.0)
					normp.y = clamp(normp.y, 0.0, 1.0)
					positions.append(normp)
		params["positions"] = positions
		params["num_positions"] = positions.size()

		# Update shader parameters for computed positions
		var ps2 = params.positions
		for j in range(0, 9):
			var pname2 = "positions_%d" % j
			var pval2 = Vector2(-1.0, -1.0)
			if j < ps2.size():
				pval2 = ps2[j]
			mat.set_shader_parameter(pname2, pval2)
		mat.set_shader_parameter("num_positions", ps2.size())

		if effect_name == "claw_row_overlay":
			var rows_list = params.get("claw_rows", [])
			var positions_local = params.get("positions", [])
			var row_count = int(params.get("row_variant", 0))
			if row_count <= 0:
				row_count = max(rows_list.size(), positions_local.size())
			row_count = clamp(row_count, 1, 3)
			mat.set_shader_parameter("row_variant", row_count)

			var y_values: Array = []
			for p in positions_local:
				if typeof(p) == TYPE_VECTOR2:
					y_values.append(p.y)
			if y_values.is_empty() and params.has("row_y"):
				var fallback_y = params["row_y"]
				if typeof(fallback_y) == TYPE_FLOAT or typeof(fallback_y) == TYPE_INT:
					y_values.append(float(fallback_y))

			if not y_values.is_empty():
				y_values.sort()
				var mid_index = int(floor(float(y_values.size()) * 0.5))
				var row_center_uv = y_values[mid_index]
				if y_values.size() == 2:
					row_center_uv = (y_values[0] + y_values[1]) * 0.5

				var row_spacing_uv = 0.0
				if row_count == 2 and y_values.size() >= 2:
					row_spacing_uv = abs(y_values[1] - y_values[0]) * 0.5
				elif row_count >= 3 and y_values.size() >= 3:
					row_spacing_uv = abs(row_center_uv - y_values[0])

				mat.set_shader_parameter("row_center", row_center_uv)
				mat.set_shader_parameter("row_spacing", row_spacing_uv)

				var half_height = params.get("row_half_height", defaults.get("row_half_height", 0.08))
				var anchor_col = params.get("claw_anchor_col", 0.0)
				if rows_list.size() > 0 and (typeof(anchor_col) == TYPE_FLOAT or typeof(anchor_col) == TYPE_INT) and typeof(GDM) != TYPE_NIL and GDM and GDM.grid:
					var vp4 = get_viewport()
					if vp4:
						var col_index = int(round(float(anchor_col)))
						var base_row = float(rows_list[0])
						var base_norm = GDM.grid.grid_cell_to_normalized_target(col_index, base_row, vp4)
						var offset_norm = GDM.grid.grid_cell_to_normalized_target(col_index, base_row + 0.5, vp4)
						var computed_half = abs(offset_norm.y - base_norm.y)
						if computed_half > 0.0:
							half_height = computed_half
				mat.set_shader_parameter("row_half_height", half_height)

			if params.has("slash_intensity"):
				mat.set_shader_parameter("slash_intensity", params["slash_intensity"])
			if params.has("glow_intensity"):
				mat.set_shader_parameter("glow_intensity", params["glow_intensity"])
			if params.has("spark_density"):
				mat.set_shader_parameter("spark_density", params["spark_density"])
			if params.has("scratch_frequency"):
				mat.set_shader_parameter("scratch_frequency", params["scratch_frequency"])

	# Step 3: Apply runtime parameter overrides for arbitrary shader-facing values
	var skip := {
		"duration": true,
		"grid_cells": true,
		"positions": true,
		"target_position": true,
		"grid_cell": true,
		"num_positions": true,
		"_canvas_layer": true
	}
	var alias_map := {
		"color": "effect_color"
	}
	for param_name in params.keys():
		if skip.has(param_name):
			continue
		var uniform_name = alias_map.get(param_name, param_name)
		if _material_has_parameter(mat, uniform_name):
			mat.set_shader_parameter(uniform_name, params[param_name])

	# Handle mask texture if positions were computed
	if params.has("positions") and _material_has_parameter(mat, "mask"):
		var norm_positions = params.positions
		if norm_positions and norm_positions.size() > 0:
			var overlay = null
			# Find the overlay for this effect (needed for mask texture creation)
			for active_handle in _active_overlays:
				if _active_overlays[active_handle] == params.get("_canvas_layer"):
					var canvas_layer = _active_overlays[active_handle]
					if canvas_layer and canvas_layer.get_child_count() > 0:
						overlay = canvas_layer.get_child(0)
					break

			if overlay:
				var mask_tex = _build_mask_texture(overlay, norm_positions, 2)
				if mask_tex:
					mat.set_shader_parameter("mask", mask_tex)

				# Set center uniform
				var center_uv = Vector2(0.5, 0.5)
				if params.has("target_position"):
					center_uv = params["target_position"]
				elif params.has("grid_cell"):
					var gp = params["grid_cell"]
					if typeof(gp) == TYPE_VECTOR2:
						var vp3 = get_viewport()
						if vp3 and GDM.grid:
							center_uv = GDM.grid.grid_cell_to_normalized_target(int(gp.x), gp.y, vp3)
				mat.set_shader_parameter("center", center_uv)

	return true

func _material_has_parameter(mat, _param_name: String) -> bool:
	"""In Godot 4, we can safely set shader parameters without checking if they exist.
	set_shader_parameter() will ignore parameters that don't exist in the shader.
	This function now always returns true to simplify the logic.
	"""
	return mat != null and mat is ShaderMaterial

func _return_overlay_to_pool(overlay: TextureRect) -> void:
	"""Return an overlay to the pool for reuse"""
	if not _is_valid_resource(overlay):
		return

	# Get the CanvasLayer parent
	var canvas_layer = overlay.get_parent() as CanvasLayer
	if not _is_valid_resource(canvas_layer):
		return

	# Remove from scene tree safely
	var scene_root = canvas_layer.get_parent()
	if scene_root:
		scene_root.remove_child(canvas_layer)

	# Reset overlay state
	overlay.material = null
	overlay.modulate = Color(1, 1, 1, 0)

	# Reset to default white texture using utility function
	overlay.texture = _create_white_texture()

	# Add CanvasLayer back to pool
	_vfx_overlays.append(canvas_layer)


func _build_mask_texture(overlay: TextureRect, norm_positions: Array, downsample: int = 2) -> ImageTexture:
	"""Build a downsampled mask ImageTexture from normalized positions (0..1).
	Returns an ImageTexture where white pixels mark tile centers.
	"""
	var vp = overlay.get_viewport() if overlay else get_viewport()
	var vp_size = Vector2(1024, 576)
	if vp:
		var vr = vp.get_visible_rect()
		if vr:
			vp_size = vr.size

	var w = max(1, int(vp_size.x / max(1, downsample)))
	var h = max(1, int(vp_size.y / max(1, downsample)))

	var img = Image.create(w, h, false, Image.FORMAT_RF)
	# In Godot 4 Image.lock()/unlock() were removed; set_pixel can be used directly.
	img.fill(Color(0,0,0,1))

	var radius = max(1, int(3.0 / max(1, downsample)))
	for pos in norm_positions:
		if typeof(pos) != TYPE_VECTOR2:
			continue
		var px = int(clamp(pos.x, 0.0, 1.0) * float(w - 1))
		var py = int(clamp(pos.y, 0.0, 1.0) * float(h - 1))
		for yy in range(max(0, py - radius), min(h, py + radius + 1)):
			for xx in range(max(0, px - radius), min(w, px + radius + 1)):
				var dx = xx - px
				var dy = yy - py
				if dx * dx + dy * dy <= radius * radius:
					img.set_pixel(xx, yy, Color(1, 0, 0, 1))

	var tex = ImageTexture.new()
	tex.set_image(img)
	return tex

func _on_ability_visual_effect_requested(effect_name: String, params: Dictionary = {}) -> void:
	"""Handle ability visual effect requests - main entry point from EventBus"""

	# Check if effect is registered, attempt auto-load if missing
	if not registry.has(effect_name):
		_attempt_auto_registration(effect_name)

	# Play the effect
	var handle = play_effect(effect_name, params)
	if handle == -1:
		push_warning("Failed to play effect: %s" % effect_name)

func _attempt_auto_registration(effect_name: String) -> void:
	"""Try to auto-load effect from common resource locations"""
	var search_names: Array = []
	var prefixed = "ability_vfx_%s" % effect_name
	search_names.append(prefixed)
	search_names.append(effect_name)

	if effect_name.find("_") != -1:
		var base = effect_name.split("_")[0]
		if base != "":
			search_names.append("ability_vfx_%s" % base)
			search_names.append(base)

	var unique_names: Array = []
	for effect_id in search_names:
		if effect_id == "":
			continue
		if unique_names.has(effect_id):
			continue
		unique_names.append(effect_id)

	var search_dirs = [
		"res://Abilities/Resources/vfx/",
		"res://Abilities/Resources/"
	]

	for effect_id in unique_names:
		for dir_path in search_dirs:
			var candidate_path = "%s%s.tres" % [dir_path, effect_id]
			if not ResourceLoader.exists(candidate_path):
				continue
			var res = ResourceLoader.load(candidate_path)
			if res:
				register_ability_visual_effect(res)
				return

# Simple helpers for the existing screen overlay (used by boosters/ability UI)
func overlay_fade_in(color: Color = Color(1,1,1,1), duration: float = 0.7) -> void:
	if not fullscreen_overlay:
		return
	var tw = get_tree().create_tween()
	fullscreen_overlay.modulate = Color(color.r, color.g, color.b, 0)
	tw.tween_property(fullscreen_overlay, "modulate", color, duration).from(Color(1,1,1,0)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.play()

func overlay_fade_out(duration: float = 0.7) -> void:
	if not fullscreen_overlay:
		return
	var tw = get_tree().create_tween()
	tw.tween_property(fullscreen_overlay, "modulate", Color(1,1,1,0), duration).from(fullscreen_overlay.modulate).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.play()

func register_effect(effect_name: String, spec: Dictionary) -> void:
	registry[effect_name] = spec

func preload_effects(names: Array) -> void:
	for n in names:
		_preload_one(n)

# Note: `preload_effects` is a convenience API to warm resources. The
# manager auto-loads on first use in `play_effect`, so calling this is
# optional and used to reduce first-frame hitches.

func _preload_one(effect_name: String) -> void:
	if _loaded.has(effect_name):
		return
	if not registry.has(effect_name):
		push_warning("Effect '%s' not registered" % effect_name)
		return
	var spec = registry[effect_name]
	var path = spec.get("path", "")
	if path == "":
		push_warning("Effect '%s' has no path" % effect_name)
		return
	# Load resource from path
	var res = ResourceLoader.load(path)
	if res:
		_loaded[effect_name] = res


func register_ability_visual_effect(effect_res: Resource) -> void:
	"""Register an AbilityVisualEffect resource into the per-combat cache.
	Accepts either an AbilityVisualEffect or a Dictionary with similar keys.
	This does not instantiate the effect, just stores metadata for quick loading.
	"""
	if not effect_res:
		return
	# Accept both our new AbilityVisualEffect resource and simple dicts
	var ename: String = ""
	var epath: String = ""
	var etyp: String = ""
	var edefaults: Dictionary = {}
	var scene_res = null

	# Resource-based AbilityVisualEffect (prefer properties if present)
	if typeof(effect_res) == TYPE_OBJECT:
		# Try to read canonical properties safely using get() to avoid calling non-existent methods
		var tmp_name = effect_res.get("effect_name")
		if tmp_name != null and str(tmp_name) != "":
			ename = tmp_name

		var tmp_scene = effect_res.get("effect_scene")
		if tmp_scene != null:
			scene_res = tmp_scene
			# Try to get the resource path from the scene
			if tmp_scene is PackedScene:
				epath = tmp_scene.resource_path
			elif typeof(tmp_scene) == TYPE_OBJECT and tmp_scene.has_method("get_path"):
				epath = tmp_scene.get_path()
			elif typeof(tmp_scene) == TYPE_OBJECT and "resource_path" in tmp_scene:
				epath = tmp_scene.resource_path

	# Also support a direct shader_path string on the resource (preferred for editor-friendly .tres)
	var tmp_shader_path = effect_res.get("shader_path")
	if tmp_shader_path != null and str(tmp_shader_path) != "":
		epath = tmp_shader_path

	# Use declared effect_type when available, otherwise infer
	var tmp_type = effect_res.get("effect_type")
	if tmp_type != null and str(tmp_type) != "":
		etyp = tmp_type
	else:
		# Infer type: if we have a shader_path, it's shader; if we have effect_scene, it's scene
		if tmp_shader_path != null and str(tmp_shader_path) != "":
			etyp = "shader"
		elif scene_res != null:
			etyp = "scene"
		elif epath != "":
			etyp = "scene"
		else:
			etyp = "shader"

	# Copy declared shader params / defaults if present
	var sp = effect_res.get("shader_params")
	if sp != null and typeof(sp) == TYPE_DICTIONARY:
		edefaults = sp.duplicate(true)

		# duration may be present on the resource
		var tmp_dur = effect_res.get("duration")
		if tmp_dur != null:
			edefaults["duration"] = tmp_dur

	elif typeof(effect_res) == TYPE_DICTIONARY:
		if effect_res.has("effect_name"):
			ename = effect_res["effect_name"]
		if effect_res.has("path"):
			epath = effect_res["path"]
		else:
			epath = ""
		if effect_res.has("type"):
			etyp = effect_res["type"]
		else:
			etyp = "scene"
		if effect_res.has("defaults"):
			edefaults = effect_res["defaults"].duplicate(true)
		else:
			edefaults = {}
	else:
		# Attempt to be permissive: maybe caller passed a path string or a resource id
		var attempt_path = str(effect_res)
		if attempt_path != "":
			var maybe_res = ResourceLoader.load(attempt_path)
			if maybe_res:
				register_ability_visual_effect(maybe_res)
				return
		# Still unsupported: warn
		push_warning("register_ability_visual_effect: unsupported type %s" % typeof(effect_res))
		return

	if ename == "":
		# If the resource didn't declare an effect_name, attempt to reload the resource
		# from disk (useful if the file was edited on disk while the running game has a
		# cached or partially-initialized Resource). If reloaded resource contains
		# the fields, prefer those values.
		var rpath = ""
		if typeof(effect_res) == TYPE_OBJECT:
			rpath = effect_res.resource_path
		if rpath != "":
			var disk_res = ResourceLoader.load(rpath)
			if disk_res and typeof(disk_res) == TYPE_OBJECT and disk_res != effect_res:
				var disk_name = disk_res.get("effect_name")
				if disk_name != null and str(disk_name) != "":
					ename = disk_name
					# refresh other discovered values as well
					var disk_scene = disk_res.get("effect_scene")
					if disk_scene != null:
						if typeof(disk_scene) == TYPE_OBJECT and disk_scene.has_method("get_path"):
							epath = disk_scene.get_path()
						elif typeof(disk_scene) == TYPE_OBJECT and disk_scene.has_property("resource_path"):
							epath = disk_scene.resource_path
						elif disk_scene is PackedScene:
							epath = disk_scene.resource_path
					var disk_type = disk_res.get("effect_type")
					if disk_type != null and str(disk_type) != "":
						etyp = disk_type
					# Prefer explicit shader_path on disk resource if present
					var disk_shader_path = disk_res.get("shader_path")
					if disk_shader_path != null and str(disk_shader_path) != "":
						epath = disk_shader_path
					var disk_sp = disk_res.get("shader_params")
					if disk_sp != null and typeof(disk_sp) == TYPE_DICTIONARY:
						edefaults = disk_sp.duplicate(true)
					var disk_dur = disk_res.get("duration")
					if disk_dur != null:
						edefaults["duration"] = disk_dur
			# If still missing, give a clearer warning
		if ename == "":
			push_warning("AbilityVisualEffect missing effect_name (resource_path=%s)" % rpath)
			return

	# Only write into the global registry if we have a concrete path. For scene-based
	# AbilityVisualEffect resources that embed a PackedScene instance (no path), register
	# them as scene effects and stash the PackedScene in _loaded so play_effect can
	# instantiate them even when there's no file path.
	if not registry.has(ename):
		if epath != "":
			registry[ename] = {"type": etyp, "path": epath, "defaults": edefaults}
		elif scene_res != null:
			# We have an embedded PackedScene resource; register as a scene with empty path
			registry[ename] = {"type": "scene", "path": "", "defaults": edefaults}
			_loaded[ename] = scene_res

	# Add to per-combat cache metadata for quick warm-up
	_combat_cache[ename] = {"type": etyp, "path": epath, "defaults": edefaults}

func register_effects_for_combatant(combatant) -> void:
	"""Iterate a combatant's abilities and register any AbilityVisualEffect resources.
	Combatant is expected to expose an `abilities` array where each Ability may have
	a `visual_effect` Resource reference. Legacy `visual_effects` arrays are removed.
	"""
	if not combatant:
		return
	# Support both Dictionary-based and Resource/Object combatant representations.
	var abilities = null
	if typeof(combatant) == TYPE_DICTIONARY:
		if not combatant.has("abilities"):
			return
		abilities = combatant["abilities"]
	elif typeof(combatant) == TYPE_OBJECT:
		# Object.get("prop") is safe on Resource/Object and returns null if missing.
		abilities = combatant.get("abilities")
	else:
		return

	if not abilities:
		return

	for ability in abilities:
		if ability == null:
			continue

		# Dictionary-based ability: expect a single `visual_effect` key
		if typeof(ability) == TYPE_DICTIONARY:
			var dict_effect_keys = ["visual_effect", "cast_visual_effect", "sinker_impact_visual_effect"]
			for key in dict_effect_keys:
				if ability.has(key) and ability[key]:
					register_ability_visual_effect(ability[key])
		# Object/Resource-based ability
		elif typeof(ability) == TYPE_OBJECT:
			var effect_fields = ["visual_effect", "cast_visual_effect", "sinker_impact_visual_effect"]
			for field in effect_fields:
				var res = ability.get(field)
				if res:
					register_ability_visual_effect(res)

func preload_combat_cache() -> void:
	"""Preload all resources registered for this combat into memory to avoid hitches."""
	if _combat_cache.keys().size() == 0:
		pass
	else:
		for k in _combat_cache.keys():
			_preload_one(k)



func play_effect(effect_name: String, params: Dictionary = {}) -> int:
	# Returns a handle for stopping or tracking
	if not registry.has(effect_name):
		push_warning("play_effect: '%s' not registered" % effect_name)
		return -1

	# Check if visual effects are disabled in config for performance reasons
	if config_manager and not config_manager.animated_bg:
		return -1

	var spec = registry[effect_name]
	var typ = spec.get("type", "shader")
	if not _loaded.has(effect_name):
		_preload_one(effect_name)
	var handle = _next_handle
	_next_handle += 1
	_active[handle] = {"name": effect_name, "params": params}

	if typ == "shader":
		_play_shader_effect(effect_name, handle, params)
	else:
		_play_scene_effect(effect_name, handle, params)

	return handle

func stop_effect(handle: int) -> void:
	if not _active.has(handle):
		return
	var info = _active[handle]
	var the_name = info.name

	# If this is a shader effect with an active overlay, clean it up
	if _active_overlays.has(handle):
		_cleanup_shader_effect(handle, the_name)
	else:
		# For scene effects or other types
		_active.erase(handle)

func _play_shader_effect(effect_name: String, handle: int, params: Dictionary) -> void:
	"""Play a shader-based visual effect. VFX is non-critical - skip gracefully if any step fails."""
	# Get an available overlay for this effect
	var overlay = _get_available_overlay()
	if not overlay:
		# VFX limit reached - skip effect but don't crash
		_active.erase(handle)
		return

	# Track which overlay this effect is using
	_active_overlays[handle] = overlay.get_parent() as CanvasLayer

	var res = _loaded.get(effect_name, null)
	if not res:
		push_warning("Shader resource for '%s' not loaded - skipping VFX" % effect_name)
		_cleanup_shader_effect(handle, effect_name)
		return

	# Only proceed if we have a valid shader resource
	var mat: ShaderMaterial = null
	if res is Shader:
		mat = ShaderMaterial.new()
		mat.shader = res
	elif res is ShaderMaterial:
		mat = res.duplicate()
	else:
		# Invalid resource type - skip VFX
		push_warning("Invalid shader resource type for '%s' - skipping VFX" % effect_name)
		_cleanup_shader_effect(handle, effect_name)
		return

	# Setup overlay for shader effects
	if not overlay.texture:
		overlay.texture = _create_white_texture()

	overlay.visible = true
	overlay.modulate = Color(1, 1, 1, 1)
	overlay.material = mat

	# Apply shader parameters safely
	var duration = params.get("duration", 0.6)
	if not _apply_shader_parameters(mat, effect_name, params):
		push_warning("Failed to apply shader parameters for '%s' - skipping VFX" % effect_name)
		_cleanup_shader_effect(handle, effect_name)
		return

	# Create and start the animation tween
	var effect_tween = get_tree().create_tween()
	if not effect_tween:
		push_warning("Failed to create tween for VFX '%s' - skipping" % effect_name)
		_cleanup_shader_effect(handle, effect_name)
		return

	# Animate effect_progress if available
	if _material_has_parameter(mat, "effect_progress"):
		mat.set_shader_parameter("effect_progress", 0.0)
		effect_tween.tween_property(mat, "shader_parameter/effect_progress", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if _material_has_parameter(mat, "progress"):
		mat.set_shader_parameter("progress", 0.0)
		effect_tween.tween_property(mat, "shader_parameter/progress", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	effect_tween.finished.connect(func():
		_cleanup_shader_effect(handle, effect_name)
	)

func _cleanup_shader_effect(handle: int, _effect_name: String) -> void:
	"""Clean up a specific shader effect and return its overlay to the pool"""
	if not _active_overlays.has(handle):
		return

	var canvas_layer = _active_overlays[handle]
	_active_overlays.erase(handle)
	_active.erase(handle)

	# Clean up the overlay safely
	if canvas_layer and is_instance_valid(canvas_layer):
		var overlay = canvas_layer.get_child(0) as TextureRect
		if overlay and is_instance_valid(overlay):
			_return_overlay_to_pool(overlay)
		else:
			# CanvasLayer exists but overlay is invalid - clean up the layer
			var scene_root = canvas_layer.get_parent()
			if scene_root:
				scene_root.remove_child(canvas_layer)
			canvas_layer.queue_free()

func _play_scene_effect(effect_name: String, handle: int, params: Dictionary) -> void:
	var res = _loaded.get(effect_name, null)
	if not res:
		push_warning("Scene resource for '%s' not loaded" % effect_name)
		_active.erase(handle)
		return

	# Instance the scene (no pooling implemented)
	var node: Node = null
	if res is PackedScene:
		node = res.instantiate()
	else:
		push_warning("Registered scene %s is not a PackedScene" % effect_name)
		_active.erase(handle)
		return

	# Attach to a new CanvasLayer at a high layer so scene effects render above UI
	# Get the appropriate root node using utility function
	var target_root = _get_target_root()
	if not target_root:
		push_warning("Scene effect '%s' - no valid target root, skipping" % effect_name)
		_active.erase(handle)
		return
	var canvas_layer = CanvasLayer.new()
	var layer_index = BASE_LAYER + _vfx_overlays.size() + _active_overlays.size()
	# If a registered fullscreen_overlay exists and is itself on a CanvasLayer,
	# ensure scene effects appear above it
	if fullscreen_overlay and is_instance_valid(fullscreen_overlay):
		var parent = fullscreen_overlay.get_parent()
		if parent and parent is CanvasLayer:
			layer_index = max(layer_index, parent.layer + 1)
	canvas_layer.layer = layer_index
	# Add canvas layer to the chosen parent so coordinates align with Grid
	target_root.add_child(canvas_layer)
	canvas_layer.add_child(node)

	# If the node exposes a `start(params)` method, prepare params and call it.
	if node.has_method("start"):
		# Clone params so we don't mutate the caller's dictionary
		var start_params = params.duplicate(true)

		# If caller provided raw grid coordinates for nodes, project them to screen-space
		# so scene effects (which live on a CanvasLayer) get pixel node positions.
		if start_params.has("grid_cells"):
			var grid_cells = start_params["grid_cells"]
			if grid_cells and typeof(grid_cells) == TYPE_ARRAY:
				var vp_for_proj = canvas_layer.get_viewport() if canvas_layer and canvas_layer.get_viewport() else null
				var pixels = []
				for gp in grid_cells:
					if typeof(gp) == TYPE_VECTOR2:
						# grid_to_pixel returns world-space pixel; world_to_viewport_pixels projects to viewport pixels
						var world_px = GDM.grid.grid_to_pixel(gp.x, gp.y)
						var screen_px = GDM.grid.world_to_viewport_pixels(world_px, vp_for_proj)
						pixels.append(screen_px)
				start_params["nodes"] = pixels
			# Remove grid_cells to avoid confusion in scene code
			start_params.erase("grid_cells")

		node.start(start_params)
		if node.has_signal("finished"):
			node.finished.connect(func():
				# return to pool
				node.queue_free() # simple approach; pooling would reuse instead
				_active.erase(handle)
			)
		else:
			# If no finished signal, schedule removal after `duration` param
			var dur = params.get("duration", 0.8)
			var t = get_tree().create_timer(dur)
			t.timeout.connect(func():
				node.queue_free()
				_active.erase(handle)
			)
	else:
		# No start method: just auto-remove after duration
		var dur = params.get("duration", 0.8)
		var t = get_tree().create_timer(dur)
		t.timeout.connect(func():
			node.queue_free()
			_active.erase(handle)
		)

func get_vfx_status() -> Dictionary:
	"""Get current status of the multi-overlay VFX system"""
	return {
		"active_overlays": _active_overlays.size(),
		"available_overlays": _vfx_overlays.size(),
		"total_overlays": _vfx_overlays.size() + _active_overlays.size(),
		"max_overlays": MAX_OVERLAYS,
		"active_effects": _active.size(),
		"active_effect_names": _active.values().map(func(info): return info.name)
	}

func clear_all_effects() -> void:
	"""Emergency cleanup - stop all effects and reset all overlays"""

	# Stop all active shader effects and clean up their overlays
	for handle in _active_overlays.keys():
		var canvas_layer = _active_overlays[handle]
		if canvas_layer and is_instance_valid(canvas_layer):
			var scene_root = canvas_layer.get_parent()
			if scene_root:
				scene_root.remove_child(canvas_layer)
			canvas_layer.queue_free()
	_active_overlays.clear()

	# Clear any remaining active effects (scene effects, etc.)
	_active.clear()

	# Clean up pooled overlays
	for canvas_layer in _vfx_overlays:
		if canvas_layer and is_instance_valid(canvas_layer):
			var scene_root = canvas_layer.get_parent()
			if scene_root:
				scene_root.remove_child(canvas_layer)
			canvas_layer.queue_free()
	_vfx_overlays.clear()
