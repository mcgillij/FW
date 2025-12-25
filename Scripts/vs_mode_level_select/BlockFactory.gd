extends RefCounted
class_name FW_BlockFactory

## Factory class for creating block display data for the map system
## Supports both monsters and players/PvP opponents

static func create_monster_block(monster: FW_Monster_Resource, depth: int = 0, environment: Array[FW_EnvironmentalEffect] = [], index: int = 0, map_hash: int = 0) -> FW_BlockDisplayData:
	"""Create a block for fighting a monster"""
	return FW_BlockDisplayData.from_monster(monster, depth, environment, index, map_hash)

static func create_player_block(player: FW_Combatant, depth: int = 0, environment: Array[FW_EnvironmentalEffect] = [], index: int = 0, map_hash: int = 0) -> FW_BlockDisplayData:
	"""Create a block for fighting another player (PvP)"""
	return FW_BlockDisplayData.from_player(player, depth, environment, index, map_hash)

static func create_event_block(event: FW_EventResource, depth: int = 0, environment: Array[FW_EnvironmentalEffect] = [], index: int = 0, map_hash: int = 0) -> FW_BlockDisplayData:
	"""Create a block for an event"""
	return FW_BlockDisplayData.from_event(event, depth, environment, index, map_hash)

static func create_random_player_block(depth: int = 0, index: int = 0, map_hash: int = 0) -> FW_BlockDisplayData:
	"""Create a block with a random cached player opponent"""
	var player_opponent = FW_PvPCache.get_opponent()
	# If no map_hash provided, generate one from player data
	if map_hash == 0:
		map_hash = (player_opponent.name + "_random").hash()
	return create_player_block(player_opponent, depth, [], index, map_hash)

static func create_pvp_arena_blocks(count: int = 5, map_hash: int = 0) -> Array[FW_BlockDisplayData]:
	"""Create multiple PvP blocks for an arena-style selection screen"""
	var blocks: Array[FW_BlockDisplayData] = []

	# Generate a hash if none provided
	if map_hash == 0:
		map_hash = ("pvp_arena_" + str(Time.get_unix_time_from_system())).hash()

	for i in range(count):
		var player_opponent = FW_PvPCache.get_opponent()
		var block_data = create_player_block(player_opponent, i + 1, [], i, map_hash)
		blocks.append(block_data)

	return blocks
