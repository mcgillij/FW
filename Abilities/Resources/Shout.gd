extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var buff: FW_Buff = load("res://Buffs/Shout.tres")
	# Use intelligent buff application - will apply to monster since Shout is harmful
	CombatManager.apply_buff_intelligently(buff)

	var cost_pink := float(cost.get("pink", 0))
	var damage_scalar := clampf(float(damage) / 18.0, 0.0, 1.0)
	var focus_scalar := clampf(cost_pink / 12.0, 0.0, 1.0)
	var level_scalar := clampf(float(level) / 5.0, 0.0, 1.2)
	# Shape the overlay using ability metrics so heavier casts feel louder
	var fx_params := {
		"intensity": 0.95 + damage_scalar * 0.7 + focus_scalar * 0.35,
		"aberration_strength": 0.45 + damage_scalar * 0.45,
		"ring_gain": 1.1 + level_scalar * 0.6,
		"noise_strength": 0.28 + focus_scalar * 0.25,
		"ripple_strength": 0.22 + damage_scalar * 0.5,
		"bloom_boost": 1.3 + damage_scalar * 0.55,
		"scan_strength": 0.28 + focus_scalar * 0.3,
		"band_sharpness": 1.6 + damage_scalar * 0.5,
		"duration": 1.05 + level_scalar * 0.15
	}

	trigger_visual_effects("on_cast", fx_params)
