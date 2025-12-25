class_name FW_UIBlockManager
extends RefCounted

# Signals
signal block_state_updated(block_name: String, is_reachable: bool, is_completed: bool)

var _config: FW_LevelMapConfig
var _block_scene: PackedScene
var _ui_blocks_map: Dictionary = {}
var _container: VBoxContainer
var _root_node: FW_LevelNode  # Reference to root node for node lookup

func _init(config: FW_LevelMapConfig, block_scene: PackedScene, container: VBoxContainer):
	_config = config
	_block_scene = block_scene
	_container = container

func set_root_node(root_node: FW_LevelNode) -> void:
	"""Set the root node reference for node lookups"""
	_root_node = root_node

func create_blocks_from_depth_map(depth_map: Dictionary, game_state: Dictionary) -> Dictionary:
	"""Create UI blocks from depth map and return the blocks map"""
	_ui_blocks_map.clear()

	var sorted_depth_keys = depth_map.keys()
	sorted_depth_keys.sort()

	for depth_key in sorted_depth_keys:
		var hbox_for_depth = _create_hbox_for_depth(depth_key)
		_container.add_child(hbox_for_depth)

		for node_data in depth_map[depth_key]:
			if not node_data:
				continue

			var ui_block = _create_ui_block_for_node(node_data)
			hbox_for_depth.add_child(ui_block)
			ui_block.setup(node_data)

			_apply_block_states(node_data, ui_block, depth_key, game_state)
			_ui_blocks_map[node_data.name] = ui_block

			_apply_current_position_highlight(node_data, ui_block, game_state)

	return _ui_blocks_map

func update_block_states(game_state: Dictionary, nodes_by_depth: Dictionary = {}) -> void:
	"""Update all block states efficiently"""
	var current_level = game_state.current_level

	# Always perform batched updates for a consistent optimized baseline
	_update_all_blocks(game_state, current_level, nodes_by_depth)

func _update_all_blocks(game_state: Dictionary, _current_level: int, _nodes_by_depth: Dictionary) -> void:
	"""Update all blocks efficiently"""
	for block_name in _ui_blocks_map.keys():
		var ui_block = _ui_blocks_map[block_name]

		if not _is_valid_block(ui_block):
			continue

		var node = _get_cached_node(block_name, {})
		if not node:
			continue

		_update_single_block_state(ui_block, node, game_state)

func clear_blocks() -> void:
	"""Clear all UI blocks and containers"""
	for child in _container.get_children():
		child.queue_free()
	_ui_blocks_map.clear()

func get_blocks_map() -> Dictionary:
	"""Get the current blocks map"""
	return _ui_blocks_map

func get_block_by_name(block_name: String) -> Control:
	"""Get a specific block by name"""
	return _ui_blocks_map.get(block_name, null)

func has_block(block_name: String) -> bool:
	"""Check if a block exists"""
	return _ui_blocks_map.has(block_name)

# --- Private Methods ---

func _create_hbox_for_depth(_depth: int) -> HBoxContainer:
	"""Create horizontal container for a depth level"""
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.set("theme_override_constants/separation", _config.H_SPACER)
	return hbox

func _create_ui_block_for_node(_node_data: FW_LevelNode) -> Control:
	"""Create a UI block for a level node"""
	if not _block_scene:
		push_error("UIBlockManager: No block scene provided")
		return Control.new()

	var ui_block: Control = _block_scene.instantiate()
	return ui_block

func _apply_block_states(node_data: FW_LevelNode, ui_block: Control, depth: int, game_state: Dictionary) -> void:
	"""Apply visual states to a UI block"""
	var current_level = game_state.current_level
	var path_history = game_state.path_history

	var is_completed = _is_node_completed(node_data, depth, path_history)
	var is_reachable = _calculate_node_reachability(node_data, current_level, path_history)

	_apply_visual_modulation(ui_block, is_reachable, current_level)

	if ui_block.has_method("set_path_state"):
		ui_block.set_path_state(is_reachable, is_completed)

	block_state_updated.emit(node_data.name, is_reachable, is_completed)

func _apply_current_position_highlight(node_data: FW_LevelNode, ui_block: Control, game_state: Dictionary) -> void:
	"""Apply current position highlighting to UI block"""
	if not ui_block.has_method("set_current_tile"):
		return

	var current_node = _get_current_position_node(game_state)
	var is_current = current_node and node_data.name == current_node.name
	ui_block.set_current_tile(is_current)

func _is_valid_block(ui_block: Control) -> bool:
	"""Check if UI block is valid and has required methods"""
	return ui_block and ui_block.has_method("set_path_state")

func _get_cached_node(block_name: String, cache: Dictionary) -> FW_LevelNode:
	"""Get a node from cache or find and cache it"""
	if cache.has(block_name):
		return cache[block_name]

	var node = _find_node_by_name(_root_node, block_name) if _root_node else null
	cache[block_name] = node
	return node

