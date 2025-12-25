class_name FW_MeshLineRenderer
extends RefCounted

## Optimized line renderer using MeshInstance2D for better performance across all platforms
## Batches lines into meshes to reduce draw calls and CPU overhead

# Preloaded shaders for performance
static var _shader_cache: Dictionary = {}
static var _material_cache: Dictionary = {}

# Mesh batching
var _structure_mesh: MeshInstance2D
var _choice_mesh: MeshInstance2D
var _path_mesh: MeshInstance2D
var _parent_container: Control

# Geometry data
var _structure_vertices: PackedVector2Array = []
var _structure_colors: PackedColorArray = []
var _structure_indices: PackedInt32Array = []

var _choice_vertices: PackedVector2Array = []
var _choice_colors: PackedColorArray = []
var _choice_indices: PackedInt32Array = []

var _path_vertices: PackedVector2Array = []
var _path_colors: PackedColorArray = []
var _path_indices: PackedInt32Array = []

# Performance settings (always-on optimized behavior)
var _current_zoom: Vector2 = Vector2.ONE
var _zoom_scalar: float = 1.0
const _MAX_DISTANCE_FOR_DETAIL: float = 1000.0

# Static initialization
static func _static_init():
	_preload_shaders()

static func _preload_shaders():
	"""Preload all shaders to avoid runtime loading"""
	if _shader_cache.is_empty():
		var shaders_to_load = {
			"line_smoke": "res://Shaders/line_smoke.gdshader",
			"sparkle": "res://Shaders/sparkle.gdshader"
		}

		for shader_name in shaders_to_load:
			var shader_path = shaders_to_load[shader_name]
			var shader = load(shader_path)
			if shader:
				_shader_cache[shader_name] = shader

static func get_cached_material(shader_name: String, base_color: Color = Color.WHITE) -> ShaderMaterial:
	"""Get cached shader material or create new one"""
	var cache_key = "%s_%s" % [shader_name, base_color.to_html()]

	if _material_cache.has(cache_key):
		return _material_cache[cache_key]

	if not _shader_cache.has(shader_name):
		return null

	var material = ShaderMaterial.new()
	material.shader = _shader_cache[shader_name]

	# Set default parameters based on shader type
	match shader_name:
		"line_smoke":
			material.set_shader_parameter("base_color", base_color)
			material.set_shader_parameter("pulse_color", Color(1.0, 1.0, 1.0, 0.8))
			material.set_shader_parameter("time_speed", 0.5)
			material.set_shader_parameter("pulse_freq", 1.2)
			material.set_shader_parameter("streak_speed", 1.2)
			material.set_shader_parameter("glow_intensity", 0.3)
		"sparkle":
			material.set_shader_parameter("glow_color", base_color)
			material.set_shader_parameter("speed", 1.0)
			material.set_shader_parameter("glow_width", 0.05)
			material.set_shader_parameter("sparkle_strength", 0.5)
			material.set_shader_parameter("sparkle_density", 10.0)

	_material_cache[cache_key] = material
	return material

func _init(parent_container: Control):
	_parent_container = parent_container
	_static_init()
	_initialize_mesh_instances()

func _initialize_mesh_instances():
	"""Initialize MeshInstance2D nodes for different line types"""
	# Structure lines mesh (map connections) - add first so it renders behind others
	_structure_mesh = MeshInstance2D.new()
	# Use a simple, non-animated material for structure lines to reduce GPU cost
	var struct_mat := CanvasItemMaterial.new()
	_structure_mesh.material = struct_mat
	_structure_mesh.z_index = 0  # Same as legacy structure lines
	_parent_container.add_child(_structure_mesh)
	# Move to beginning of child list to render behind everything
	_parent_container.move_child(_structure_mesh, 0)

	# Choice lines mesh (available paths) - add after structure
	_choice_mesh = MeshInstance2D.new()
	# Choice lines keep the animated shader so active choices have visual effects
	_choice_mesh.material = get_cached_material("sparkle", Color(0.9, 0.9, 0.2, 0.75))
	_choice_mesh.z_index = 0  # Same as legacy choice lines
	_parent_container.add_child(_choice_mesh)
	# Move to after structure mesh
	_parent_container.move_child(_choice_mesh, 1)

	# Path lines mesh (completed path) - add after choice
	_path_mesh = MeshInstance2D.new()
	# Use a simple, non-animated material for completed path lines (performance)
	var path_mat := CanvasItemMaterial.new()
	_path_mesh.material = path_mat
	_path_mesh.z_index = 0  # Same as legacy path line
	_parent_container.add_child(_path_mesh)
	# Move to after choice mesh
	_parent_container.move_child(_path_mesh, 2)

