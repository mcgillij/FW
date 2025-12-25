extends Node

@onready var player: FW_Player #  = player_script.new() #{}, [null, null, null, null, null], 300, 0)
@onready var level_manager: FW_LevelManager
@onready var monster_to_fight: FW_Monster_Resource
@onready var npc_to_load: FW_Character


var GU = FW_GridUtils.new()
var grid = FW_GridUtils.Grid.new()

var level: int
enum game_types {normal, vs, solitaire, sudoku}

var game_mode: game_types = game_types.normal

var game_manager: FW_GameManager
var tracker = FW_Tracker.new()
var inventory_item_size := Vector2(64,64)
var skill_check_in_progress := false
var skill_check_resolving := false
var player_action_in_progress := false

var level_scroll_value: int = 0
var normal_level_select_scroll_value: int = 0
var previous_scene_path: String = "res://WorldMap/world_map.tscn"
var pending_combined_stats_review: bool = false
var current_prize_wheel_hash: int = 0

var inventory_size = 60 # number of slots

enum Initiative {
	PLAYER,
	MONSTER
}

var _pending_initiative_winner: Initiative = Initiative.PLAYER

# normal mode
const save_filename: String = "save.dat"
const user_dir: String = "user://save/"
var save_path = user_dir + save_filename
var level_info: Dictionary = {} # for regular game mode
var default_level_info: Dictionary = {
	1:{
		"unlocked": true
	}
}

const screenshake_num := 5
# vs mode
const save_filename_vs: String = "vs_save.res"
var save_path_vs = user_dir + save_filename_vs
const level_filename: String = "level_save.res"
const level_path_history_filename: String = "level_path_history_save.res"
var level_path_vs = user_dir + level_filename
var level_path_history_vs = user_dir + level_path_history_filename

class VSCurrentInfo:
	var level: FW_LevelNode
	var world: FW_WorldNode
	var level_to_generate := {}
	var environmental_effects: Array[FW_EnvironmentalEffect]

var current_info :VSCurrentInfo
var world_state :FW_WorldState
var env_manager :FW_EnvironmentManager
var effect_manager: FW_EffectManager
var notification_manager: FW_NotificationManager

# Run seed for ensuring different level generation between game cycles
var current_run_seed: int = 0

# Returns true if Steamworks is available and enabled
func is_steam_ok() -> bool:
	# Return false on Android regardless
	if OS.get_name() == "Android":
		return false

	# Check if Steamworks exists and is enabled
	if not Steamworks:
		return false

	return Steamworks.steam_enabled

func safe_steam_set_achievement(achievement_name: String) -> void:
	if is_steam_ok() and Steamworks.has_method("set_achievement"):
		Steamworks.set_achievement(achievement_name)

func safe_steam_increment_stat(stat_name: String) -> void:
	if is_steam_ok() and Steamworks.has_method("increment_steam_stat"):
		Steamworks.increment_steam_stat(stat_name)

func safe_steam_set_rich_presence(token: String, player_name: String = "") -> void:
	# Safe wrapper for Steam rich presence - updated
	if is_steam_ok() and Steamworks.has_method("set_rich_presence"):
		Steamworks.set_rich_presence(token, player_name)

func set_initiative_winner(winner: Initiative) -> void:
	_pending_initiative_winner = winner

func get_initiative_winner() -> Initiative:
	return _pending_initiative_winner

func consume_initiative_winner() -> Initiative:
	var winner := _pending_initiative_winner
	_pending_initiative_winner = Initiative.PLAYER
	return winner

func setup_worldstate() -> void:
	current_info = VSCurrentInfo.new()
	world_state = FW_WorldState.new()
	env_manager = FW_EnvironmentManager.new()
	effect_manager = FW_EffectManager.new()

	# Load and initialize notification manager
	notification_manager = FW_NotificationManager.new()
	notification_manager.initialize()

	# Load run seed for persistent game cycles
	load_run_seed()

	# Initialize simplified PvP cache system for VS mode
	FW_PvPCache.initialize()

func get_current_run_seed() -> int:
	return current_run_seed

func increment_run_seed() -> void:
	current_run_seed += 1
	save_run_seed()  # Persist the new seed
	#FW_Debug.debug_log(["Run seed incremented to: ", current_run_seed])

