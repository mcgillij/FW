extends Node
class_name FW_ConfigService

signal changed(section: StringName, key: StringName, value: Variant)

const DEFAULT_PATH := "user://save/framework_config.cfg"

var _path: String = DEFAULT_PATH
var _cfg := ConfigFile.new()
var _defaults_by_section: Dictionary = {}

func register_defaults(defaults_by_section: Dictionary) -> void:
	for section in defaults_by_section.keys():
		var section_name := StringName(str(section))
		if not _defaults_by_section.has(section_name):
			_defaults_by_section[section_name] = {}
		var dst: Dictionary = _defaults_by_section[section_name]
		var src: Dictionary = defaults_by_section[section]
		for key in src.keys():
			dst[StringName(str(key))] = src[key]

func load(path: String = DEFAULT_PATH) -> void:
	_path = path
	_cfg = ConfigFile.new()
	var err := _cfg.load(_path)
	if err != OK:
		_cfg = ConfigFile.new()

func save() -> void:
	_ensure_save_dir_exists(_path)
	_cfg.save(_path)

func get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
	if _cfg.has_section_key(section, key):
		return _cfg.get_value(section, key)
	if _defaults_by_section.has(section):
		var defaults: Dictionary = _defaults_by_section[section]
		if defaults.has(key):
			return defaults[key]
	return fallback

func set_value(section: StringName, key: StringName, value: Variant, autosave: bool = false) -> void:
	_cfg.set_value(section, key, value)
	changed.emit(section, key, value)
	if autosave:
		save()

func get_bool(section: StringName, key: StringName, fallback: bool = false) -> bool:
	return bool(get_value(section, key, fallback))

func get_int(section: StringName, key: StringName, fallback: int = 0) -> int:
	return int(get_value(section, key, fallback))

func get_float(section: StringName, key: StringName, fallback: float = 0.0) -> float:
	return float(get_value(section, key, fallback))

func get_string(section: StringName, key: StringName, fallback: String = "") -> String:
	return str(get_value(section, key, fallback))

func get_vec2(section: StringName, key: StringName, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var v: Variant = get_value(section, key, fallback)
	if v is Vector2:
		return v
	return fallback

func has_key(section: StringName, key: StringName) -> bool:
	return _cfg.has_section_key(section, key)

func _ensure_save_dir_exists(path: String) -> void:
	var dir_path := path.get_base_dir()
	if dir_path.is_empty():
		return
	if DirAccess.dir_exists_absolute(dir_path):
		return
	DirAccess.make_dir_recursive_absolute(dir_path)
