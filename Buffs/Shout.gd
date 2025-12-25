extends FW_Buff

# Function to apply the buff effect per turn, if needed
func apply_per_turn_effects() -> void:
	duration_left -= 1
	@warning_ignore("narrowing_conversion")
	emit_damage_over_time_effect(self.effect_strength, " Recurring Shout damage!")
	if duration_left <= 0:
		on_expire()
