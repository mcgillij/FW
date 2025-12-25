extends FW_Buff

# Custom Rage buff that provides both bark stat boost and mana gain per turn

func apply_per_turn_effects() -> void:
	duration_left -= 1

	# Apply scaling stat bonus (bark)
	if stat_target and type == buff_type.scaling:
		@warning_ignore("narrowing_conversion")
		var stats_target: FW_StatsManager = _get_stats_target()
		if stats_target:
			stats_target.apply_temporary_bonus(self.stat_target, self.effect_strength)

	# Apply mana gain per turn (10 red mana)
	var mana_gain = {"red": 10}
	if owner_type == "monster":
		CombatManager.apply_mana_gain_to_monster(mana_gain)
	else:
		CombatManager.apply_mana_gain_to_player(mana_gain)

	if duration_left <= 0:
		on_expire()
