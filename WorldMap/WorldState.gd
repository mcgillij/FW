extends Resource

class_name FW_WorldState

@export var save := {}
@export var blacksmith_loot: Array[String] # Store Equipment resource paths only
@export var world_active_nodes: Dictionary = {}  # Key: world_id (e.g., "world1"), Value: Dictionary of node_id to bool
@export var current_seed: int = 0  # Game seed for RNG
@export var difficulty_thresholds: Dictionary = {  # Global thresholds for active nodes
	"base_active_nodes": 2,  # Set to 3 for testing
	"ascension_multiplier": 1.2,
	"max_active_nodes_per_world": 10
}
@export var unlocked_worlds: Dictionary = {}  # Key: world_id, Value: bool (unlocked or not)

# Initialize a new hash entry in the save dictionary if it doesn't exist
func init_hash(world_hash: int) -> void:
	if !save.has(world_hash):
		save[world_hash] = {
			"path_history": {},
			"current_level": 0,
			"completed": false,
			"data": null,  # Will be regenerated
			"level_gen_params": {},  # Store generation parameters
			"cleared_nodes": {},  # Store which nodes are cleared by level_hash
			"fog_cleared": {},   # Store which nodes have fog cleared by level_hash
			"node_monsters": {},  # Store monster data by level_hash
			"node_events": {},    # Store event data by level_hash
			"node_minigames": {},  # Store minigame data by level_hash
			"node_environments": {},  # Store environment data by level_hash
			"node_monster_abilities": {}, # Store monster ability resource paths by level_hash
			"player_progress": {},  # Store any other player progress
			"pvp_arena_data": {},  # Store PvP arena data by level_hash
			"pvp_cache_mapping": {}  # Map arena cache IDs to player data for persistence
		}

# Update the data node in the save structure
func update_data(world_hash: int, node: FW_LevelNode) -> void:
	init_hash(world_hash)
	save[world_hash]["data"] = node

# Store generation parameters for reproducible level generation
func update_level_gen_params(world_hash: int, params: Dictionary) -> void:
	init_hash(world_hash)
	save[world_hash]["level_gen_params"] = params

# Update the path history for a specific level
func update_path_history(world_hash: int, level: int, node: FW_LevelNode) -> void:
	init_hash(world_hash)
	save[world_hash]["path_history"][level] = node
	if OS.is_debug_build():
		FW_Debug.debug_log(["[WorldState] update_path_history world_hash=", world_hash, "level=", level, "entry_count=", save[world_hash]["path_history"].size()])

# Update the current level
func update_current_level(world_hash: int, level: int) -> void:
	init_hash(world_hash)
	save[world_hash]["current_level"] = level

# Update whether the level is completed
func update_completed(world_hash: int, completed: bool) -> void:
	init_hash(world_hash)
	save[world_hash]["completed"] = completed

# only ever increment ascension on world completion
# TODO: wire up end-game
func ascend(_world_hash: int, _completed: bool) -> void:
	# Increment ascension on completion (adjust logic if not per-world)
	UnlockManager.increment_ascension_level(GDM.player.character.name)
	# Trigger achievement for unlocking this world
	var achievement_name = "ascend"
	Achievements.unlock_achievement(achievement_name)
	GDM.safe_steam_set_achievement(achievement_name.capitalize())

# Mark a specific node as cleared
func update_node_cleared(world_hash: int, level_hash: int, cleared: bool) -> void:
	init_hash(world_hash)
	save[world_hash]["cleared_nodes"][level_hash] = cleared

# Mark fog as cleared for a specific node
func update_fog_cleared(world_hash: int, level_hash: int, cleared: bool) -> void:
	init_hash(world_hash)
	save[world_hash]["fog_cleared"][level_hash] = cleared

func update_fog(world_hash: int, fog: bool) -> void:
	init_hash(world_hash)
	var data_node = save[world_hash].get("data", null)
	if data_node:
		data_node.fog = fog

func get_current_level(world_hash: int) -> int:
	if save.has(world_hash):
		return save[world_hash].current_level
	return 0

func get_completed(world_hash: int) -> bool:
	if save.has(world_hash):
		return save[world_hash].completed
	return false

