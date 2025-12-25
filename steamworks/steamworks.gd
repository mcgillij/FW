extends Node

var steam_enabled: bool = false
var avatar_widget: TextureRect = null

func _ready() -> void:
	#FW_Debug.debug_log(["Steamworks _ready called"])

	if OS.has_feature("steam") and OS.get_name() != "Android": # or OS.has_feature("editor"):
		initialize_steam()

func _process(_delta: float) -> void:
	if OS.has_feature("steam") and OS.get_name() != "Android" and steam_enabled:
		Steam.run_callbacks()

func initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	#FW_Debug.debug_log(["Did Steam initialize?: %s" % initialize_response])

	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		#FW_Debug.debug_log(["Failed to initialize Steam, shutting down: %s" % initialize_response])
		get_tree().quit()
	var is_owned: bool = Steam.isSubscribed()
	if is_owned == false:
		printerr("User does not own this game")
		get_tree().quit()
	else:
		steam_enabled = true
		Steam.avatar_loaded.connect(_on_loaded_avatar)
		# Request the user's avatar
		var steam_id = Steam.getSteamID()
		Steam.getPlayerAvatar(Steam.AVATAR_MEDIUM, steam_id)

func set_avatar_widget(widget: TextureRect) -> void:
	avatar_widget = widget

func _on_loaded_avatar(_user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	#FW_Debug.debug_log(["Avatar for user: %s" % user_id])
	#FW_Debug.debug_log(["Size: %s" % avatar_size])

	# Create the image and texture for loading
	var avatar_image: Image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)

	# Optionally resize the image if it is too large
	if avatar_size > 128:
		avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)

	# Apply the image to a texture
	var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	if avatar_widget:
		avatar_widget.texture = avatar_texture
		avatar_widget.show()

func set_rich_presence(token: String, player: String = "") -> void:
	#FW_Debug.debug_log(["in rich presence"])
	if not steam_enabled:
		#FW_Debug.debug_log(["Steam not enabled, cannot set rich presence"])
		return
	# Set the token
	if player:
		set_rich_presence_player(player)
	# Set the token
	var _setting_presence = Steam.setRichPresence("steam_display", token)

	# Debug it
	#FW_Debug.debug_log(["Setting rich presence to "+str(token)+": "+str(setting_presence)])

# Need to figure out how to actually pass the parameter up, this seems todo but the
# .vdf file / template doesn't fill it out.
func set_rich_presence_player(player: String) -> void:
	if not steam_enabled:
		#FW_Debug.debug_log(["Steam not enabled, cannot set rich presence player"])
		return
	# Set the token
	var _setting_presence = Steam.setRichPresence("player", player.to_lower())
	#FW_Debug.debug_log(["Setting rich presence player to "+str(player.to_lower())+": "+str(setting_presence)])

func set_achievement(this_achievement: String) -> void:
	if not steam_enabled:
		#FW_Debug.debug_log(["Steam not enabled, cannot set achievement"])
		return
	if not Steam.setAchievement(this_achievement):
		#FW_Debug.debug_log(["Failed to set achievement: %s" % this_achievement])
		return
	#FW_Debug.debug_log(["Set acheivement: %s" % this_achievement])

	# Pass the value to Steam then fire it
	if not Steam.storeStats():
		#FW_Debug.debug_log(["Failed to store data on Steam, should be stored locally"])
		return

	#FW_Debug.debug_log(["Data successfully sent to Steam"])

func set_statistic(this_stat: String, new_value: int = 0) -> void:
	if not steam_enabled:
		#FW_Debug.debug_log(["Steam not enabled, cannot set statistic"])
		return
	if not Steam.setStatInt(this_stat, new_value):
		#FW_Debug.debug_log(["Failed to set stat %s to: %s" % [this_stat, new_value]])
		return

	#FW_Debug.debug_log(["Set statistics %s succesfully: %s" % [this_stat, new_value]])


	# Pass the value to Steam then fire it
	if not Steam.storeStats():
		#FW_Debug.debug_log(["Failed to store data on Steam, should be stored locally"])
		return

	#FW_Debug.debug_log(["Data successfully sent to Steam"])

func increment_steam_stat(stat_name: String) -> void:
	if not steam_enabled:
		#FW_Debug.debug_log(["Steam not enabled, cannot increment statistic"])
		return
	var steam_stat: int = Steam.getStatInt(stat_name)
	var updated_value: int  = steam_stat + 1
	set_statistic(stat_name, updated_value)
