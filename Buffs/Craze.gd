extends FW_Buff


# Function to apply the buff effect per turn, if needed
func apply_per_turn_effects() -> void:
	duration_left -= 1
	if duration_left <= 0:
		on_expire()

func on_damage_taken(amount: int) -> void:
	var shields = amount * 2
	emit_shield_effect(shields)
	# Log the trigger
	# Let CombatLogBus handle formatting/publishing so it respects queue/context
	EventBus.do_booster_effect.emit(self, "craze")
