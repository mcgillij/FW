# FW_LevelNode.gd
extends Resource

class_name FW_LevelNode

enum NodeType {
	STARTING,
	MONSTER,
	EVENT,
	PLAYER,  # PvP node type
	BLACKSMITH,
	MINIGAME
}

# Level data
@export var name: String
@export var display_name: String
@export var level_depth: int
@export var node_type: NodeType = NodeType.MONSTER
@export var environment: Array[FW_EnvironmentalEffect]
@export var monster: FW_Monster_Resource
@export var children: Array = []
@export var cleared: bool = false
@export var event: FW_EventResource
@export var fog: bool = false
@export var level_hash: int = 0
@export var skill_check: FW_SkillCheckRes

# Minigame-specific data
@export var minigame_path: String = ""

# PvP-specific data (serialized as JSON string for persistence)
@export var player_data_json: String = ""
@export var player_cache_id: String = ""

# Parents: Array of parent nodes (can have multiple parents)
@export var parents: Array[FW_LevelNode] = []

# Initialize the level node with data
func _init(name_p: String = "Blank",
		display_name_p: String = "Blank",
		depth: int = 0,
		node_type_p: NodeType = NodeType.MONSTER,
		environment_arr: Array[FW_EnvironmentalEffect] = [],
		monster_res: FW_Monster_Resource = null,
		children_p := [],
		cleared_p := false,
		event_p: FW_EventResource = null,
		fog_p := false,
		skill_check_p:FW_SkillCheckRes = null,
		hash_p := 0,
		minigame_path_p: String = ""
	):
	name = name_p + ""
	display_name = display_name_p + ""
	level_depth = depth
	node_type = node_type_p
	environment = environment_arr
	monster = monster_res
	children = children_p
	cleared = cleared_p
	event = event_p
	fog = fog_p
	skill_check = skill_check_p
	level_hash = hash_p
	parents = []
	minigame_path = minigame_path_p

# Helper methods for PvP data management
func set_player_data(combatant: FW_Combatant, cache_id: String = "") -> void:
	"""Store player data as serialized JSON for persistence"""
	if combatant:
		var player_dict: Dictionary
		# Check if it's actually a Player instance
		if combatant.has_method("serialize_for_upload"):
			player_dict = combatant.serialize_for_upload()
		else:
			# If not a Player, create a basic dictionary from Combatant
			player_dict = _combatant_to_dict(combatant)
		player_data_json = JSON.stringify(player_dict)
		player_cache_id = cache_id
		node_type = NodeType.PLAYER

func get_player_data() -> FW_Combatant:
	"""Restore player data from JSON or cache"""
	if player_data_json != "":
		# Try to deserialize from stored JSON
		var json = JSON.new()
		var parse_result = json.parse(player_data_json)
		if parse_result == OK and json.data is Dictionary:
			return FW_PlayerSerializer.deserialize_player_data(json.data)

	# Fallback: try to get from PvPCache if cache_id exists
	if player_cache_id != "":
		# Note: FW_PvPCache doesn't support individual cache ID lookup
		# This is a design choice to keep it simple - just get a random opponent
		return FW_PvPCache.get_opponent()

	# Final fallback: get a random cached opponent
	return FW_PvPCache.get_opponent()

func _combatant_to_dict(combatant: FW_Combatant) -> Dictionary:
	"""Convert a Combatant to a dictionary for serialization"""
	# Properly serialize affinities as strings, not enum values
	var affinities_array: Array[String] = []
	if combatant.affinities:
		for affinity in combatant.affinities:
			affinities_array.append(FW_Ability.ABILITY_TYPES.keys()[affinity])

	# Properly serialize abilities
	var abilities_array: Array = []
	if combatant.abilities:
		for ability in combatant.abilities:
			if ability != null:
				abilities_array.append({
					"name": ability.name,
					"resource_path": ability.resource_path
				})

	return {
		"character": {
			"name": combatant.name,
			"description": combatant.description if combatant.description else "A fellow adventurer",
			"texture_path": combatant.texture.resource_path if combatant.texture else "",
			"affinities": affinities_array,
			"effects": combatant.character_effects if combatant.character_effects else {}
		},
		"stats": combatant.stats.get_stat_values() if combatant.stats else {},
		"abilities": abilities_array,
		"job": {
			"name": combatant.job_name if combatant.job_name else "Adventurer",
			"color": FW_Utils.normalize_color(combatant.job_color).to_html() if combatant.job_color else "ffffffff"
		},
		"level": combatant.difficulty_level if combatant.difficulty_level > 0 else 1,
		"difficulty": "GRUNT",  # Default difficulty
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system()
	}

func is_player_node() -> bool:
	"""Check if this is a PvP player node"""
	return node_type == NodeType.PLAYER

func is_minigame_node() -> bool:
	"""Check if this is a minigame node"""
	return node_type == NodeType.MINIGAME