func setup_level_manager() -> void:
	level_manager = FW_LevelManager.new(player)

func load_player() -> void:
	player = null
	player = load_data_vs()
	# Set flag to prevent default ability reset during setup when loading from save
	player._loading_from_save = true
	player.setup()
	# Reset flag after setup
	player._loading_from_save = false
	# Load doghouse state after player is loaded
	DoghouseManager.load_state()

func load_worldstate() -> void:
	load_level_data()

func vs_save() -> void:
	save_data_vs()
	save_world_data()

func save_data_vs() -> void:
	var error := ResourceSaver.save(player, save_path_vs)
	if error:
		printerr("Error during save")

func load_data_vs() -> FW_Player:
	if FileAccess.file_exists(save_path_vs):
		var data := ResourceLoader.load(save_path_vs, "", ResourceLoader.CACHE_MODE_REPLACE)
		if data is FW_Player:
			return data
	return FW_Player.new()

func load_run_seed() -> void:
	var run_seed_path = user_dir + "run_seed.save"
	if FileAccess.file_exists(run_seed_path):
		var file = FileAccess.open(run_seed_path, FileAccess.READ)
		if file:
			current_run_seed = file.get_32()
			file.close()
	else:
		current_run_seed = 0

func save_run_seed() -> void:
	var run_seed_path = user_dir + "run_seed.save"
	var file = FileAccess.open(run_seed_path, FileAccess.WRITE)
	if file:
		file.store_32(current_run_seed)
		file.close()

func save_world_data() -> void:
	if !world_state or !level_path_vs:
		return
	# Set the 'data' key to null in each world before saving
	for k in world_state.save.keys():
		var v = world_state.save[k]
		if v is Dictionary and v.has("data"):
			v["data"] = null
			world_state.save[k] = v # Ensure the change is written back

	# Safety pass: forcibly set any 'data' key to null in all dictionaries
	for k in world_state.save.keys():
		var v = world_state.save[k]
		if v is Dictionary and v.has("data"):
			v["data"] = null
			world_state.save[k] = v

	var error := ResourceSaver.save(world_state, level_path_vs)
	if error:
		printerr("Error during world save: " + str(error))

func load_level_data(map_hash: int = 0) -> bool:
	if FileAccess.file_exists(level_path_vs):
		var res = load(level_path_vs)
		if res:
			world_state = res
			# Don't regenerate here - let get_or_generate_level handle it
			if world_state.save.has(map_hash):
				return true
	return false

