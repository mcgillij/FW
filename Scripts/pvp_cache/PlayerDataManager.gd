extends RefCounted
class_name FW_PlayerDataManager

# Simplified manager that only handles:
# 1. Player serialization/upload
# 2. Getting opponents (delegates to cache)
const MIN_LEVEL_FOR_PVP = 2
static func upload_player_data(player: FW_Player) -> void:
	"""Upload player data to server if online"""
	if not NetworkUtils.should_use_network():
		return
	if player.current_level < MIN_LEVEL_FOR_PVP:
		FW_Debug.debug_log(["not uploading, too low level"])
		return
	var data = FW_PlayerSerializer.serialize_player_for_upload(player)
	var json_string = JSON.stringify(data)

	NetworkUtils.perform_post(
		Engine.get_main_loop().current_scene,
		NetworkUtils.server_url + "/upload_player",
		_on_upload_complete,
		json_string
	)

static func _on_upload_complete(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 200:
		FW_Debug.debug_log(["✓ Player data uploaded successfully"])
	else:
		FW_Debug.debug_log(["✗ Failed to upload player data"])

static func get_pvp_opponent() -> FW_Combatant:
	"""Get a PvP opponent - uses the simple cache system"""
	return FW_PvPCache.get_opponent()
