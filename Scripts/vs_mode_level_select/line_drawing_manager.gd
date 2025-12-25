class_name FW_LineDrawingManager
extends RefCounted

var _config: FW_LevelMapConfig
var _parent_container: Control
var _ui_blocks_map: Dictionary
var _root_node: FW_LevelNode
var _mesh_renderer: FW_MeshLineRenderer
var _current_zoom_level: Vector2 = Vector2.ONE
var _last_stats: Dictionary = {}
var _block_center_cache: Dictionary = {}
var _zoom_scalar: float = 1.0


func _init(config: FW_LevelMapConfig, parent_container: Control):
	_config = config
	_parent_container = parent_container
	_mesh_renderer = FW_MeshLineRenderer.new(parent_container)

func set_root_node(root_node: FW_LevelNode) -> void:
	_root_node = root_node

func update_context(ui_blocks_map: Dictionary, _viewport_start: int, _viewport_end: int) -> void:
	_ui_blocks_map = ui_blocks_map
	# Invalidate per-draw block center cache when context changes
	_block_center_cache.clear()

func set_zoom_level(zoom_level: Vector2) -> void:
	_current_zoom_level = zoom_level
	_zoom_scalar = _compute_zoom_scalar(zoom_level)
	_mesh_renderer.set_zoom_level(zoom_level)


func draw_all_lines(root_node: FW_LevelNode, game_state: Dictionary) -> void:
	"""Draw all lines - simplified version"""
	if not root_node:
		return

	_root_node = root_node
	# Start of a fresh draw pass: clear renderer and center cache
	_mesh_renderer.clear_all_lines()
	_block_center_cache.clear()

	# Precompute edge sets to prevent double-drawing (which looks like thicker lines)
	var path_edges: Dictionary = _compute_path_edges(game_state)
	var choice_edges: Dictionary = _compute_choice_edges(root_node, game_state)
	var structure_skip_edges: Dictionary = {}
	for k in path_edges.keys():
		structure_skip_edges[k] = true
	for k in choice_edges.keys():
		structure_skip_edges[k] = true

	# Draw structure lines (parent -> child connections)
	_draw_structure_lines(root_node, {}, structure_skip_edges)

	# Draw path lines (completed path through the tree)
	_draw_path_lines(game_state)

	# Draw choice lines (available next moves)
	_draw_choice_lines(root_node, game_state, path_edges)

	_mesh_renderer.finalize_batches()

	# Collect stats
	#_last_stats = _mesh_renderer.get_line_counts()
	#FW_Debug.debug_log(["line_drawing counts ", _last_stats])

func _draw_structure_lines(node: FW_LevelNode, visited: Dictionary, skip_edges: Dictionary) -> void:
	"""Draw basic structure lines between parent and child nodes"""
	if not node or visited.has(node.get_instance_id()):
		return
	visited[node.get_instance_id()] = true

	# Only draw if this node has a UI block
	if not _ui_blocks_map.has(node.name):
		_draw_structure_lines_recursive(node, visited, skip_edges)  # Continue looking for valid nodes
		return

	var from_block = _ui_blocks_map[node.name]

	for child in node.children:
		if child and _ui_blocks_map.has(child.name):
			# Skip edges that will be drawn as path or choice lines to avoid thickness doubling
			var ekey = _edge_key(node, child)
			if skip_edges.has(ekey):
				# Continue recursion but do not draw this edge as structure
				_draw_structure_lines(child, visited, skip_edges)
				continue
			var to_block = _ui_blocks_map[child.name]
			var from_pos = _get_block_center(from_block)
			var to_pos = _get_block_center(to_block)

			if from_pos != Vector2.ZERO and to_pos != Vector2.ZERO:
				_mesh_renderer.add_structure_line(from_pos, to_pos, FW_LevelMapConfig.STRUCTURE_LINE_COLOR, FW_LevelMapConfig.STRUCTURE_LINE_WIDTH)

		# Continue recursion
		_draw_structure_lines(child, visited, skip_edges)

func _draw_structure_lines_recursive(node: FW_LevelNode, visited: Dictionary, skip_edges: Dictionary) -> void:
	"""Continue structure line recursion for nodes without UI blocks"""
	for child in node.children:
		_draw_structure_lines(child, visited, skip_edges)

