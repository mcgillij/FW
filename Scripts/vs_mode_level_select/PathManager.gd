class_name FW_PathManager
extends RefCounted

# Manages path connectivity and validation for StS-style map navigation

static func get_available_paths(current_node: FW_LevelNode, all_nodes_by_depth: Dictionary, current_depth: int) -> Array:
	"""Returns array of nodes that are reachable from current position"""
	var available_nodes = []
	var next_depth = current_depth + 1

	# If no current node provided, return nodes at next depth
	if not current_node:
		return all_nodes_by_depth.get(next_depth, [])

	# Only children of current node are available
	for child in current_node.children:
		if child and child.level_depth == next_depth:
			available_nodes.append(child)

	return available_nodes

static func get_path_difficulty(node: FW_LevelNode) -> String:
	"""Determine path difficulty/type for coloring"""
	if node.node_type == FW_LevelNode.NodeType.STARTING:
		return "starting"
	elif node.node_type == FW_LevelNode.NodeType.MINIGAME:
		return "event"
	elif node.event:
		return "event"
	elif node.monster:
		match node.monster.type:
			FW_Monster_Resource.monster_type.BOSS:
				return "boss"
			FW_Monster_Resource.monster_type.ELITE:
				return "elite"
			FW_Monster_Resource.monster_type.GRUNT:
				return "normal"
			FW_Monster_Resource.monster_type.SCRUB:
				return "easy"

	return "normal"

static func get_path_color(difficulty: String) -> Color:
	"""Get color for path lines based on difficulty/type"""
	match difficulty:
		"starting":
			return Color.WHITE
		"easy":
			return Color.GREEN
		"normal":
			return Color.YELLOW
		"elite":
			return Color.RED
		"boss":
			return Color.PURPLE
		"event":
			return Color.CYAN
		_:
			return Color.WHITE
