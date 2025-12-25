extends RefCounted
class_name FW_LevelGenerator

var _map_hash: int
var _rng: RandomNumberGenerator
var _name_gen: FW_LevelNameGenerator
var _local_pvp_pool: Array = []
var _blacksmiths_created: int = 0
var _max_blacksmiths: int = 1

# Configuration
const MAX_BRANCHES := 5
const MIN_BRANCHES := 2
const CONVERGENCE_INTERVAL := 8  # Converge every 8 levels to control branching
const ELITE_FREQUENCY := 15      # Elite roughly every 15 levels
const EVENT_PROBABILITY := 0.20  # 20% chance for event nodes
const DEFAULT_PVP_PROBABILITY := 0.03  # 3% default chance for PvP nodes in regular maps
const BLACKSMITH_PROBABILITY := 0.05    # 5% chance for blacksmith nodes
const MINIGAME_PROBABILITY := 0.08  # 8% chance for minigame nodes

func _init(map_hash: int):
	_map_hash = map_hash
	_rng = RandomNumberGenerator.new()
	_rng.seed = map_hash
	_name_gen = FW_LevelNameGenerator.new()

func generate_level(level_gen_params: Dictionary) -> FW_LevelNode:
	var level_structure = _create_level_structure(level_gen_params["max_depth"])

	# Use the new PvPCache system to build our PvP pool
	_build_pvp_pool_from_simple_cache()

	# initialize blacksmith counters / limit (configurable via params)
	_blacksmiths_created = 0
	_max_blacksmiths = int(level_gen_params.get("max_blacksmiths", _max_blacksmiths))

	# Convert structure to actual LevelNode objects, passing params for monster logic
	var root_node = _build_node_tree_with_params(level_structure, level_gen_params)

	return root_node

func _build_pvp_pool_from_simple_cache() -> void:
	"""Build the PvP pool from cache"""
	var cache = FW_PvPCache.get_instance()
	_local_pvp_pool = []

	for i in range(cache._cached_opponents.size()):
		_local_pvp_pool.append({
			"cache_id": "simple_cache_" + str(i),
			"payload": cache._cached_opponents[i].duplicate(true)
		})

	# Shuffle the pool for randomness
	_local_pvp_pool.shuffle()


func _calculate_pvp_difficulty_for_depth(depth: int, max_depth: int) -> int:
	"""Calculate appropriate PvP opponent difficulty based on depth in regular maps"""
	var ascension_level = FW_AscensionHelper.get_ascension_level(GDM.player.character.name)
	var depth_ratio = float(depth) / float(max_depth)

	# Scale difficulty from 1-5 based on depth progression
	var base_difficulty = 1
	if depth_ratio < 0.2:
		base_difficulty = 1
	elif depth_ratio < 0.4:
		base_difficulty = 2
	elif depth_ratio < 0.6:
		base_difficulty = 3
	elif depth_ratio < 0.8:
		base_difficulty = 4
	else:
		base_difficulty = 5

	# Add ascension bonus only if ascension level > 0
	var ascension_bonus = 0
	if ascension_level > 0:
		ascension_bonus = min(ascension_level, 2)  # Max +2 difficulty levels

	return clamp(base_difficulty + ascension_bonus, 1, 5)

# New function: build node tree using params for monster type logic
func _build_node_tree_with_params(structure: Array, params: Dictionary) -> FW_LevelNode:
	var max_depth = params["max_depth"]
	var nodes_by_level = []

	# Calculate thresholds for monster types
	var scrub_levels = params.get("scrub_levels", 0)
	var grunt_levels = params.get("grunt_levels", 0)
	var elite_levels = params.get("elite_levels", 0)
	var boss_level = params.get("boss_level", null)
	var end_type = params.get("end_type", "")

	# Create all nodes first
	for depth in range(structure.size()):
		var level_nodes = []
		var node_count = structure[depth]

		for i in range(node_count):
			var node = _create_complete_node_with_params(
				depth, i, max_depth,
				scrub_levels, grunt_levels, elite_levels, boss_level, end_type
			)
			level_nodes.append(node)

		nodes_by_level.append(level_nodes)

	# Connect nodes between levels
	for depth in range(structure.size() - 1):
		var current_level = nodes_by_level[depth]
		var next_level = nodes_by_level[depth + 1]
		_connect_levels(current_level, next_level)

	return nodes_by_level[0][0]  # Return the root node