# Apply saved player progress (cleared nodes, fog states) to a regenerated level
func _apply_saved_progress_to_level(root_node: FW_LevelNode, map_hash: int) -> void:
	if !world_state:
		return

	var cleared_nodes = world_state.get_cleared_nodes(map_hash)
	var fog_cleared = world_state.get_fog_cleared(map_hash)

	# Use BFS to traverse all nodes and apply progress
	var queue = [root_node]
	var visited = {}
	var hash_to_node = {}

	while queue.size() > 0:
		var node = queue.pop_front()
		if !node or visited.has(node.get_instance_id()):
			continue

		visited[node.get_instance_id()] = true
		hash_to_node[node.level_hash] = node

		# Apply saved progress to this node
		if cleared_nodes.has(node.level_hash):
			node.cleared = cleared_nodes[node.level_hash]

		if fog_cleared.has(node.level_hash):
			node.fog = !fog_cleared[node.level_hash]  # fog_cleared = true means fog = false

		# Restore saved monster, event, and environment data from resource paths
		var saved_monster_path = world_state.get_node_monster(map_hash, node.level_hash)
		if saved_monster_path != "":
			var loaded_monster = ResourceLoader.load(saved_monster_path)
			if loaded_monster:
				node.monster = loaded_monster
				var ability_paths = world_state.get_node_monster_abilities(map_hash, node.level_hash)
				if ability_paths.size() > 0:
					var loaded_abilities = _fixup_resource_paths(ability_paths, "Ability")
					if loaded_abilities.size() > 0:
						node.monster.abilities.clear()
						for ab in loaded_abilities:
							node.monster.abilities.append(ab)
						# Mark abilities as initialized to prevent re-randomization during setup()
						node.monster.abilities_initialized = true

		var saved_event_path = world_state.get_node_event(map_hash, node.level_hash)
		if saved_event_path != "":
			var loaded_event = ResourceLoader.load(saved_event_path)
			if loaded_event:
				node.event = loaded_event

		var saved_minigame_path = world_state.get_node_minigame(map_hash, node.level_hash)
		if saved_minigame_path != "":
			node.minigame_path = saved_minigame_path

		var saved_environment_paths = world_state.get_node_environments(map_hash, node.level_hash)
		var loaded_envs = _fixup_resource_paths(saved_environment_paths, "EnvironmentalEffect")
		if loaded_envs.size() > 0:
			node.environment.clear()
			for env in loaded_envs:
				node.environment.append(env)

		# Restore PvP data for player nodes
		if node.node_type == FW_LevelNode.NodeType.PLAYER:
			var stored_json = world_state.get_pvp_arena_node(map_hash, node.level_hash)
			var stored_cache_id = world_state.get_pvp_cache_id(map_hash, node.level_hash)

			if stored_json != "":
				node.player_data_json = stored_json
				node.player_cache_id = stored_cache_id
				# Ensure node type is set correctly
				node.node_type = FW_LevelNode.NodeType.PLAYER

		# Add children to queue
		for child in node.children:
			if child and !visited.has(child.get_instance_id()):
				queue.append(child)

	# --- Remap path_history to new node instances ---
	var path_history = world_state.get_path_history(map_hash)
	var new_path_history = {}
	for depth in path_history.keys():
		var old_node = path_history[depth]
		if old_node and old_node.level_hash and hash_to_node.has(old_node.level_hash):
			new_path_history[depth] = hash_to_node[old_node.level_hash]
	# Update world_state's path_history with remapped nodes
	if new_path_history.size() > 0:
		world_state.save[map_hash]["path_history"] = new_path_history

# Save generation parameters when creating a new level
func save_level_generation_params(map_hash: int, params: Dictionary) -> void:
	if world_state:
		world_state.update_level_gen_params(map_hash, params)

# Track when a node is cleared (call this when player completes a level)
func mark_node_cleared(map_hash: int, level_hash: int, cleared: bool = true) -> void:
	if world_state:
		world_state.update_node_cleared(map_hash, level_hash, cleared)

# Track when fog is cleared from a node (call this when player removes fog)
func mark_fog_cleared(map_hash: int, level_hash: int, cleared: bool = true) -> void:
	if world_state:
		world_state.update_fog_cleared(map_hash, level_hash, cleared)

# Generate a new level and store generation parameters for later regeneration
func generate_new_level(map_hash: int, params: Dictionary, skip_data_storage: bool = false) -> FW_LevelNode:
	# Create the generator with the map hash as seed
	var generator = FW_LevelGenerator.new(map_hash)

	# Generate the level using provided parameters
	var root_node = generator.generate_level(params)
	# Store the generation parameters for future regeneration
	save_level_generation_params(map_hash, params)

	# Store node-specific data (monsters, events, environments) for persistence
	# Skip if this is a regeneration where we want to preserve existing saved data
	if not skip_data_storage:
		_store_node_specific_data(root_node, map_hash)

	# Store the generated level data
	if world_state:
		world_state.update_data(map_hash, root_node)

	return root_node

# Get or generate a level - this is the main method for accessing levels
func get_or_generate_level(map_hash: int, params: Dictionary) -> FW_LevelNode:
	if !world_state:
		setup_worldstate()

	# Ensure world_state is properly initialized
	if !world_state:
		return generate_new_level(map_hash, params)

	# Try to load existing level first
	if load_level_data(map_hash):
		var existing_level = world_state.get_level_data(map_hash)
		if existing_level and existing_level.name != "":  # Check that it's a valid level node
			# Apply saved progress to existing level
			_apply_saved_progress_to_level(existing_level, map_hash)
			return existing_level
		# If data is null but we have generation params, regenerate
		var gen_params = world_state.get_level_gen_params(map_hash)
		if gen_params.size() > 0:
			# Generate level structure but don't overwrite saved monster/event data
			var regenerated_level = generate_new_level(map_hash, gen_params, true)
			# CRITICAL: Apply saved progress to regenerated level
			_apply_saved_progress_to_level(regenerated_level, map_hash)
			# Update the world state with the regenerated level after applying progress
			if world_state:
				world_state.update_data(map_hash, regenerated_level)
			return regenerated_level

	# Generate new level if none exists
	var new_level = generate_new_level(map_hash, params)
	return new_level

