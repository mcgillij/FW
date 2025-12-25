extends Node

@onready var path: String = "user://save/config.ini"
var sound_on: bool = true
var music_on: bool = true
var animated_bg: bool = true
var combat_log_enabled: bool = false
var ingame_combat_log: bool = true
var sound_volume: float = -15.0
var music_volume: float = -15.0
var level_select_zoom: Vector2 = Vector2(1, 1)
var skill_tree_zoom: Vector2 = Vector2(0.5, 0.5)
var window_size: Vector2 = Vector2(720, 1280)
var window_position: Vector2 = Vector2(0, 0)
var _window_position_loaded: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_config()
	apply_window_settings()
	call_deferred("_connect_resize_signal")

func save_config() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "sound", sound_on)
	config.set_value("audio", "music", music_on)
	config.set_value("audio", "sound_volume", sound_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("shaders", "animated_bg", animated_bg)
	config.set_value("combat_log", "enabled", combat_log_enabled)
	config.set_value("ingame_combat_log", "enabled", ingame_combat_log)
	config.set_value("zoom", "level_select_zoom", level_select_zoom)
	config.set_value("zoom", "skill_tree_zoom", skill_tree_zoom)
	config.set_value("display", "window_size", window_size)
	config.set_value("display", "window_position", window_position)
	#FW_Debug.debug_log(["Saving config with window_size: ", window_size])

	var err = config.save(path)
	if err != OK:
		printerr("something went horribly wrong with writing the config file")

func load_config() -> Dictionary:
	var config = ConfigFile.new()
	var default_options = {
		"sound": true,
		"music": true,
		"animated_bg": true,
		"combat_log": false,
		"ingame_combat_log": true,
		"sound_volume": -15.0,
		"music_volume": -15.0,
		"level_select_zoom": Vector2(1, 1),
		"skill_tree_zoom": Vector2(0.5, 0.5),
		"window_size": Vector2(720, 1280),
		"window_position": Vector2(0, 0)
	}
	var err = config.load(path)
	if err != OK:
		_window_position_loaded = false
		return default_options
	sound_on = config.get_value("audio", "sound", default_options.sound)
	music_on = config.get_value("audio", "music", default_options.music)
	sound_volume = config.get_value("audio", "sound_volume", default_options.sound_volume)
	music_volume = config.get_value("audio", "music_volume", default_options.music_volume)
	animated_bg = config.get_value("shaders", "animated_bg", default_options.animated_bg)
	combat_log_enabled = config.get_value("combat_log", "enabled", default_options.combat_log)
	ingame_combat_log = config.get_value("ingame_combat_log", "enabled", default_options.ingame_combat_log)
	level_select_zoom = config.get_value("zoom", "level_select_zoom", default_options.level_select_zoom)
	skill_tree_zoom = config.get_value("zoom", "skill_tree_zoom", default_options.skill_tree_zoom)
	var size_value = config.get_value("display", "window_size", default_options.window_size)
	if size_value is Vector2 or size_value is Vector2i:
		window_size = Vector2(size_value)
	else:
		window_size = default_options.window_size
	_window_position_loaded = config.has_section_key("display", "window_position")
	var position_value = config.get_value("display", "window_position", default_options.window_position)
	if _window_position_loaded and (position_value is Vector2 or position_value is Vector2i):
		window_position = Vector2(position_value)
	else:
		_window_position_loaded = false
	#FW_Debug.debug_log(["Loaded window size: ", window_size])
	return {}

func apply_window_settings() -> void:
	var window = get_window()
	if OS.get_name() in ["Windows", "Linux", "macOS"]:  # Desktop platforms
		# Validate and constrain window size to reasonable bounds
		var min_size := Vector2i(320, 240)  # Minimum viable window size
		var max_size := Vector2i(7680, 4320)  # 8K resolution max

		var desired_size := Vector2i(
			clampi(roundi(window_size.x), min_size.x, max_size.x),
			clampi(roundi(window_size.y), min_size.y, max_size.y)
		)

		# Update stored size if it was clamped
		if desired_size != Vector2i(roundi(window_size.x), roundi(window_size.y)):
			window_size = Vector2(desired_size)
			FW_Debug.debug_log(["Window size clamped to reasonable bounds: ", window_size])

		window.size = desired_size

		if _window_position_loaded:
			var desired_pos := Vector2i(roundi(window_position.x), roundi(window_position.y))
			var validated_pos := _ensure_window_position_visible(desired_size, desired_pos)
			window.position = validated_pos
			window_position = Vector2(validated_pos)
		else:
			# Ensure the default position is valid
			var current_pos := Vector2i(window.position)
			var validated_pos := _ensure_window_position_visible(desired_size, current_pos)
			if validated_pos != current_pos:
				window.position = validated_pos
			window_position = Vector2(validated_pos)

		window.unresizable = false  # false means resizable, true means not resizable
		# Connect to size change for saving
		if not window.size_changed.is_connected(_on_window_size_changed):
			window.size_changed.connect(_on_window_size_changed)
	else:  # Mobile (e.g., Android) - keep fixed
		window.unresizable = true  # true means not resizable
		# Ensure stretch mode is preserved (handled in project.godot/export presets)

func _on_window_size_changed() -> void:
	window_size = get_window().size
	save_config()  # Persist the new size

func save_current_window_size() -> void:
	window_size = Vector2(get_window().size)
	#FW_Debug.debug_log(["Saving current window size: ", window_size])
	save_config()

func save_current_window_position() -> void:
	var window = get_window()
	var current_pos := Vector2i(window.position)
	var current_size := Vector2i(window.size)

	# Validate that the current position makes sense
	var validated_pos := _ensure_window_position_visible(current_size, current_pos)

	# Only save if the position is actually valid and different from what we have
	if validated_pos == current_pos:
		window_position = Vector2(validated_pos)
		_window_position_loaded = true
		save_config()
	else:
		# If the current position isn't valid, move to the validated position
		window.position = validated_pos
		window_position = Vector2(validated_pos)
		_window_position_loaded = true
		save_config()
		FW_Debug.debug_log(["Window position corrected and saved: ", window_position])

func _connect_resize_signal() -> void:
	var window = get_window()
	if not window.size_changed.is_connected(_on_window_size_changed):
		window.size_changed.connect(_on_window_size_changed)

func _ensure_window_position_visible(desired_size: Vector2i, desired_pos: Vector2i) -> Vector2i:
	var window_rect := Rect2i(desired_pos, desired_size)
	var screen_count := DisplayServer.get_screen_count()

	# First, try to find a screen that can contain the entire window
	for screen_index in range(screen_count):
		var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
		if usable_rect.intersects(window_rect):
			# Check if the window is mostly visible (at least 75% of its area)
			var intersection = usable_rect.intersection(window_rect)
			var window_area = desired_size.x * desired_size.y
			var visible_area = intersection.size.x * intersection.size.y

			if visible_area >= window_area * 0.75:
				return desired_pos

	# If no screen found or screen count is 0, fall back to primary screen
	if screen_count == 0:
		FW_Debug.debug_log(["Warning: No screens detected, using fallback position"])
		return Vector2i.ZERO

	var primary_index := DisplayServer.get_primary_screen()
	var primary_rect := DisplayServer.screen_get_usable_rect(primary_index)

	# Ensure window fits within primary screen boundaries
	var constrained_size := Vector2i(
		mini(desired_size.x, primary_rect.size.x),
		mini(desired_size.y, primary_rect.size.y)
	)

	# Center the window on the primary screen if possible
	var fallback_x := primary_rect.position.x
	var fallback_y := primary_rect.position.y

	if primary_rect.size.x > constrained_size.x:
		fallback_x += int((primary_rect.size.x - constrained_size.x) * 0.5)
	if primary_rect.size.y > constrained_size.y:
		fallback_y += int((primary_rect.size.y - constrained_size.y) * 0.5)

	# Ensure the fallback position doesn't push the window off-screen
	fallback_x = clampi(fallback_x, primary_rect.position.x,
						primary_rect.position.x + primary_rect.size.x - constrained_size.x)
	fallback_y = clampi(fallback_y, primary_rect.position.y,
						primary_rect.position.y + primary_rect.size.y - constrained_size.y)

	var fallback_pos := Vector2i(fallback_x, fallback_y)

	# If we had to change the size, update the stored window size
	if constrained_size != desired_size:
		window_size = Vector2(constrained_size)
		FW_Debug.debug_log(["Window size adjusted to fit screen: ", window_size])

	return fallback_pos