# New function: create node with monster type logic from params
func _create_complete_node_with_params(
		depth: int, index: int, max_depth: int,
		_scrub_levels: int, grunt_levels: int, elite_levels: int, boss_level, end_type: String
	) -> FW_LevelNode:
	var is_starting = (depth == 0)
	var is_final = (depth == max_depth)

	# Get PvP, event, and blacksmith probabilities from params
	var pvp_probability = GDM.current_info.level_to_generate.get("pvp_probability", DEFAULT_PVP_PROBABILITY)
	var event_probability = GDM.current_info.level_to_generate.get("event_probability", EVENT_PROBABILITY)
	var blacksmith_probability = GDM.current_info.level_to_generate.get("blacksmith_probability", BLACKSMITH_PROBABILITY)
	var minigame_probability = GDM.current_info.level_to_generate.get("minigame_probability", MINIGAME_PROBABILITY)

	var node_type: FW_LevelNode.NodeType
	if is_starting:
		node_type = FW_LevelNode.NodeType.STARTING
	elif is_final and end_type == "player":
		# Force final node to be a player for PvP arenas
		node_type = FW_LevelNode.NodeType.PLAYER
	elif not is_starting and _rng.randf() < pvp_probability and not is_final:
		node_type = FW_LevelNode.NodeType.PLAYER
	# Only create a blacksmith if we haven't reached the per-generation limit
	elif not is_starting and _rng.randf() < blacksmith_probability and not is_final and _blacksmiths_created < _max_blacksmiths:
		node_type = FW_LevelNode.NodeType.BLACKSMITH
	elif not is_starting and _rng.randf() < event_probability and not is_final:
		node_type = FW_LevelNode.NodeType.EVENT
	elif not is_starting and _rng.randf() < minigame_probability and not is_final:
		node_type = FW_LevelNode.NodeType.MINIGAME
	else:
		node_type = FW_LevelNode.NodeType.MONSTER

	# Generate names
	var names = _generate_node_names(depth, index, node_type, false, is_final)
	var node_name = names[0]
	var display_name = names[1]

	# Monster logic
	var monster: FW_Monster_Resource = null
	var player_data: FW_Combatant = null
	var cache_id: String = ""
	var minigame_path: String = ""

	if node_type == FW_LevelNode.NodeType.MONSTER:
		var monster_type: int
		if (boss_level != null and depth == boss_level) or (end_type == "boss" and is_final):
			monster_type = FW_Monster_Resource.monster_type.BOSS
		elif (elite_levels > 0 and depth > (max_depth - elite_levels)) or (end_type == "elite" and is_final):
			monster_type = FW_Monster_Resource.monster_type.ELITE
		elif (grunt_levels > 0 and depth > (max_depth - elite_levels - grunt_levels)):
			monster_type = FW_Monster_Resource.monster_type.GRUNT
		else:
			monster_type = FW_Monster_Resource.monster_type.SCRUB

		# Get monster subtype filter from level generation params
		var monster_subtype = GDM.current_info.level_to_generate.get("monster_subtype", null)
		monster = FW_RandomMonster.get_random_monster_static(monster_type, monster_subtype)

		# Initialize monster with abilities during level generation, not during combat
		if monster:
			# Delegate ascension modifications and setup to AscensionHelper
			FW_AscensionHelper.apply_to_monster(monster, GDM.player.character.name)
	if node_type == FW_LevelNode.NodeType.PLAYER:
		var chosen_cache_id: String = ""
		if _local_pvp_pool.size() > 0:
			# Pop one payload object off the end of the pool
			var entry = _local_pvp_pool.pop_back()
			if typeof(entry) == TYPE_DICTIONARY and entry.has("payload"):
				chosen_cache_id = entry.get("cache_id", "")
				var cached = entry.payload
				if not cached.is_empty():
					player_data = FW_PlayerSerializer.deserialize_player_data(cached)
		else:
			# Fall back to random local pick if pool empty or load failed
			player_data = FW_PvPCache.get_opponent()

		if player_data:
			# Adjust difficulty based on depth (similar to monster scaling)
			var difficulty_level = _calculate_pvp_difficulty_for_depth(depth, max_depth)
			player_data.difficulty_level = difficulty_level
			cache_id = chosen_cache_id if chosen_cache_id != "" else "mixed_pvp_%d_%d_%d" % [_map_hash, depth, index]

	# Environmental effects: allow both MONSTER and PLAYER nodes to sometimes have effects
	var env_effects: Array[FW_EnvironmentalEffect] = []
	if node_type == FW_LevelNode.NodeType.MONSTER or node_type == FW_LevelNode.NodeType.PLAYER:
		env_effects = _generate_environmental_effects()

	# Event
	var event: FW_EventResource = null
	if node_type == FW_LevelNode.NodeType.EVENT:
		event = FW_LevelEvents.generate_random_event(_rng)

	# Minigame
	if node_type == FW_LevelNode.NodeType.MINIGAME:
		minigame_path = FW_LevelMiniGames.generate_random_minigames(_rng)

	# Fog and skill check
	var has_fog = not is_starting
	var skill_check: FW_SkillCheckRes = null
	if has_fog:
		skill_check = _generate_skill_check(depth)

	var level_hash = _generate_level_hash(depth, index)
	var children_array: Array = []

	var new_node = FW_LevelNode.new(
		node_name,
		display_name,
		depth,
		node_type,
		env_effects,
		monster,
		children_array,
		false,  # cleared
		event,
		has_fog,
		skill_check,
		level_hash,
		minigame_path
	)

	# Set player data if this is a PvP node
	if node_type == FW_LevelNode.NodeType.PLAYER and player_data:
		new_node.set_player_data(player_data, cache_id)

	# If we created a blacksmith node, increment the counter so we don't exceed the max
	if node_type == FW_LevelNode.NodeType.BLACKSMITH:
		_blacksmiths_created += 1
	return new_node