func _update_single_block_state(ui_block: Control, node: FW_LevelNode, game_state: Dictionary) -> void:
	"""Update the state of a single UI block"""
	var current_level = game_state.current_level
	var path_history = game_state.path_history

	var is_completed = _is_node_completed(node, node.level_depth, path_history)
	var is_reachable = _calculate_node_reachability(node, current_level, path_history)

	var current_position_node = _get_current_position_node(game_state)
	var is_current_position = current_position_node and node.name == current_position_node.name

	if ui_block.has_method("set_current_tile"):
		ui_block.set_current_tile(is_current_position)

	if ui_block.has_method("set_path_state"):
		ui_block.set_path_state(is_reachable, is_completed)

	_apply_visual_modulation(ui_block, is_reachable, current_level)

	block_state_updated.emit(node.name, is_reachable, is_completed)

func _apply_visual_modulation(ui_block: Control, is_reachable: bool, current_level: int = 0) -> void:
	"""Apply visual modulation to indicate reachability"""
	# Special case: Highlight the starting node (depth 0) only while player hasn't moved off it
	var should_highlight_starting = false
	if ui_block.has_method("get") and "level_node" in ui_block and ui_block.level_node:
		var is_starting_node = ui_block.level_node.level_depth == 0
		# Only highlight starting node if player is still at level 0 (hasn't moved off it yet)
		should_highlight_starting = is_starting_node and current_level == 0

	var color = Color.WHITE if (is_reachable or should_highlight_starting) else _config.DIMMED_NODE_COLOR

	if ui_block.has_method("get") and "active_panel" in ui_block and ui_block.active_panel:
		ui_block.active_panel.modulate = color
	else:
		ui_block.modulate = color

	if ui_block.has_method("get") and "node_type_image" in ui_block and ui_block.node_type_image:
		ui_block.node_type_image.modulate = color

func _is_node_completed(node: FW_LevelNode, depth: int, path_history: Dictionary) -> bool:
	"""Check if a node is completed"""
	if not path_history.has(depth):
		return false

	var completed_node = path_history[depth]
	return completed_node and completed_node.name == node.name

func _calculate_node_reachability(node: FW_LevelNode, current_level: int, path_history: Dictionary) -> bool:
	"""Calculate node reachability using PathManager logic"""
	if not node:
		return false

	var depth = node.level_depth
	var current_position_node = _get_current_position_node({"current_level": current_level, "path_history": path_history})
	
	if not current_position_node:
		return false
	
	var actual_current_depth = current_position_node.level_depth

	if depth == 0:
		# Start node - reachable until next node is completed
		return not path_history.has(1)
	elif depth < actual_current_depth:
		# Past levels - not reachable
		return false
	elif depth == actual_current_depth:
		# Current level - check if any node at this depth is completed
		return not path_history.has(depth)
	elif depth == actual_current_depth + 1:
		# Next level - use PathManager to get available nodes
		var nodes_by_depth = _get_all_nodes_by_depth()
		var available_nodes = FW_PathManager.get_available_paths(current_position_node, nodes_by_depth, actual_current_depth)
		var is_available = _is_node_in_available_list(node, available_nodes)
		return is_available
	else:
		# Future levels - not reachable
		return false

func _get_current_position_node(game_state: Dictionary) -> FW_LevelNode:
	"""Get the current position node from game state"""
	var current_level = game_state.current_level
	var path_history = game_state.path_history

	var current_node = null
	if current_level == 0:
		current_node = _root_node
	elif path_history.has(current_level):
		current_node = path_history[current_level]
	
	# Handle edge case: current_level incremented but no node completed at that level yet
	# (e.g., after event completion)
	if not current_node and current_level > 0:
		current_node = _get_path_history_node(current_level - 1, path_history)
	
	return current_node

func _get_path_history_node(level: int, path_history: Dictionary) -> FW_LevelNode:
	"""Get node from path history at specified level"""
	if level == 0:
		return _root_node
	elif path_history.has(level):
		return path_history[level]
	return null

func _get_all_nodes_by_depth() -> Dictionary:
	"""Get all nodes by depth from the root node"""
	if _root_node:
		return FW_LevelGenerator.collect_nodes_by_depth(_root_node)
	else:
		return {}

func _is_node_in_available_list(target_node: FW_LevelNode, available_nodes: Array) -> bool:
	"""Check if target_node is in available_nodes by comparing level_hash"""
	if not target_node:
		return false
	for available_node in available_nodes:
		if available_node and available_node.level_hash == target_node.level_hash:
			return true
	return false

# --- Helper Functions ---
static func _find_node_by_name(root: FW_LevelNode, target_name: String) -> FW_LevelNode:
	"""Find a node by name in the tree"""
	if not root:
		return null
	if root.name == target_name:
		return root
	for child in root.children:
		var found = _find_node_by_name(child, target_name)
		if found:
			return found
	return null
