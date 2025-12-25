extends Node
class_name FW_FrameworkBus

signal event(topic: StringName, payload: Dictionary)

func emit_event(topic: StringName, payload: Dictionary = {}) -> void:
	event.emit(topic, payload)

func emit_error(message: String, context: Dictionary = {}) -> void:
	var payload := {
		"message": message,
		"context": context,
	}
	emit_event(&"framework.error", payload)

func emit_log(message: String, context: Dictionary = {}) -> void:
	var payload := {
		"message": message,
		"context": context,
	}
	emit_event(&"framework.log", payload)