func _create_level_structure(max_depth: int) -> Array:
	"""Create the level structure as arrays of node counts per level"""
	var structure = []

	# Level 0: Single start node
	structure.append(1)

	# Get ascension-influenced monster count multiplier
	var monster_count_multiplier = FW_AscensionHelper.get_monster_count_multiplier(GDM.player.character.name)

	var current_branches = 1

	for depth in range(1, max_depth + 1):
		var is_convergence_level = (depth % CONVERGENCE_INTERVAL == 0)
		var is_final_level = (depth == max_depth)
		var is_elite_level = (depth % ELITE_FREQUENCY == 0) and not is_final_level

		if is_final_level:
			# Final level: single boss node
			structure.append(1)
		elif is_convergence_level:
			# Convergence: reduce branches significantly
			current_branches = max(1, int(current_branches * 0.4))
			structure.append(current_branches)
		elif is_elite_level:
			# Elite level: moderate convergence
			current_branches = max(2, int(current_branches * 0.6))
			structure.append(current_branches)
		else:
			# Regular level: moderate branching with ascension scaling
			var branching_factor = _rng.randf_range(1.2, 1.8)
			current_branches = int(current_branches * branching_factor * monster_count_multiplier)
			current_branches = clamp(current_branches, MIN_BRANCHES, MAX_BRANCHES)
			structure.append(current_branches)
	return structure

func _generate_node_names(depth: int, index: int, node_type: FW_LevelNode.NodeType, is_elite: bool, is_final: bool) -> Array:
	"""Generate node name and display name"""
	# Create a unique seed based on depth, index, and map hash to ensure consistent naming
	var seed_value = abs(("%d_%d_%d" % [depth, index, _map_hash]).hash())

	# Create unique base name with depth and index to avoid collisions
	var unique_suffix = "%d_%d" % [depth, index]

	if node_type == FW_LevelNode.NodeType.STARTING:
		return ["Start_" + unique_suffix, "Start"]
	elif node_type == FW_LevelNode.NodeType.EVENT:
		var event_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 1, "event")
		return [event_names[0] + "_" + unique_suffix, event_names[1]]
	elif node_type == FW_LevelNode.NodeType.BLACKSMITH:
		var blacksmith_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 4, "blacksmith")
		return [blacksmith_names[0] + "_" + unique_suffix, blacksmith_names[1]]
	elif node_type == FW_LevelNode.NodeType.MINIGAME:
		var minigame_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 5, "event")
		return [minigame_names[0] + "_" + unique_suffix, minigame_names[1]]
	elif is_final:
		var boss_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 2, "special")
		return [boss_names[0] + "_" + unique_suffix, boss_names[1]]
	elif is_elite:
		var elite_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 3, "special")
		return [elite_names[0] + "_" + unique_suffix, elite_names[1]]
	else:
		var monster_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value, "monster")
		return [monster_names[0] + "_" + unique_suffix, monster_names[1]]

