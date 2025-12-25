extends Resource

class_name FW_BlockDisplayData

enum BlockType {
	MONSTER,
	PLAYER,
	EVENT,
	MINIGAME
}

# Common interface for block display data
@export var texture: Texture2D
@export var name: String
@export var description: String
@export var display_name: String
@export var level_depth: int
@export var block_type: BlockType = BlockType.MONSTER
@export var environment: Array[FW_EnvironmentalEffect] = []
@export var fog: bool = false
@export var cleared: bool = false
@export var block_hash: int = 0  # Used for unique name generation

# Type-specific data references
@export var monster_data: FW_Monster_Resource
@export var player_data: FW_Combatant
@export var event_data: FW_EventResource
@export var minigame_path: String = ""

# Player-specific display data
@export var player_id: String = ""
@export var player_level: int = 1
@export var job_name: String = ""
@export var job_color: Color = Color.WHITE

# Monster-specific display data
@export var monster_type: FW_Monster_Resource.monster_type = FW_Monster_Resource.monster_type.SCRUB

# Virtual methods that subclasses should implement
func get_combatant() -> FW_Combatant:
	"""Return the appropriate Combatant for combat"""
	match block_type:
		BlockType.PLAYER:
			return player_data
		BlockType.MONSTER:
			return FW_Combatant.from_monster_data(monster_data) if monster_data else null
		_:
			return null

func get_combat_target() -> Resource:
	"""Get the raw combat target (Monster_Resource, Combatant, or EventResource)"""
	match block_type:
		BlockType.MONSTER:
			return monster_data
		BlockType.PLAYER:
			return player_data
		BlockType.EVENT:
			return event_data
		BlockType.MINIGAME:
			return null
		_:
			return null

func is_combat_block() -> bool:
	"""Check if this block leads to combat"""
	return block_type in [BlockType.MONSTER, BlockType.PLAYER]

func is_player_block() -> bool:
	"""Check if this is a player/PvP block"""
	return block_type == BlockType.PLAYER

func is_minigame_block() -> bool:
	"""Check if this is a minigame block"""
	return block_type == BlockType.MINIGAME

func get_difficulty_icon() -> Texture2D:
	"""Return the appropriate difficulty icon"""
	if block_type == BlockType.MONSTER:
		const MONSTER_TYPE_ICONS := {
			FW_Monster_Resource.monster_type.SCRUB: preload("res://Monsters/MonsterDifficultyImages/scrub.png"),
			FW_Monster_Resource.monster_type.GRUNT: preload("res://Monsters/MonsterDifficultyImages/grunt.png"),
			FW_Monster_Resource.monster_type.ELITE: preload("res://Monsters/MonsterDifficultyImages/elite.png"),
			FW_Monster_Resource.monster_type.BOSS: preload("res://Monsters/MonsterDifficultyImages/boss.png"),
		}
		return MONSTER_TYPE_ICONS.get(monster_type, MONSTER_TYPE_ICONS[FW_Monster_Resource.monster_type.SCRUB])
	elif block_type == BlockType.PLAYER:
		# Use the dedicated player PvP icon
		const PLAYER_PVP_ICON := preload("res://Monsters/MonsterDifficultyImages/fallen_player.png")
		return PLAYER_PVP_ICON
	elif block_type == BlockType.EVENT:
		return preload("res://tile_images/questionmarks.png")
	elif block_type == BlockType.MINIGAME:
		return preload("res://Icons/minigames.png")
	else:
		return null

func get_difficulty_text() -> String:
	"""Get text description of difficulty"""
	if block_type == BlockType.PLAYER:
		if player_level >= 50:
			return "Master"
		elif player_level >= 25:
			return "Veteran"
		elif player_level >= 10:
			return "Experienced"
		else:
			return "Novice"
	elif block_type == BlockType.MONSTER:
		match monster_type:
			FW_Monster_Resource.monster_type.SCRUB:
				return "Easy"
			FW_Monster_Resource.monster_type.GRUNT:
				return "Normal"
			FW_Monster_Resource.monster_type.ELITE:
				return "Hard"
			FW_Monster_Resource.monster_type.BOSS:
				return "Boss"
			_:
				return "Unknown"
	elif block_type == BlockType.MINIGAME:
		return "Minigame"
	else:
		return "Event"

func get_display_info() -> Dictionary:
	"""Return display information for UI"""
	return {
		"name": display_name if display_name != "" else name,
		"subtitle": _get_subtitle(),
		"icon": get_difficulty_icon(),
		"difficulty": get_difficulty_text(),
		"is_combat": is_combat_block(),
		"is_player": is_player_block()
	}

func _get_subtitle() -> String:
	"""Generate appropriate subtitle based on type"""
	if block_type == BlockType.PLAYER:
		var level_text = "Level %d" % player_level
		return "%s • %s" % [job_name, level_text] if job_name != "" else level_text
	elif block_type == BlockType.MONSTER:
		return FW_Monster_Resource.monster_type.keys()[monster_type].capitalize()
	elif block_type == BlockType.MINIGAME:
		return "Minigame"
	else:
		return "Event"

