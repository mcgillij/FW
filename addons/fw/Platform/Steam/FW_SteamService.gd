extends Node
class_name FW_SteamService

signal enabled_changed(enabled: bool)
signal init_failed(reason: String, details: Dictionary)
signal avatar_texture_loaded(user_id: int, texture: Texture2D)

var enabled: bool = false

var require_steam_feature: bool = true
var require_ownership: bool = false

var _steam: Object = null

func configure(config: FW_ConfigService) -> void:
	require_steam_feature = config.get_bool(&"steam", &"require_feature", true)
	require_ownership = config.get_bool(&"steam", &"require_ownership", false)

func is_platform_supported() -> bool:
	if OS.get_name() == "Android":
		return false
	if require_steam_feature and not OS.has_feature("steam"):
		return false
	return true

func has_steam_singleton() -> bool:
	return Engine.has_singleton("Steam")

func initialize() -> bool:
	if enabled:
		return true

	if not is_platform_supported():
		return false
	if not has_steam_singleton():
		init_failed.emit("missing_singleton", {})
		return false

	_steam = Engine.get_singleton("Steam")

	var init_resp: Variant = _steam.call("steamInitEx")
	var init_dict := init_resp as Dictionary
	if init_dict.is_empty() and init_resp != null:
		# Some bindings may not return a Dictionary; treat non-null as success.
		init_dict = {}

	if init_dict.has("status") and int(init_dict["status"]) != 0:
		init_failed.emit("init_failed", init_dict)
		_steam = null
		return false

	if require_ownership:
		var owned: bool = bool(_steam.call("isSubscribed"))
		if not owned:
			init_failed.emit("not_owned", init_dict)
			_steam = null
			return false

	if _steam.has_signal("avatar_loaded") and not _steam.is_connected("avatar_loaded", Callable(self, "_on_avatar_loaded")):
		_steam.connect("avatar_loaded", Callable(self, "_on_avatar_loaded"))

	enabled = true
	enabled_changed.emit(true)
	return true

func shutdown() -> void:
	if not enabled:
		return
	enabled = false
	enabled_changed.emit(false)
	_steam = null

func _process(_delta: float) -> void:
	if not enabled:
		return
	if _steam == null:
		shutdown()
		return
	if _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")

func get_steam_id() -> int:
	if not enabled or _steam == null:
		return 0
	if not _steam.has_method("getSteamID"):
		return 0
	return int(_steam.call("getSteamID"))

func set_rich_presence(key: String, value: String) -> void:
	if not enabled or _steam == null:
		return
	if not _steam.has_method("setRichPresence"):
		return
	_steam.call("setRichPresence", key, value)

func set_presence_display(token: String) -> void:
	set_rich_presence("steam_display", token)

func set_presence_player(player: String) -> void:
	set_rich_presence("player", player.to_lower())

func set_achievement(achievement_id: String) -> bool:
	if not enabled or _steam == null:
		return false
	if not _steam.has_method("setAchievement"):
		return false
	var ok: bool = bool(_steam.call("setAchievement", achievement_id))
	if ok:
		store_stats()
	return ok

func store_stats() -> bool:
	if not enabled or _steam == null:
		return false
	if not _steam.has_method("storeStats"):
		return false
	return bool(_steam.call("storeStats"))

func get_stat_int(stat_name: String, fallback: int = 0) -> int:
	if not enabled or _steam == null:
		return fallback
	if not _steam.has_method("getStatInt"):
		return fallback
	return int(_steam.call("getStatInt", stat_name))

func set_stat_int(stat_name: String, value: int) -> bool:
	if not enabled or _steam == null:
		return false
	if not _steam.has_method("setStatInt"):
		return false
	var ok: bool = bool(_steam.call("setStatInt", stat_name, value))
	if ok:
		store_stats()
	return ok

func increment_stat_int(stat_name: String, delta: int = 1) -> bool:
	var current := get_stat_int(stat_name, 0)
	return set_stat_int(stat_name, current + delta)

func request_player_avatar(avatar_type: int, steam_id: int) -> void:
	if not enabled or _steam == null:
		return
	if not _steam.has_method("getPlayerAvatar"):
		return
	_steam.call("getPlayerAvatar", avatar_type, steam_id)

func request_local_avatar(avatar_type: int) -> void:
	var steam_id := get_steam_id()
	if steam_id == 0:
		return
	request_player_avatar(avatar_type, steam_id)

func _on_avatar_loaded(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	if avatar_size <= 0:
		return
	if avatar_buffer.is_empty():
		return

	var avatar_image: Image = Image.create_from_data(
		avatar_size,
		avatar_size,
		false,
		Image.FORMAT_RGBA8,
		avatar_buffer
	)

	if avatar_size > 128:
		avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	avatar_texture_loaded.emit(user_id, avatar_texture)
