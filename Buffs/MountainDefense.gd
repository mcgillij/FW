extends FW_Buff

# Function to apply the buff effect per turn, if needed
func apply_per_turn_effects() -> void:
	duration_left -= 1
	emit_shield_effect(int(self.effect_strength))

	if duration_left <= 0:
		on_expire()