func _draw_path_lines(game_state: Dictionary) -> void:
	"""Draw the completed path through the tree"""
	var path_history = game_state.get("path_history", {})
	var depths = path_history.keys()
	depths.sort()

	# Add depth 0 (root) if missing
	if not depths.has(0):
		depths.insert(0, 0)

	for i in range(depths.size() - 1):
		var from_node = null
		var to_node = null

		if depths[i] == 0:
			from_node = _root_node
		else:
			from_node = path_history.get(depths[i])

		to_node = path_history.get(depths[i + 1])

		if (from_node and to_node and
			_ui_blocks_map.has(from_node.name) and
			_ui_blocks_map.has(to_node.name)):

			var from_block = _ui_blocks_map[from_node.name]
			var to_block = _ui_blocks_map[to_node.name]
			var from_pos = _get_block_center(from_block)
			var to_pos = _get_block_center(to_block)

			if from_pos != Vector2.ZERO and to_pos != Vector2.ZERO:
				_mesh_renderer.add_path_line(from_pos, to_pos, FW_LevelMapConfig.PATH_LINE_COLOR, FW_LevelMapConfig.PATH_LINE_WIDTH)

func _draw_choice_lines(root_node: FW_LevelNode, game_state: Dictionary, path_edges: Dictionary) -> void:
	"""Draw available choice lines from current position"""
	var current_level = game_state.get("current_level", 0)
	var path_history = game_state.get("path_history", {})

	var current_node = null
	if current_level == 0:
		current_node = root_node
	else:
		current_node = path_history.get(current_level)

	if not current_node or not _ui_blocks_map.has(current_node.name):
		return

	var from_block = _ui_blocks_map[current_node.name]
	var from_pos = _get_block_center(from_block)

	if from_pos == Vector2.ZERO:
		return

	# Draw lines to available children (skip if edge already part of completed path)
	for child in current_node.children:
		if child and _ui_blocks_map.has(child.name):
			if path_edges.has(_edge_key(current_node, child)):
				continue
			var to_block = _ui_blocks_map[child.name]
			var to_pos = _get_block_center(to_block)

			if to_pos != Vector2.ZERO:
				_mesh_renderer.add_choice_line(from_pos, to_pos, Color(0.9, 0.9, 0.2, 0.75), FW_LevelMapConfig.CHOICE_LINE_WIDTH)

func _get_block_center(block: Control) -> Vector2:
	"""Get the center position of a UI block in the parent container's coordinate space - zoom aware"""
	if not block or not block.is_inside_tree() or not _parent_container:
		return Vector2.ZERO

	# Use block instance id as cache key to avoid name collisions
	var key = block.get_instance_id()
	if _block_center_cache.has(key):
		return _block_center_cache[key]

	# Compute center once per draw and cache it
	var block_rect = block.get_global_rect()
	var block_center = block_rect.get_center()
	# Convert to the parent container's local space to avoid manual zoom compensation
	var local_pos = _parent_container.get_global_transform_with_canvas().affine_inverse() * block_center
	_block_center_cache[key] = local_pos
	return local_pos

func _compute_zoom_scalar(zoom: Vector2) -> float:
	# Use a uniform scalar to avoid angle-dependent thickness under non-uniform scaling
	var zx := absf(zoom.x)
	var zy := absf(zoom.y)
	if zx == 0.0 and zy == 0.0:
		return 1.0
	# Average maintains a perceptual uniform zoom; prevents anisotropic width distortion
	return max(0.0001, (zx + zy) * 0.5)

func _edge_key(from_node: FW_LevelNode, to_node: FW_LevelNode) -> String:
	# Use instance IDs to avoid name collisions and keep directionality
	return "%s>%s" % [str(from_node.get_instance_id()), str(to_node.get_instance_id())]

func _compute_path_edges(game_state: Dictionary) -> Dictionary:
	var edges: Dictionary = {}
	var path_history = game_state.get("path_history", {})
	var depths = path_history.keys()
	depths.sort()
	if not depths.has(0):
		depths.insert(0, 0)
	for i in range(depths.size() - 1):
		var from_node = null
		var to_node = null
		if depths[i] == 0:
			from_node = _root_node
		else:
			from_node = path_history.get(depths[i])
		to_node = path_history.get(depths[i + 1])
		if from_node and to_node:
			edges[_edge_key(from_node, to_node)] = true
	return edges

func _compute_choice_edges(root_node: FW_LevelNode, game_state: Dictionary) -> Dictionary:
	var edges: Dictionary = {}
	var current_level = game_state.get("current_level", 0)
	var path_history = game_state.get("path_history", {})
	var current_node = null
	if current_level == 0:
		current_node = root_node
	else:
		current_node = path_history.get(current_level)
	if not current_node:
		return edges
	for child in current_node.children:
		if child:
			edges[_edge_key(current_node, child)] = true
	return edges

func clear_all_lines() -> void:
	_mesh_renderer.clear_all_lines()
	_last_stats = {}

func get_render_stats() -> Dictionary:
	return _last_stats

# Debug helper
func debug_coordinate_system() -> Dictionary:
	return {
		"total_blocks": _ui_blocks_map.size(),
		"blocks_valid": not _ui_blocks_map.is_empty()
	}