# Store node-specific data (monsters, events, environments) for all nodes in a tree
func _store_node_specific_data(root_node: FW_LevelNode, map_hash: int) -> void:
	if !world_state or !root_node:
		return

	# Use BFS to traverse all nodes and store their specific data
	var queue = [root_node]
	var visited = {}

	while queue.size() > 0:
		var node = queue.pop_front()
		if !node or visited.has(node.get_instance_id()):
			continue

		visited[node.get_instance_id()] = true

		# Store based on node type
		match node.node_type:
			FW_LevelNode.NodeType.MONSTER:
				_store_monster_node_data(node, map_hash)
			FW_LevelNode.NodeType.EVENT:
				_store_event_node_data(node, map_hash)
			FW_LevelNode.NodeType.PLAYER:
				_store_pvp_node_data(node, map_hash)
			FW_LevelNode.NodeType.MINIGAME:
				_store_minigame_node_data(node, map_hash)
			FW_LevelNode.NodeType.STARTING:
				pass  # Starting nodes don't need special storage

		# Add children to queue
		for child in node.children:
			if child and !visited.has(child.get_instance_id()):
				queue.append(child)

func _store_monster_node_data(node: FW_LevelNode, map_hash: int) -> void:
	"""Store monster-specific node data"""
	var monster_path = node.monster.resource_path if node.monster and "resource_path" in node.monster and node.monster.resource_path != "" else ""
	if monster_path == "" and node.monster:
		monster_path = save_monster_to_disk(node.monster)

	var environment_paths = []
	if node.environment:
		for env in node.environment:
			if env and "resource_path" in env and env.resource_path != "":
				environment_paths.append(env.resource_path)

	var monster_ability_paths = []
	if node.monster and "abilities" in node.monster:
		for ab in node.monster.abilities:
			var ab_path = ab.resource_path if ab and "resource_path" in ab and ab.resource_path != "" else ""
			if ab_path == "" and ab:
				ab_path = save_ability_to_disk(ab)
			if ab_path != "":
				monster_ability_paths.append(ab_path)

	if monster_path != "" or environment_paths.size() > 0 or monster_ability_paths.size() > 0:
		world_state.store_node_data(map_hash, node.level_hash, monster_path, "", environment_paths, monster_ability_paths)

func _store_event_node_data(node: FW_LevelNode, map_hash: int) -> void:
	"""Store event-specific node data"""
	var event_path = node.event.resource_path if node.event and "resource_path" in node.event and node.event.resource_path != "" else ""
	var environment_paths = []
	if node.environment:
		for env in node.environment:
			if env and "resource_path" in env and env.resource_path != "":
				environment_paths.append(env.resource_path)

	world_state.store_node_data(map_hash, node.level_hash, "", event_path, environment_paths)

func _store_minigame_node_data(node: FW_LevelNode, map_hash: int) -> void:
	"""Store minigame-specific node data"""
	if not node.minigame_path:
		return

	world_state.store_minigame_node(map_hash, node.level_hash, node.minigame_path)

func _store_pvp_node_data(node: FW_LevelNode, map_hash: int) -> void:
	"""Store PvP-specific node data"""
	if node.player_data_json != "":
		world_state.store_pvp_arena_node(map_hash, node.level_hash, node.player_data_json, node.player_cache_id)

	# Also store environmental effects for PvP nodes so they persist on regeneration
	var environment_paths = []
	if node.environment:
		for env in node.environment:
			if env and "resource_path" in env and env.resource_path != "":
				environment_paths.append(env.resource_path)

	if environment_paths.size() > 0:
		# Use store_node_data with empty monster/event paths but environment paths provided
		world_state.store_node_data(map_hash, node.level_hash, "", "", environment_paths)

func is_vs_mode() -> bool:
	if game_mode == game_types.vs:
		return true
	return false

