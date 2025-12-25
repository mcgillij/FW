extends Node

signal layout_changed(preset: LayoutPreset)

enum LayoutPreset { PORTRAIT, LANDSCAPE }

const CONFIG_PATH := "user://layout_prefs.cfg"
const CONFIG_SECTION := "layout"
const CONFIG_KEY_CURRENT := "solitaire_ui"

var _current_preset: LayoutPreset = LayoutPreset.PORTRAIT
var _platform_default: LayoutPreset = LayoutPreset.PORTRAIT

func _ready() -> void:
	_platform_default = LayoutPreset.LANDSCAPE if _is_mobile_platform() else LayoutPreset.PORTRAIT
	_current_preset = _platform_default
	_load_config()

func get_active_preset() -> LayoutPreset:
	return _current_preset

func apply_layout(preset: LayoutPreset) -> void:
	if preset == _current_preset:
		return
	_current_preset = preset
	_save_config()
	layout_changed.emit(_current_preset)

func toggle_layout() -> void:
	var next := LayoutPreset.LANDSCAPE if _current_preset == LayoutPreset.PORTRAIT else LayoutPreset.PORTRAIT
	apply_layout(next)

func reset_to_default() -> void:
	apply_layout(_platform_default)

func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	var stored_value: int = int(config.get_value(CONFIG_SECTION, CONFIG_KEY_CURRENT, int(_platform_default)))
	var values := LayoutPreset.values()
	if stored_value >= 0 and stored_value < values.size():
		_current_preset = values[stored_value]

func _save_config() -> void:
	var config := ConfigFile.new()
	config.set_value(CONFIG_SECTION, CONFIG_KEY_CURRENT, int(_current_preset))
	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_warning("Failed to save layout preference: %s" % err)

func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