# No low-power gating; we aim for good default performance across devices

func set_zoom_level(zoom: Vector2):
	"""Update zoom level and adjust line widths accordingly"""
	_current_zoom = zoom
	# Compute a uniform scalar so width scales consistently under non-uniform zoom
	_zoom_scalar = _compute_zoom_scalar(zoom)

	# Update material parameters for zoom-responsive effects
	if _structure_mesh and _structure_mesh.material and _structure_mesh.material is ShaderMaterial:
		_structure_mesh.material.set_shader_parameter("zoom_level", _zoom_scalar)
	if _choice_mesh and _choice_mesh.material and _choice_mesh.material is ShaderMaterial:
		_choice_mesh.material.set_shader_parameter("zoom_level", _zoom_scalar)
	if _path_mesh and _path_mesh.material and _path_mesh.material is ShaderMaterial:
		_path_mesh.material.set_shader_parameter("zoom_level", _zoom_scalar)

	# Note: Zoom adjustments will be applied when building meshes

func set_lod_settings(_enabled: bool, _max_distance: float = 1000.0):
	"""Deprecated: LOD is always enabled with sane defaults."""
	pass

func clear_all_lines():
	"""Clear all line meshes"""
	_clear_structure_lines()
	_clear_choice_lines()
	_clear_path_lines()

func _clear_structure_lines():
	_structure_vertices.clear()
	_structure_colors.clear()
	_structure_indices.clear()
	_structure_mesh.mesh = null

func _clear_choice_lines():
	_choice_vertices.clear()
	_choice_colors.clear()
	_choice_indices.clear()
	_choice_mesh.mesh = null

func _clear_path_lines():
	_path_vertices.clear()
	_path_colors.clear()
	_path_indices.clear()
	_path_mesh.mesh = null

func add_structure_line(from_pos: Vector2, to_pos: Vector2, color: Color = Color(0.4, 0.4, 0.6, 0.7), width: float = 2.0):
	"""Add a structure line to the batch - SIMPLIFIED: no zoom scaling on coordinates"""
	# Only scale the line width, not the coordinates (they're already in correct space)
	var zoom_width = width * _zoom_scalar
	_add_line_to_batch(_structure_mesh, _structure_vertices, _structure_colors, _structure_indices, from_pos, to_pos, color, zoom_width)

func add_choice_line(from_pos: Vector2, to_pos: Vector2, color: Color = Color(0.9, 0.9, 0.2, 0.75), width: float = 4.0):
	"""Add a choice line to the batch - SIMPLIFIED: no zoom scaling on coordinates"""
	# Only scale the line width, not the coordinates (they're already in correct space)
	var zoom_width = width * _zoom_scalar
	_add_line_to_batch(_choice_mesh, _choice_vertices, _choice_colors, _choice_indices, from_pos, to_pos, color, zoom_width)

func add_path_line(from_pos: Vector2, to_pos: Vector2, color: Color = Color(1.0, 0.6, 0.2, 0.9), width: float = 6.0):
	"""Add a path line to the batch - SIMPLIFIED: no zoom scaling on coordinates"""
	# Only scale the line width, not the coordinates (they're already in correct space)
	var zoom_width = width * _zoom_scalar
	_add_line_to_batch(_path_mesh, _path_vertices, _path_colors, _path_indices, from_pos, to_pos, color, zoom_width)

