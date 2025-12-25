extends RefCounted
class_name FW_InputActions

# Holds a project-defined list of actions and their default binds.
# This is deliberately data-only so you can unit test it without a SceneTree.

var _definitions: Array[Dictionary] = []

func add_action(action: StringName, default_events: Array[InputEvent] = []) -> FW_InputActions:
	_definitions.append({
		"action": action,
		"defaults": default_events,
	})
	return self

func get_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in _definitions:
		out.append(d.get("action", &""))
	return out

func get_defaults(action: StringName) -> Array[InputEvent]:
	for d in _definitions:
		if d.get("action", &"") == action:
			var defaults: Array[InputEvent] = d.get("defaults", [])
			return defaults
	return []

func ensure_actions_exist() -> void:
	for d in _definitions:
		var action: StringName = d.get("action", &"")
		if action == &"":
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)

		# If the action exists but has no events, seed defaults.
		if InputMap.action_get_events(action).is_empty():
			var defaults: Array[InputEvent] = d.get("defaults", [])
			for ev in defaults:
				if ev != null:
					InputMap.action_add_event(action, ev)

func reset_to_defaults() -> void:
	for d in _definitions:
		var action: StringName = d.get("action", &"")
		if action == &"":
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var defaults: Array[InputEvent] = d.get("defaults", [])
		for ev in defaults:
			if ev != null:
				InputMap.action_add_event(action, ev)
