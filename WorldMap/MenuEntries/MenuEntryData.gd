extends Resource

class_name FW_MenuEntryData

@export var key: StringName
@export var label_override: String = ""
@export_file("*.png", "*.webp", "*.jpg", "*.jpeg", "*.svg", "*.svgz", "*.tres", "*.res") var icon_path: String = ""

var _cached_icon_path: String = ""
var _cached_icon: Texture2D

func get_key() -> StringName:
	return key

func get_label() -> String:
	var trimmed := label_override.strip_edges()
	if trimmed != "":
		return trimmed
	return FW_MenuEntryCatalog.get_label(key)

func get_icon_path() -> String:
	var trimmed := icon_path.strip_edges()
	if trimmed != "":
		return trimmed
	return FW_MenuEntryCatalog.get_icon_path(key)

func get_icon() -> Texture2D:
	var path := get_icon_path()
	if path == "":
		return null
	if path == _cached_icon_path and _cached_icon:
		return _cached_icon
	var texture := ResourceLoader.load(path)
	if texture and texture is Texture2D:
		_cached_icon_path = path
		_cached_icon = texture
		return _cached_icon
	_cached_icon_path = ""
	_cached_icon = null
	push_warning("MenuEntryData: Failed to load icon at '" + path + "' for key '" + str(key) + "'")
	return null