# Factory methods for creating different types of block data
static func from_monster(monster: FW_Monster_Resource, depth: int = 0, env: Array[FW_EnvironmentalEffect] = [], index: int = 0, map_hash: int = 0) -> FW_BlockDisplayData:
	"""Create block data from a Monster_Resource"""
	var data = FW_BlockDisplayData.new()
	data.block_type = BlockType.MONSTER
	data.monster_data = monster
	data.level_depth = depth
	data.environment = env
	data.monster_type = monster.type
	data.description = monster.description
	data.texture = monster.texture

	# Generate unique names using LevelNameGenerator
	if map_hash != 0:
		var seed_value = abs(("%d_%d_%d" % [depth, index, map_hash]).hash())
		var unique_suffix = "%d_%d" % [depth, index]
		data.block_hash = seed_value

		# Determine if this is elite/boss based on monster type
		var is_elite = monster.type == FW_Monster_Resource.monster_type.ELITE
		var is_boss = monster.type == FW_Monster_Resource.monster_type.BOSS

		var generated_names: Array
		if is_boss:
			generated_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 2, "special")
		elif is_elite:
			generated_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 3, "special")
		else:
			generated_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value, "monster")

		data.name = generated_names[0] + "_" + unique_suffix
		data.display_name = generated_names[1]
	else:
		# Fallback to original monster name if no hash provided
		data.name = monster.name
		data.display_name = monster.name
		data.block_hash = monster.name.hash()

	return data

static func from_minigame(minigame_path_p: String, depth: int = 0, index: int = 0, map_hash: int = 0) -> FW_BlockDisplayData:
	"""Create block data for a minigame node"""
	var data = FW_BlockDisplayData.new()
	data.block_type = BlockType.MINIGAME
	data.level_depth = depth
	data.minigame_path = minigame_path_p

	var base_name := "Minigame"
	if minigame_path_p != "":
		base_name = minigame_path_p.get_file().get_basename().replace("_", " ")
		if base_name.length() > 0:
			base_name = base_name.capitalize()

	# Generate deterministic names if we have a map hash
	if map_hash != 0:
		var seed_value = abs(("%d_%d_%d" % [depth, index, map_hash]).hash())
		var unique_suffix = "%d_%d" % [depth, index]
		data.block_hash = seed_value
		var generated_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 5, "event")
		data.name = generated_names[0] + "_" + unique_suffix
		data.display_name = base_name if base_name != "" else generated_names[1]
	else:
		data.name = base_name
		data.display_name = base_name
		data.block_hash = base_name.hash()

	return data

static func from_player(player: FW_Combatant, depth: int = 0, env: Array[FW_EnvironmentalEffect] = [], index: int = 0, map_hash: int = 0) -> FW_BlockDisplayData:
	"""Create block data from a Combatant (player)"""
	var data = FW_BlockDisplayData.new()
	data.block_type = BlockType.PLAYER
	data.player_data = player
	data.level_depth = depth
	data.environment = env
	data.player_level = player.difficulty_level if player.difficulty_level > 0 else 1
	data.job_name = player.job_name if player.job_name != "" else "Adventurer"
	data.job_color = player.job_color
	data.description = player.description if player.description else "A fellow adventurer"
	data.texture = player.texture

	# Generate unique names using LevelNameGenerator
	if map_hash != 0:
		var seed_value = abs(("%d_%d_%d" % [depth, index, map_hash]).hash())
		var unique_suffix = "%d_%d" % [depth, index]
		data.block_hash = seed_value

		# For PvP blocks, we can generate arena-style names
		var generated_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 4, "pvp")
		data.name = generated_names[0] + "_" + unique_suffix
		data.display_name = "%s's %s" % [player.name, generated_names[1]]
	else:
		# Fallback to original player name
		data.name = player.name + " (Player)"
		data.display_name = player.name
		data.block_hash = (player.name + "_player").hash()

	return data

static func from_event(event: FW_EventResource, depth: int = 0, env: Array[FW_EnvironmentalEffect] = [], index: int = 0, map_hash: int = 0) -> FW_BlockDisplayData:
	"""Create block data from an EventResource"""
	var data = FW_BlockDisplayData.new()
	data.block_type = BlockType.EVENT
	data.event_data = event
	data.level_depth = depth
	data.environment = env
	data.description = event.description if event.description else "A mysterious event"
	data.texture = event.image if event.image else null

	# Generate unique names using LevelNameGenerator
	if map_hash != 0:
		var seed_value = abs(("%d_%d_%d" % [depth, index, map_hash]).hash())
		var unique_suffix = "%d_%d" % [depth, index]
		data.block_hash = seed_value

		var generated_names = FW_LevelNameGenerator.generate_name_from_seed(seed_value + 1, "event")
		data.name = generated_names[0] + "_" + unique_suffix
		data.display_name = generated_names[1]
	else:
		# Fallback to original event name
		data.name = event.name if event.name else "Event"
		data.display_name = data.name
		data.block_hash = data.name.hash()

	return data