func get_path_history(world_hash: int) -> Dictionary:
	if save.has(world_hash):
		return save[world_hash].path_history
	return {}

func get_level_data(world_hash: int) -> FW_LevelNode:
	if save.has(world_hash):
		var data = save[world_hash].get("data", null)
		if data != null:
			return data
		# If data is null but we have generation parameters, the level needs to be regenerated
		# Return null to indicate regeneration is needed
		return null
	return null

func count_total_completed_levels() -> int:
	var total := 0
	for world_hash in save.keys():
		var path_history: Dictionary = save[world_hash].get("path_history", {})
		total += path_history.size()
	return total

# Get stored generation parameters for level regeneration
func get_level_gen_params(world_hash: int) -> Dictionary:
	if save.has(world_hash):
		return save[world_hash].get("level_gen_params", {})
	return {}

# Get cleared node states
func get_cleared_nodes(world_hash: int) -> Dictionary:
	if save.has(world_hash):
		return save[world_hash].get("cleared_nodes", {})
	return {}

# Get fog cleared states
func get_fog_cleared(world_hash: int) -> Dictionary:
	if save.has(world_hash):
		return save[world_hash].get("fog_cleared", {})
	return {}

# Check if a specific node is cleared
func is_node_cleared(world_hash: int, level_hash: int) -> bool:
	var cleared_nodes = get_cleared_nodes(world_hash)
	return cleared_nodes.get(level_hash, false)

# Check if fog is cleared for a specific node
func is_fog_cleared(world_hash: int, level_hash: int) -> bool:
	var fog_cleared = get_fog_cleared(world_hash)
	return fog_cleared.get(level_hash, false)

# Store node-specific data (monster, event, environments)
func store_node_data(world_hash: int, level_hash: int, monster_path: String, event_path: String, environment_paths: Array, monster_ability_paths: Array = []) -> void:
	init_hash(world_hash)
	if monster_path != "":
		save[world_hash]["node_monsters"][level_hash] = monster_path
	if event_path != "":
		save[world_hash]["node_events"][level_hash] = event_path
	# Minigames are stored through store_minigame_node()
	if environment_paths.size() > 0:
		save[world_hash]["node_environments"][level_hash] = environment_paths
	if monster_ability_paths.size() > 0:
		save[world_hash]["node_monster_abilities"][level_hash] = monster_ability_paths

# Store minigame data (scene path) for a specific node
func store_minigame_node(world_hash: int, level_hash: int, minigame_path: String) -> void:
	init_hash(world_hash)
	if minigame_path != "":
		save[world_hash]["node_minigames"][level_hash] = minigame_path

# Get stored monster for a specific node
func get_node_monster(world_hash: int, level_hash: int) -> String:
	if save.has(world_hash):
		return save[world_hash].get("node_monsters", {}).get(level_hash, "")
	return ""

# Get stored event for a specific node
func get_node_event(world_hash: int, level_hash: int) -> String:
	if save.has(world_hash):
		return save[world_hash].get("node_events", {}).get(level_hash, "")
	return ""

# Get stored minigame for a specific node
func get_node_minigame(world_hash: int, level_hash: int) -> String:
	if save.has(world_hash):
		return save[world_hash].get("node_minigames", {}).get(level_hash, "")
	return ""

# Get stored environments for a specific node
func get_node_environments(world_hash: int, level_hash: int) -> Array:
	if save.has(world_hash):
		return save[world_hash].get("node_environments", {}).get(level_hash, [])
	return []

# Get stored monster abilities for a specific node
func get_node_monster_abilities(world_hash: int, level_hash: int) -> Array:
	if save.has(world_hash):
		return save[world_hash].get("node_monster_abilities", {}).get(level_hash, [])
	return []

# PvP Arena Data Management
func store_pvp_arena_node(world_hash: int, level_hash: int, player_data_json: String, cache_id: String = "") -> void:
	"""Store PvP arena node data"""
	init_hash(world_hash)
	save[world_hash]["pvp_arena_data"][level_hash] = player_data_json
	if cache_id != "":
		save[world_hash]["pvp_cache_mapping"][level_hash] = cache_id

