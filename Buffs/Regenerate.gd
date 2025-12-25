extends FW_Buff


# Function to apply the buff effect per turn, if needed
func apply_per_turn_effects() -> void:
	duration_left -= 1
	# regenerate v1 just static heal, maybe look into making the higher level ones into scaling buffs
	@warning_ignore("narrowing_conversion")
	emit_heal_effect(self.effect_strength)

	if duration_left <= 0:
		on_expire()