func _generate_monster_for_depth(depth: int, max_depth: int, is_elite: bool, is_final: bool) -> FW_Monster_Resource:
	"""Generate appropriate monster for the given depth"""
	var monster_type: int

	if is_final:
		monster_type = FW_Monster_Resource.monster_type.BOSS
	elif is_elite:
		monster_type = FW_Monster_Resource.monster_type.ELITE
	else:
		# Simple monster type logic based on depth
		var depth_ratio = float(depth) / float(max_depth)
		if depth_ratio < 0.3:
			monster_type = FW_Monster_Resource.monster_type.SCRUB
		elif depth_ratio < 0.7:
			monster_type = FW_Monster_Resource.monster_type.GRUNT
		else:
			monster_type = FW_Monster_Resource.monster_type.ELITE

	return FW_RandomMonster.get_random_monster_static(monster_type, GDM.current_info.level_to_generate.get("monster_subtype", null))

func _generate_environmental_effects() -> Array[FW_EnvironmentalEffect]:
	"""Generate random environmental effects"""
	# Base chance; let AscensionHelper adjust it
	var base_chance = 0.4
	var ascension_chance = FW_AscensionHelper.apply_environment_chance(base_chance, GDM.player.character.name)

	if _rng.randf() < ascension_chance:
		var count = 2 if _rng.randf() < 0.3 else 1
		var effects = _get_unique_environmental_effects(count)
		return effects

	# Return empty typed array
	var empty_effects: Array[FW_EnvironmentalEffect] = []
	return empty_effects

func _get_unique_environmental_effects(desired_count: int) -> Array[FW_EnvironmentalEffect]:
	var unique_effects: Array[FW_EnvironmentalEffect] = []
	if desired_count <= 0 or not GDM.env_manager:
		return unique_effects

	var seen_effects := {}  # Use effect objects as keys to ensure uniqueness
	var attempts = 0
	var max_attempts = max(6, desired_count * 4)

	while unique_effects.size() < desired_count and attempts < max_attempts:
		var candidates = GDM.env_manager.get_random_environments(desired_count)
		for effect in candidates:
			if not effect or seen_effects.has(effect):
				continue
			seen_effects[effect] = true
			unique_effects.append(effect)
			if unique_effects.size() == desired_count:
				break
		attempts += 1

	if unique_effects.size() < desired_count and GDM.env_manager.environments:
		var remaining_paths = GDM.env_manager.environments.duplicate()
		remaining_paths.shuffle()
		for path in remaining_paths:
			if unique_effects.size() == desired_count:
				break
			var fallback_effect = load(path)
			if not fallback_effect or seen_effects.has(fallback_effect):
				continue
			seen_effects[fallback_effect] = true
			unique_effects.append(fallback_effect)

	return unique_effects



func _generate_skill_check(depth: int) -> FW_SkillCheckRes:
	"""Generate skill check for fog removal"""
	var skill_names = ["Bark", "Reflex", "Alertness", "Vigor", "Enthusiasm"]
	var skill_colors = [FW_Colors.bark, FW_Colors.reflex, FW_Colors.alertness, FW_Colors.vigor, FW_Colors.enthusiasm]

	# Let AscensionHelper provide the difficulty multiplier
	var difficulty_multiplier = FW_AscensionHelper.get_skill_check_multiplier(GDM.player.character.name)

	# Skill difficulty scales with depth and ascension
	var difficulty: FW_SkillCheckRes.DIFF
	var target: int

	var adjusted_depth = int(depth * difficulty_multiplier)

	if adjusted_depth <= 3:
		difficulty = FW_SkillCheckRes.DIFF.SIMPLE
		target = _rng.randi_range(10, 20)
	elif adjusted_depth <= 6:
		difficulty = FW_SkillCheckRes.DIFF.EASY
		target = _rng.randi_range(20, 30)
	elif adjusted_depth <= 12:
		difficulty = FW_SkillCheckRes.DIFF.MEDIUM
		target = _rng.randi_range(30, 40)
	elif adjusted_depth <= 18:
		difficulty = FW_SkillCheckRes.DIFF.HARD
		target = _rng.randi_range(50, 60)
	else:
		difficulty = FW_SkillCheckRes.DIFF.EXTREME
		target = _rng.randi_range(70, 80)

	var skill_index = _rng.randi() % skill_names.size()
	return FW_SkillCheckRes.new(
		skill_names[skill_index],
		skill_colors[skill_index],
		target,
		difficulty
	)

