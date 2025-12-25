class_name FW_StateSynchronizer
extends RefCounted

# Signals for coordinating state changes
signal state_updated(current_level: int, path_history: Dictionary)
signal ui_refresh_needed()

var _world_hash: int

func _init(world_hash: int):
	_world_hash = world_hash

func get_current_game_state() -> Dictionary:
	"""Get the current game state in a structured format"""
	return {
		"current_level": GDM.world_state.get_current_level(_world_hash),
		"path_history": GDM.world_state.get_path_history(_world_hash),
		"world_hash": _world_hash
	}

func sync_ui_with_game_state() -> Dictionary:
	"""Synchronize UI state with current game state and return the state"""
	var state = get_current_game_state()
	state_updated.emit(state.current_level, state.path_history)
	return state

func handle_level_completion() -> Dictionary:
	"""Handle level completion and return updated state"""
	# Wait for state to be updated by the completion process
	await EventBus.level_completed
	
	# Give time for state updates to propagate
	await Engine.get_main_loop().process_frame
	
	var new_state = get_current_game_state()
	state_updated.emit(new_state.current_level, new_state.path_history)
	ui_refresh_needed.emit()
	
	return new_state

func get_current_position_node(current_level: int, path_history: Dictionary, root_node: FW_LevelNode) -> FW_LevelNode:
	"""Get the current position node, handling edge cases for event completions"""
	var current_node = _find_node_at_level(current_level, path_history, root_node)
	
	# For event completions, current_level might be incremented already
	if not current_node and current_level > 0:
		current_node = _find_node_at_level(current_level - 1, path_history, root_node)
	
	return current_node

func _find_node_at_level(level: int, path_history: Dictionary, root_node: FW_LevelNode) -> FW_LevelNode:
	"""Find the node at a specific level in path history"""
	if level == 0:
		return root_node
	elif path_history.has(level):
		return path_history[level]
	else:
		return null