func set_data() -> void:
	if !is_vs_mode():
		level_info = load_data()

func save_data() -> void:
	if !is_vs_mode():
		var file = FileAccess.open(save_path, FileAccess.WRITE)
		if file != null:
			file.store_var(level_info)
		else:
			return
		file.close()

func load_data() -> Dictionary:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file != null:
		var data = file.get_var()
		return data
	else:
		return default_level_info

func delete_vs_save_data() -> void:
	# possibly call an archiving / stats saving here prior to deleting the save
	var dir = DirAccess.open(user_dir)
	var error_vs = dir.remove(save_filename_vs)
	var error_vs_level_path = dir.remove(level_path_vs)
	var error_level_path_history_vs = dir.remove(level_path_history_vs)
	# remove the equipment
	delete_rng_equipment()
	# Clear PvP cache data to reset opponents
	# Use the new simplified cache system to refresh opponents
	FW_PvPCache.refresh_for_new_game()
	# Increment run seed to ensure different level generation for next run
	increment_run_seed()
	# Reset the world_state object in memory to ensure fresh start
	world_state = null
	current_info = null
	env_manager = null
	effect_manager = null
	# Use Godot error constants for robust checks. Ignore 'does not exist' errors.
	var had_error := false
	if error_vs != OK and error_vs != ERR_DOES_NOT_EXIST:
		printerr("delete_vs_save_data: failed to remove ", save_filename_vs, " code=", error_vs)
		had_error = true
	if error_vs_level_path != OK and error_vs_level_path != ERR_DOES_NOT_EXIST:
		printerr("delete_vs_save_data: failed to remove ", level_path_vs, " code=", error_vs_level_path)
		had_error = true
	if error_level_path_history_vs != OK and error_level_path_history_vs != ERR_DOES_NOT_EXIST:
		printerr("delete_vs_save_data: failed to remove ", level_path_history_vs, " code=", error_level_path_history_vs)
		had_error = true
	if had_error:
		printerr("delete_vs_save_data: one or more files failed to delete")

func delete_data() -> void:
	var dir = DirAccess.open(user_dir)
	var error_vs = dir.remove(save_filename_vs)
	var error_vs_level_path = dir.remove(level_path_vs)
	var error_level_path_history_vs = dir.remove(level_path_history_vs)
	# remove the equipment
	delete_rng_equipment()
	# Clear PvP cache data to reset opponents
	# Use the new simplified cache system to refresh opponents
	FW_PvPCache.refresh_for_new_game()
	# Reset the world_state object in memory to ensure fresh start
	world_state = null
	current_info = null
	env_manager = null
	effect_manager = null
	# Clear puzzle mode save also
	var error = dir.remove(save_filename)
	# Use Godot error constants for robust checks. Ignore 'does not exist' errors.
	var had_error := false
	if error != OK and error != ERR_DOES_NOT_EXIST:
		printerr("delete_data: failed to remove ", save_filename, " code=", error)
		had_error = true
	if error_vs != OK and error_vs != ERR_DOES_NOT_EXIST:
		printerr("delete_data: failed to remove ", save_filename_vs, " code=", error_vs)
		had_error = true
	if error_vs_level_path != OK and error_vs_level_path != ERR_DOES_NOT_EXIST:
		printerr("delete_data: failed to remove ", level_path_vs, " code=", error_vs_level_path)
		had_error = true
	if error_level_path_history_vs != OK and error_level_path_history_vs != ERR_DOES_NOT_EXIST:
		printerr("delete_data: failed to remove ", level_path_history_vs, " code=", error_level_path_history_vs)
		had_error = true
	if had_error:
		printerr("delete_data: one or more files failed to delete")

func super_delete_data() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var extensions = [".json", ".dat", ".res", ".tres", ".ini"]
		while file_name != "":
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue
			if not dir.current_is_dir():
				var file_path = "user://".path_join(file_name)
				var should_delete = false
				if "achievement" in file_name.to_lower():
					FW_Debug.debug_log(["Super delete: deleting achievement file " + file_path])
					should_delete = true
				else:
					for ext in extensions:
						if file_name.ends_with(ext):
							should_delete = true
							break
				if should_delete:
					DirAccess.remove_absolute(file_path)
			file_name = dir.get_next()
		dir.list_dir_end()

	# Delete the save directory and its contents
	if DirAccess.dir_exists_absolute("user://save"):
		_delete_save_dir("user://save")

	# Recreate the save directory
	DirAccess.make_dir_absolute("user://save")