func _add_line_to_batch(mesh_instance: MeshInstance2D, vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array,
						from_pos: Vector2, to_pos: Vector2, color: Color, width: float):
	"""Add a line as a quad to the specified batch - OPTIMIZED for Steam Deck"""

	# Skip very short lines for performance (increased threshold)
	var line_length = from_pos.distance_to(to_pos)
	if line_length < 2.0:  # Increased from 1.0
		return

	# LOD disabled for consistent thickness: do not modify width or alpha based on length

	# Skip lines that are too thin to be visible
	if width < 1.0:
		return

	# Work in global space to keep thickness angle-independent under anisotropic parent scale
	var parent_xform: Transform2D = _parent_container.get_global_transform_with_canvas()
	var g_from: Vector2 = parent_xform * from_pos
	var g_to: Vector2 = parent_xform * to_pos

	var seg := g_to - g_from
	var seg_len := seg.length()
	if seg_len <= 0.0001:
		return
	# Normalize using Euclidean length to avoid angle-based width variation
	var direction = seg / seg_len
	var perpendicular = Vector2(-direction.y, direction.x) * (width * 0.5)

	# Build quad vertices in global space
	var g_v0 = g_from + perpendicular
	var g_v1 = g_from - perpendicular
	var g_v2 = g_to - perpendicular
	var g_v3 = g_to + perpendicular

	# Convert back to the mesh's local space
	var inv_mesh: Transform2D = mesh_instance.get_global_transform_with_canvas().affine_inverse()
	var v0 = inv_mesh * g_v0
	var v1 = inv_mesh * g_v1
	var v2 = inv_mesh * g_v2
	var v3 = inv_mesh * g_v3

	var base_index = vertices.size()

	# Create quad vertices (two triangles) - SIMPLIFIED geometry
	vertices.append(v0)
	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)

	# Add colors for each vertex
	colors.append(color)
	colors.append(color)
	colors.append(color)
	colors.append(color)

	# Add triangle indices (2 triangles = 6 indices)
	indices.append(base_index + 0)
	indices.append(base_index + 1)
	indices.append(base_index + 2)

	indices.append(base_index + 0)
	indices.append(base_index + 2)
	indices.append(base_index + 3)

func _compute_zoom_scalar(zoom: Vector2) -> float:
	var zx := absf(zoom.x)
	var zy := absf(zoom.y)
	if zx == 0.0 and zy == 0.0:
		return 1.0
	return max(0.0001, (zx + zy) * 0.5)

func finalize_batches():
	"""Build final meshes from batched data"""
	_build_mesh(_structure_mesh, _structure_vertices, _structure_colors, _structure_indices)
	_build_mesh(_choice_mesh, _choice_vertices, _choice_colors, _choice_indices)
	_build_mesh(_path_mesh, _path_vertices, _path_colors, _path_indices)

func _build_mesh(mesh_instance: MeshInstance2D, vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array):
	"""Build a mesh from vertex data"""
	if vertices.is_empty():
		mesh_instance.mesh = null
		return

	var array_mesh = ArrayMesh.new()
	var mesh_arrays = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)

	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	mesh_arrays[Mesh.ARRAY_INDEX] = indices

	# Generate UVs for shader effects
	var uvs = PackedVector2Array()
	uvs.resize(vertices.size())
	for i in range(vertices.size()):
		# Create UV coordinates that work well with line shaders
		var u = float(i % 4) / 3.0  # 0 to 1 across quad
		var v = float(i) / 4.0 / float(vertices.size()) * 4.0  # 0 to 1 along line
		uvs[i] = Vector2(u, v)

	mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs

	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
	mesh_instance.mesh = array_mesh

func get_line_counts() -> Dictionary:
	"""Get statistics about rendered lines"""
	# Using integer division intentionally - we want whole counts
	@warning_ignore("integer_division")
	return {
		"structure_lines": _structure_vertices.size() / 4,
		"choice_lines": _choice_vertices.size() / 4,
		"path_segments": _path_vertices.size() / 4,
		"total_vertices": _structure_vertices.size() + _choice_vertices.size() + _path_vertices.size(),
		"total_triangles": (_structure_indices.size() + _choice_indices.size() + _path_indices.size()) / 3
	}

func cleanup():
	"""Clean up resources"""
	if _structure_mesh:
		_structure_mesh.queue_free()
	if _choice_mesh:
		_choice_mesh.queue_free()
	if _path_mesh:
		_path_mesh.queue_free()
