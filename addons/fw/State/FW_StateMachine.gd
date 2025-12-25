extends Node
class_name FW_StateMachine

signal state_changed(prev: StringName, next: StringName)

@export var auto_process := false

var _states: Dictionary = {} # StringName -> FW_State (or compatible)
var _current: StringName = &""

func add_state(name: StringName, state: Variant) -> void:
	_states[name] = state

func has_state(name: StringName) -> bool:
	return _states.has(name)

func get_state() -> StringName:
	return _current

func start(initial: StringName, data: Variant = null) -> Dictionary:
	if not _states.has(initial):
		return {"ok": false, "error": "state.missing", "state": str(initial)}
	_current = initial
	_call_state(_current, "on_enter", [&"", data])
	set_process(auto_process)
	return {"ok": true, "state": str(_current)}

func transition_to(next: StringName, data: Variant = null) -> Dictionary:
	if next == _current:
		return {"ok": true, "state": str(_current), "noop": true}
	if not _states.has(next):
		return {"ok": false, "error": "state.missing", "state": str(next)}

	var prev := _current
	if prev != &"":
		_call_state(prev, "on_exit", [next])

	_current = next
	_call_state(_current, "on_enter", [prev, data])
	state_changed.emit(prev, next)
	return {"ok": true, "prev": str(prev), "state": str(_current)}

func tick(delta: float) -> void:
	if _current == &"":
		return
	_call_state(_current, "on_update", [delta])

func send_event(event: Variant) -> void:
	if _current == &"":
		return
	_call_state(_current, "on_event", [event])

func _process(delta: float) -> void:
	if not auto_process:
		return
	tick(delta)

func _call_state(state_name: StringName, method: String, args: Array) -> void:
	var st: Variant = _states.get(state_name, null)
	if st == null:
		return
	if st is Dictionary:
		var d: Dictionary = st
		if d.has(method) and d[method] is Callable:
			(d[method] as Callable).callv(args)
		return
	if st is Object and (st as Object).has_method(method):
		(st as Object).callv(method, args)
