extends FW_Buff

class_name FW_EvasiveRecoveryBuff

func on_evasion() -> void:
	# Heal for 20 points when evasion occurs
	var heal_amount = 20
	emit_heal_effect(heal_amount)
	
	# Log the healing
	var heal_log_vars = {"amount": heal_amount}
	var formatted_message = get_formatted_log_message(heal_log_vars)
	if formatted_message:
		# Emit combat log via EventBus (follows same pattern as other buff effects)
		EventBus.publish_combat_log.emit(formatted_message)