func get_pvp_arena_node(world_hash: int, level_hash: int) -> String:
	"""Get stored PvP arena node data"""
	if save.has(world_hash):
		return save[world_hash].get("pvp_arena_data", {}).get(level_hash, "")
	return ""

func get_pvp_cache_id(world_hash: int, level_hash: int) -> String:
	"""Get cache ID for PvP node"""
	if save.has(world_hash):
		return save[world_hash].get("pvp_cache_mapping", {}).get(level_hash, "")
	return ""

func is_arena_level(world_hash: int) -> bool:
	"""Check if this is a pure PvP arena level (100% PvP nodes)"""
	var params = get_level_gen_params(world_hash)
	return params.get("pvp_probability", 0.0) >= 1.0

# World Active Nodes Management
func init_world_active_nodes(world_id: String) -> void:
	if !world_active_nodes.has(world_id):
		world_active_nodes[world_id] = {}

func get_world_active_nodes(world_id: String) -> Dictionary:
	return world_active_nodes.get(world_id, {})

func set_world_active_node(world_id: String, node_id: String, active: bool) -> void:
	init_world_active_nodes(world_id)
	world_active_nodes[world_id][node_id] = active

func is_world_node_active(world_id: String, node_id: String) -> bool:
	var active_nodes = get_world_active_nodes(world_id)
	var val = active_nodes.get(node_id, 0)
	if val is bool:
		return val
	else:
		return val != 0

func get_world_completion_percentage(world_id: String) -> float:
	var active_nodes = get_world_active_nodes(world_id)
	if active_nodes.is_empty():
		return 0.0
	var completed = 0
	var total_active = 0
	for node_id in active_nodes.keys():
		var level_hash = active_nodes[node_id]
		if level_hash != 0:
			total_active += 1
			if get_completed(level_hash):
				completed += 1
	if total_active == 0:
		return 0.0
	return float(completed) / total_active

func regenerate_world_active_nodes(world_id: String, node_list: Array) -> void:
	init_world_active_nodes(world_id)
	var thresholds = difficulty_thresholds
	var base_count = thresholds.get("base_active_nodes", 5)
	var multiplier = thresholds.get("ascension_multiplier", 1.2)
	var max_count = thresholds.get("max_active_nodes_per_world", 10)
	# Fetch ascension level from (assumes GDM.player.character is set)
	var ascension_level = GDM.player.current_ascension_level
	var target_count = min(base_count + (ascension_level * multiplier), max_count, node_list.size())

	# Seed the global RNG for deterministic shuffle
	seed(current_seed)
	node_list.shuffle()
	var active_nodes = {}
	for i in range(target_count):
		var node = node_list[i]
		active_nodes[node.name] = node.loaded.world_hash
	for node in node_list:
		if not active_nodes.has(node.name):
			active_nodes[node.name] = 0  # Not active
	world_active_nodes[world_id] = active_nodes
	if OS.is_debug_build():
		FW_Debug.debug_log(["[WorldState] regenerated_active_nodes for ", world_id, ":", active_nodes])
func init_unlocked_worlds() -> void:
	if unlocked_worlds.is_empty():
		unlocked_worlds = {"world1": true}  # World1 always unlocked

func is_world_unlocked(world_id: String) -> bool:
	init_unlocked_worlds()
	return unlocked_worlds.get(world_id, false)

func unlock_world(world_id: String) -> void:
	init_unlocked_worlds()
	if FW_AscensionHelper.is_final_world(world_id):
		# Use call_deferred so the signal is emitted on the EventBus node in the next idle
		# This avoids losing the signal if a listener connects later in the same frame (e.g. in _ready)
		EventBus.call_deferred("emit_signal", "ascension_triggered", world_id)
		# Always increment ascension when the active run reaches its final world
		ascend(0, false)
	unlocked_worlds[world_id] = true

# Prize Wheel Management
func mark_prize_wheel_collected(wheel_hash: int) -> void:
	init_hash(wheel_hash)
	save[wheel_hash]["collected"] = true

func is_prize_wheel_collected(wheel_hash: int) -> bool:
	if save.has(wheel_hash):
		return save[wheel_hash].get("collected", false)
	return false
