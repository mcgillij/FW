extends Node
class_name FW_WindowPrefs

# Optional window sizing/positioning helper for desktop platforms.
# Stores values in FW_ConfigService under [display].

const SECTION := &"display"
const KEY_WINDOW_SIZE := &"window_size"
const KEY_WINDOW_POSITION := &"window_position"

@export var min_window_size: Vector2i = Vector2i(320, 240)
@export var max_window_size: Vector2i = Vector2i(7680, 4320)
@export var desktop_only: bool = true

var _config: FW_ConfigService
var _window_position_loaded: bool = false

func configure(config: FW_ConfigService) -> void:
	_config = config

func apply_to_current_window() -> void:
	if _config == null:
		return
	if desktop_only and not _is_desktop():
		return

	var window := get_window()
	var desired_size := _get_clamped_window_size()
	window.size = desired_size

	_window_position_loaded = _config.has_key(SECTION, KEY_WINDOW_POSITION)
	var desired_pos := _get_window_position(Vector2(desired_size))
	var validated_pos := _ensure_window_position_visible(desired_size, desired_pos)
	window.position = validated_pos

	_config.set_value(SECTION, KEY_WINDOW_SIZE, Vector2(desired_size))
	_config.set_value(SECTION, KEY_WINDOW_POSITION, Vector2(validated_pos))

	if not window.size_changed.is_connected(_on_window_size_changed):
		window.size_changed.connect(_on_window_size_changed)

func save_current_window_position() -> void:
	if _config == null:
		return
	if desktop_only and not _is_desktop():
		return
	var window := get_window()
	var desired_pos := Vector2i(window.position)
	var desired_size := Vector2i(window.size)
	var validated_pos := _ensure_window_position_visible(desired_size, desired_pos)
	window.position = validated_pos
	_config.set_value(SECTION, KEY_WINDOW_POSITION, Vector2(validated_pos), true)

func _on_window_size_changed() -> void:
	if _config == null:
		return
	var s := Vector2i(get_window().size)
	var clamped := _clamp_size(s)
	if clamped != s:
		get_window().size = clamped
	_config.set_value(SECTION, KEY_WINDOW_SIZE, Vector2(clamped), true)

func _get_clamped_window_size() -> Vector2i:
	var v: Variant = _config.get_value(SECTION, KEY_WINDOW_SIZE, Vector2(720, 1280))
	var size_v2 := Vector2(720, 1280)
	if v is Vector2:
		size_v2 = v
	elif v is Vector2i:
		size_v2 = Vector2(v)
	var s := Vector2i(roundi(size_v2.x), roundi(size_v2.y))
	return _clamp_size(s)

func _get_window_position(_size: Vector2) -> Vector2i:
	var v: Variant = _config.get_value(SECTION, KEY_WINDOW_POSITION, Vector2(0, 0))
	if v is Vector2:
		return Vector2i(roundi(v.x), roundi(v.y))
	if v is Vector2i:
		return v
	return Vector2i.ZERO

func _clamp_size(s: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(s.x, min_window_size.x, max_window_size.x),
		clampi(s.y, min_window_size.y, max_window_size.y)
	)

func _ensure_window_position_visible(desired_size: Vector2i, desired_pos: Vector2i) -> Vector2i:
	var window_rect := Rect2i(desired_pos, desired_size)
	var screen_count := DisplayServer.get_screen_count()

	for screen_index in range(screen_count):
		var usable_rect := DisplayServer.screen_get_usable_rect(screen_index)
		if usable_rect.intersects(window_rect):
			var intersection := usable_rect.intersection(window_rect)
			var window_area := desired_size.x * desired_size.y
			var visible_area := intersection.size.x * intersection.size.y
			if visible_area >= int(window_area * 0.75):
				return desired_pos

	if screen_count == 0:
		return Vector2i.ZERO

	var primary_index := DisplayServer.get_primary_screen()
	var primary_rect := DisplayServer.screen_get_usable_rect(primary_index)

	var constrained_size := Vector2i(
		mini(desired_size.x, primary_rect.size.x),
		mini(desired_size.y, primary_rect.size.y)
	)

	var fallback_x := primary_rect.position.x
	var fallback_y := primary_rect.position.y
	if primary_rect.size.x > constrained_size.x:
		fallback_x += int((primary_rect.size.x - constrained_size.x) * 0.5)
	if primary_rect.size.y > constrained_size.y:
		fallback_y += int((primary_rect.size.y - constrained_size.y) * 0.5)

	fallback_x = clampi(fallback_x, primary_rect.position.x, primary_rect.position.x + primary_rect.size.x - constrained_size.x)
	fallback_y = clampi(fallback_y, primary_rect.position.y, primary_rect.position.y + primary_rect.size.y - constrained_size.y)

	return Vector2i(fallback_x, fallback_y)

func _is_desktop() -> bool:
	return OS.get_name() in ["Windows", "Linux", "macOS"]
