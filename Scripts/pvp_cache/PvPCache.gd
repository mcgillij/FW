extends RefCounted
class_name FW_PvPCache

# Simple PvP opponent cache with clear responsibilities:
# 1. Load seed data on first run or when offline
# 2. Fetch from server when online and replace cache
# 3. Provide opponents for current session
# 4. Refresh cache on game over

const CACHE_FILE = "user://pvp_cache.save"
const SEED_DATA_FILE = "res://seed_data/seed_player_data.json"
const MAX_CACHE_SIZE = 50

static var _instance: FW_PvPCache
static var _cached_opponents: Array[Dictionary] = []
static var _is_first_run: bool = true

static func get_instance() -> FW_PvPCache:
	if not _instance:
		_instance = FW_PvPCache.new()
	return _instance

func _init():
	_load_cache()

# Main public API - just get an opponent
static func get_opponent() -> FW_Combatant:
	var cache = get_instance()
	return cache._get_random_opponent()

# Initialize cache on game start
static func initialize():
	var cache = get_instance()
	if cache._is_cache_empty():
		cache._load_seed_data()
	# Try to refresh from network (non-blocking)
	cache._try_network_refresh()

# Refresh cache after game over
static func refresh_for_new_game():
	var cache = get_instance()
	cache._try_network_refresh()

# Clear everything (for testing/reset)
static func clear_cache():
	_cached_opponents.clear()
	if FileAccess.file_exists(CACHE_FILE):
		DirAccess.remove_absolute(CACHE_FILE)

# Private implementation
func _get_random_opponent() -> FW_Combatant:
	if _cached_opponents.is_empty():
		_load_seed_data()

	var opponent_data = _cached_opponents.pick_random()
	return FW_PlayerSerializer.deserialize_player_data(opponent_data)

func _is_cache_empty() -> bool:
	return _cached_opponents.is_empty()

func _load_cache():
	if not FileAccess.file_exists(CACHE_FILE):
		_is_first_run = true
		return

	var file = FileAccess.open(CACHE_FILE, FileAccess.READ)
	if not file:
		return

	var json = JSON.new()
	var text = file.get_as_text()
	file.close()

	if json.parse(text) == OK and json.data is Array:
		var temp_array: Array[Dictionary] = []
		for item in json.data:
			if item is Dictionary:
				temp_array.append(item)
		_cached_opponents = temp_array
		_is_first_run = false

func _save_cache():
	var file = FileAccess.open(CACHE_FILE, FileAccess.WRITE)
	if not file:
		return

	file.store_string(JSON.stringify(_cached_opponents))
	file.close()

func _load_seed_data():
	var seed_data = _load_seed_json()
	if seed_data.size() > 0:
		_cached_opponents = seed_data
	else:
		_cached_opponents = _generate_fallback_data()
	_save_cache()

func _load_seed_json() -> Array[Dictionary]:
	if not FileAccess.file_exists(SEED_DATA_FILE):
		return []

	var file = FileAccess.open(SEED_DATA_FILE, FileAccess.READ)
	if not file:
		return []

	var json = JSON.new()
	var text = file.get_as_text()
	file.close()

	if json.parse(text) == OK and json.data is Array:
		var result: Array[Dictionary] = []
		for item in json.data:
			if item is Dictionary:
				result.append(item)
		return result
	return []

func _generate_fallback_data() -> Array[Dictionary]:
	# Minimal fallback if no seed file exists
	return [{
		"character": {"name": "Training Dummy", "description": "Practice opponent"},
		"stats": {"hp": 50, "alertness": 5},
		"abilities": [],
		"level": 1,
		"difficulty": "NORMAL"
	}]

func _try_network_refresh():
	if not NetworkUtils.should_use_network():
		return

	NetworkUtils.is_server_up(null, func(is_up: bool):
		if is_up:
			_fetch_from_server()
	)

func _fetch_from_server():
	var url = NetworkUtils.server_url + "/get_random_opponents?count=" + str(MAX_CACHE_SIZE)
	NetworkUtils.perform_get(null, url, _on_network_response, false)

func _on_network_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return

	if json.data is Array and not json.data.is_empty():
		var temp_array: Array[Dictionary] = []
		for item in json.data:
			if item is Dictionary:
				temp_array.append(item)
		_cached_opponents = temp_array
		_save_cache()
