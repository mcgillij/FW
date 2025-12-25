extends Resource

class_name FW_EffectCommand

# Base class for all combat effect commands
# Allows for queuing and execution

@export var command_type: String = "base"  # e.g., "damage", "heal", "buff"
@export var description: String = ""  # For debugging/logging
@export var log_message: String = ""  # Templated message for combat log, e.g., "{attacker} deals {amount} damage to {target}"

func execute() -> void:
	# Override in subclasses
	push_error("FW_EffectCommand.execute() must be overridden in subclass")
	# Note: base class should not emit combat log messages.
	# Use the FW_EffectResource.log_message / get_formatted_log_message and
	# let CombatLogBus / CombatLogManager handle UI/file output to avoid duplicates.

func can_execute() -> bool:
	# Override for preconditions (e.g., mana checks)
	return true

func _to_string() -> String:
	return "[%s] %s" % [command_type, description]