func _delete_save_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				_delete_save_dir(full_path)
			else:
				DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
		DirAccess.remove_absolute(path)  # remove empty dir

func make_2d_array() -> Array:
	var array = []
	for i in range(grid.width):
		var row = []
		for j in range(grid.height):
			row.append(null)
		array.append(row)
	return array

func delete_rng_equipment() -> void:
	const equipment_dir = "user://save/Equipment"
	var dir = DirAccess.open(equipment_dir)
	if dir and dir.dir_exists(equipment_dir):
		for file in dir.get_files():
			dir.remove(file)

func generate_custom_uuid() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return "%d-%s" % [Time.get_unix_time_from_system(), generate_random_string(6)]

func generate_random_string(length: int) -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()  # Ensure randomness
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""
	for i in range(length):
		result += charset[rng.randi_range(0, charset.length() - 1)]
	return result

func save_equipment_to_disk(item: FW_Item) -> String:
	const user_path := "user://save/"
	const equipment_dir := "Equipment"
	var dir = DirAccess.open(user_path)
	if !dir.dir_exists(equipment_dir):
		dir.make_dir(equipment_dir)
	var file_path = user_path + "/" + equipment_dir + "/random_loot_" + generate_custom_uuid() + ".tres"
	var result = ResourceSaver.save(item, file_path)
	if result != OK:
		printerr("Failed to save equipment.")
		return ""
	return file_path

func save_monster_to_disk(monster: FW_Monster_Resource) -> String:
	const user_path := "user://save/"
	const monsters_dir := "Monsters"
	var dir = DirAccess.open(user_path)
	if !dir.dir_exists(monsters_dir):
		dir.make_dir(monsters_dir)
	var file_path = user_path + "/" + monsters_dir + "/random_monster_" + generate_custom_uuid() + ".tres"
	var result = ResourceSaver.save(monster, file_path)
	if result != OK:
		printerr("Failed to save monster.")
		return ""
	return file_path

func save_ability_to_disk(ability: FW_Ability) -> String:
	const user_path := "user://save/"
	const abilities_dir := "Abilities"
	var dir = DirAccess.open(user_path)
	if !dir.dir_exists(abilities_dir):
		dir.make_dir(abilities_dir)
	var file_path = user_path + "/" + abilities_dir + "/random_ability_" + generate_custom_uuid() + ".tres"
	var result = ResourceSaver.save(ability, file_path)
	if result != OK:
		printerr("Failed to save ability.")
		return ""
	return file_path

# Helper to convert arrays of resource paths to loaded resources of the expected type
func _fixup_resource_paths(arr: Array, expected_type: String) -> Array:
	var loaded_resources = []
	for path in arr:
		if path is String and path != "":
			var resource = ResourceLoader.load(path)
			if resource:
				loaded_resources.append(resource)
			else:
				push_warning("Failed to load %s resource from path: %s" % [expected_type, path])
	return loaded_resources

# Helper function to add equipment and trigger notifications
func add_equipment_to_player(equipment: FW_Equipment) -> void:
	player.inventory.append(equipment)
	save_equipment_to_disk(equipment)
	EventBus.equipment_added.emit(equipment)
	EventBus.inventory_changed.emit()

# Helper function to add consumable and trigger notifications
func add_consumable_to_player(consumable) -> void:
	player.inventory.append(consumable)
	EventBus.consumable_added.emit(consumable)
	EventBus.inventory_changed.emit()

# Helper function to add any item and trigger appropriate notifications
func add_item_to_player(item: FW_Item) -> void:
	player.inventory.append(item)

	if item.item_type == FW_Item.ITEM_TYPE.EQUIPMENT:
		save_equipment_to_disk(item)
		EventBus.equipment_added.emit(item)
	elif item.item_type == FW_Item.ITEM_TYPE.CONSUMABLE:
		EventBus.consumable_added.emit(item)
	else:
		EventBus.inventory_item_added.emit(item)
	EventBus.inventory_changed.emit()