func _generate_level_hash(depth: int, index: int) -> int:
	"""Generate unique hash for the level"""
	# Combine map hash, depth, and index to create unique level hash
	return hash(str(_map_hash) + "_" + str(depth) + "_" + str(index))

func _connect_levels(current_level: Array, next_level: Array) -> void:

	"""Connect all nodes in current level to nodes in next level, with intermittent extra parent connections"""
	var current_count = current_level.size()
	var next_count = next_level.size()

	# Standard connections (unchanged)
	if next_count == 1:
		var target_node = next_level[0]
		for parent in current_level:
			_link_nodes(parent, target_node)
	elif current_count <= next_count:
		for i in range(current_count):
			var parent = current_level[i]
			var base_children = int(float(next_count) / float(current_count))
			var extra_children = 1 if (i < (next_count % current_count)) else 0
			var total_children = base_children + extra_children
			var start_child = i * base_children + min(i, next_count % current_count)
			for j in range(total_children):
				var child_index = (start_child + j) % next_count
				_link_nodes(parent, next_level[child_index])
	else:
		for i in range(next_count):
			var child = next_level[i]
			var base_parents = int(float(current_count) / float(next_count))
			var extra_parents = 1 if (i < (current_count % next_count)) else 0
			var total_parents = base_parents + extra_parents
			var start_parent = i * base_parents + min(i, current_count % next_count)
			for j in range(total_parents):
				var parent_index = (start_parent + j) % current_count
				_link_nodes(current_level[parent_index], child)

	# Intermittent extra parent connections for variety
	const EXTRA_PARENT_PROBABILITY := 0.25  # 25% chance for extra parent
	const MAX_EXTRA_PARENTS := 2
	for child in next_level:
		if _rng.randf() < EXTRA_PARENT_PROBABILITY:
			# Pick up to MAX_EXTRA_PARENTS random parents not already connected
			var available_parents = []
			for parent in current_level:
				if not parent in child.parents:
					available_parents.append(parent)
			var num_extra = min(MAX_EXTRA_PARENTS, available_parents.size())
			for k in range(num_extra):
				if available_parents.size() == 0:
					break
				var idx = _rng.randi() % available_parents.size()
				var extra_parent = available_parents[idx]
				_link_nodes(extra_parent, child)
				available_parents.remove_at(idx)

func _link_nodes(parent: FW_LevelNode, child: FW_LevelNode) -> void:
	"""Link two nodes together"""
	if not parent or not child:
		return

	# Avoid duplicate connections
	if child in parent.children:
		return

	parent.children.append(child)
	# Add parent to child's parents array (properly typed)
	if not parent in child.parents:
		child.parents.append(parent)

# Static helper method for compatibility
static func collect_nodes_by_depth(root: FW_LevelNode) -> Dictionary:
	"""Collect nodes organized by depth - compatible with existing code"""
	if not root:
		return {}

	var nodes_by_depth = {}
	var visited = {}
	var queue = [{"node": root, "depth": 0}]

	while queue.size() > 0:
		var item = queue.pop_front()
		var node = item.node
		var depth = item.depth
		var node_id = node.get_instance_id()

		if visited.has(node_id):
			continue

		visited[node_id] = true

		if not nodes_by_depth.has(depth):
			nodes_by_depth[depth] = []
		nodes_by_depth[depth].append(node)

		for child in node.children:
			if child and not visited.has(child.get_instance_id()):
				queue.append({"node": child, "depth": depth + 1})

	return nodes_by_depth

static func get_max_depth(root_node: FW_LevelNode) -> int:
	"""Calculate the maximum depth in the level tree efficiently using iterative BFS"""
	if not root_node:
		return 0

	var max_depth = 0
	var queue = [root_node]
	var visited = {}

	while queue.size() > 0:
		var current_node = queue.pop_front()
		if not current_node or visited.has(current_node.get_instance_id()):
			continue
		visited[current_node.get_instance_id()] = true

		if current_node.has_method("get") and "level_depth" in current_node:
			var node_depth = current_node.level_depth
			if node_depth > max_depth:
				max_depth = node_depth

		for child in current_node.children:
			if child and not visited.has(child.get_instance_id()):
				queue.append(child)

	return max_depth
