class_name FW_ViewportManager
extends RefCounted

signal viewport_changed(start_depth: int, end_depth: int)

var _config: Resource
var _start_depth: int = 0
var _end_depth: int = 0
var _total_level_depth: int = 0
var _total_levels_count: int = 0

var _top_indicator: Label = null
var _bottom_indicator: Label = null

func _init(config: Resource):
	_config = config

func calculate_total_depth(root_node: FW_LevelNode) -> void:
	"""Calculate the maximum depth in the level tree"""
	# FW_LevelGenerator.get_max_depth() is treated as the maximum depth index (0-based).
	# Store both the max index and the explicit count of levels to avoid off-by-one
	# ambiguity when computing indicator counts.
	_total_level_depth = FW_LevelGenerator.get_max_depth(root_node)
	_total_levels_count = max(0, _total_level_depth + 1)

func calculate_viewport_range(current_level: int) -> void:
	"""Calculate the current viewport range based on player position"""
	var buffer_above = _config.VIEWPORT_BUFFER
	var viewport_size = _config.VIEWPORT_SIZE
	
	# Start viewport slightly above current level for context
	_start_depth = max(0, current_level - buffer_above)
	_end_depth = min(_total_level_depth, _start_depth + viewport_size - 1)
	
	# Adjust if we hit the bottom of the level tree
	if _end_depth >= _total_level_depth:
		_end_depth = _total_level_depth
		_start_depth = max(0, _end_depth - viewport_size + 1)
	
	viewport_changed.emit(_start_depth, _end_depth)

func is_depth_in_viewport(depth: int) -> bool:
	"""Check if a given depth is within the current viewport"""
	return depth >= _start_depth and depth <= _end_depth

func get_viewport_bounds() -> Dictionary:
	return {
		"start": _start_depth,
		"end": _end_depth,
		"total_depth": _total_level_depth,
		"total_levels": _total_levels_count
	}

func create_viewport_indicators(container: VBoxContainer, depth_map: Dictionary = {}) -> void:
	"""Create and add viewport indicators to show content above/below"""
	clear_indicators()

	# Compute counts. Prefer using the provided depth_map (if given) so we count
	# actual depth layers that contain nodes; otherwise fall back to index math
	# using the total levels value.
	var levels_above: int
	var levels_below: int
	if depth_map and depth_map.size() > 0:
		# Determine which depth layers are actually present in the filtered map.
		# We want to count only missing depth layers outside the viewport so that
		# an indicator is hidden if the nodes for that layer are already included
		# in the UI by the filtered depth map (e.g., for connected boundary nodes).
		var present_depths = {}
		for d in depth_map.keys():
			present_depths[int(d)] = true

		# Count missing depths above
		levels_above = 0
		for i in range(_start_depth):
			if not present_depths.has(i):
				levels_above += 1

		# Count missing depths below
		levels_below = 0
		for i in range(_end_depth + 1, _total_levels_count):
			if not present_depths.has(i):
				levels_below += 1
	else:
		levels_above = _start_depth
		levels_below = max(0, _total_levels_count - (_end_depth + 1))

	# No debug prints by default. The logic above computes levels_above/levels_below
	# based on the provided filtered depth map (preferred) or index math (fallback).

	# Top indicator (only if something is above the viewport)
	if levels_above > 0:
		_top_indicator = Label.new()
		_top_indicator.text = "▲ %d %s above ▲" % [levels_above, ("level" if levels_above == 1 else "levels")]
		_top_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_top_indicator.add_theme_color_override("font_color", Color.GRAY)
		container.add_child(_top_indicator)
		container.move_child(_top_indicator, 0)

	# Bottom indicator (only if something is below the viewport)
	if levels_below > 0:
		_bottom_indicator = Label.new()
		_bottom_indicator.text = "▼ %d %s below ▼" % [levels_below, ("level" if levels_below == 1 else "levels")]
		_bottom_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bottom_indicator.add_theme_color_override("font_color", Color.GRAY)
		container.add_child(_bottom_indicator)

func clear_indicators() -> void:
	"""Remove existing viewport indicators"""
	if _top_indicator:
		_top_indicator.queue_free()
		_top_indicator = null
	if _bottom_indicator:
		_bottom_indicator.queue_free()
		_bottom_indicator = null

func filter_depth_map_by_viewport(depth_map: Dictionary) -> Dictionary:
	"""Filter the depth map to only include levels within the viewport"""
	var filtered_map = {}
	
	# Include all depths within the viewport
	for depth in depth_map.keys():
		if is_depth_in_viewport(depth):
			filtered_map[depth] = depth_map[depth]
	
	# Include connected nodes at viewport boundaries for line continuity
	for depth in depth_map.keys():
		if not filtered_map.has(depth):
			var depth_nodes = depth_map[depth]
			for node in depth_nodes:
				if node and _has_connection_to_viewport(node):
					if not filtered_map.has(depth):
						filtered_map[depth] = []
					filtered_map[depth].append(node)
	
	return filtered_map

func _has_connection_to_viewport(node: FW_LevelNode) -> bool:
	"""Check if node has connections to viewport"""
	# Check children in viewport
	for child in node.children:
		if child and is_depth_in_viewport(child.level_depth):
			return true
	
	# Check parents in viewport
	for parent in node.parents:
		if parent and is_depth_in_viewport(parent.level_depth):
			return true
	
	return false
