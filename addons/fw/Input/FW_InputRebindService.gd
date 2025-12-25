extends Node
class_name FW_InputRebindService

signal rebind_started(action: StringName)
signal rebind_cancelled(action: StringName)
signal rebind_applied(action: StringName)

const _SECTION := &"input"
const _BINDS_KEY := &"binds"

@export var autosave := true

var _config: FW_ConfigService
var _actions: Variant
var _pending_action: StringName = &""

func configure(config: FW_ConfigService, actions: Variant, autosave_enabled: bool = true) -> void:
	autosave = autosave_enabled
	_config = config
	_actions = actions
	if _actions != null and _actions.has_method("ensure_actions_exist"):
		_actions.call("ensure_actions_exist")
	_apply_config_binds()

func begin_rebind(action: StringName) -> void:
	_pending_action = action
	rebind_started.emit(action)

func cancel_rebind() -> void:
	if _pending_action == &"":
		return
	var a := _pending_action
	_pending_action = &""
	rebind_cancelled.emit(a)

func feed_event(event: InputEvent) -> bool:
	# Optional helper for UI code: call this from _input/_unhandled_input.
	if _pending_action == &"":
		return false
	if event == null:
		return false
	if event.is_echo():
		return false
	if not _is_bindable_event(event):
		return false

	apply_event(_pending_action, event)
	_pending_action = &""
	return true

func apply_event(action: StringName, event: InputEvent) -> void:
	if action == &"" or event == null:
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	# Simple behavior: replace all binds for this action with this one event.
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_persist_action_binds(action)
	rebind_applied.emit(action)

func clear_bind(action: StringName) -> void:
	if action == &"":
		return
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	_persist_action_binds(action)

func restore_defaults() -> void:
	if _actions == null or not _actions.has_method("reset_to_defaults"):
		return
	_actions.call("reset_to_defaults")
	# Clear persisted overrides.
	if _config != null:
		_config.set_value(_SECTION, _BINDS_KEY, {}, autosave)

func _apply_config_binds() -> void:
	if _config == null:
		return
	var binds: Dictionary = _config.get_value(_SECTION, _BINDS_KEY, {})
	if binds.is_empty():
		return

	for action_str in binds.keys():
		var action := StringName(str(action_str))
		var serialized: Variant = binds[action_str]
		if not (serialized is Array):
			continue
		var events_out: Array[InputEvent] = _deserialize_events(serialized)
		if events_out.is_empty():
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for ev in events_out:
			InputMap.action_add_event(action, ev)

func _persist_action_binds(action: StringName) -> void:
	if _config == null:
		return
	var binds: Dictionary = _config.get_value(_SECTION, _BINDS_KEY, {})
	var events := InputMap.action_get_events(action)
	binds[str(action)] = _serialize_events(events)
	_config.set_value(_SECTION, _BINDS_KEY, binds, autosave)

static func _is_bindable_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventMouseButton

static func _serialize_events(events: Array[InputEvent]) -> Array:
	var out: Array = []
	for ev in events:
		var d := _event_to_dict(ev)
		if not d.is_empty():
			out.append(d)
	return out

static func _deserialize_events(serialized: Array) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for v in serialized:
		if v is Dictionary:
			var ev := _dict_to_event(v)
			if ev != null:
				out.append(ev)
	return out

static func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev == null:
		return {}

	if ev is InputEventKey:
		var k: InputEventKey = ev
		return {
			"t": "key",
			"keycode": int(k.keycode),
			"physical_keycode": int(k.physical_keycode),
			"shift": bool(k.shift_pressed),
			"alt": bool(k.alt_pressed),
			"ctrl": bool(k.ctrl_pressed),
			"meta": bool(k.meta_pressed),
		}

	if ev is InputEventMouseButton:
		var m: InputEventMouseButton = ev
		return {
			"t": "mouse_button",
			"button_index": int(m.button_index),
		}

	if ev is InputEventJoypadButton:
		var jb: InputEventJoypadButton = ev
		return {
			"t": "joy_button",
			"device": int(jb.device),
			"button_index": int(jb.button_index),
		}

	if ev is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = ev
		return {
			"t": "joy_axis",
			"device": int(jm.device),
			"axis": int(jm.axis),
			"axis_value": float(jm.axis_value),
			"deadzone": float(jm.deadzone),
		}

	return {}

static func _dict_to_event(d: Dictionary) -> InputEvent:
	var t := str(d.get("t", ""))
	match t:
		"key":
			var k := InputEventKey.new()
			k.keycode = int(d.get("keycode", 0))
			k.physical_keycode = int(d.get("physical_keycode", 0))
			k.shift_pressed = bool(d.get("shift", false))
			k.alt_pressed = bool(d.get("alt", false))
			k.ctrl_pressed = bool(d.get("ctrl", false))
			k.meta_pressed = bool(d.get("meta", false))
			return k
		"mouse_button":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("button_index", 0))
			return m
		"joy_button":
			var jb := InputEventJoypadButton.new()
			jb.device = int(d.get("device", 0))
			jb.button_index = int(d.get("button_index", 0))
			return jb
		"joy_axis":
			var jm := InputEventJoypadMotion.new()
			jm.device = int(d.get("device", 0))
			jm.axis = int(d.get("axis", 0))
			jm.axis_value = float(d.get("axis_value", 0.0))
			jm.deadzone = float(d.get("deadzone", 0.0))
			return jm
		_:
			return null
