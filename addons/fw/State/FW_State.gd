extends RefCounted
class_name FW_State

# Base class for a state used by FW_StateMachine.
# Override the hooks you need.

func on_enter(_prev: StringName, _data: Variant = null) -> void:
	pass

func on_exit(_next: StringName) -> void:
	pass

func on_update(_delta: float) -> void:
	pass

func on_event(_event: Variant) -> void:
	pass
