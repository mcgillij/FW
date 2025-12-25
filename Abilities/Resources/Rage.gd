extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var rage_buff: FW_Buff = load("res://Buffs/Rage.tres")
	# Use intelligent buff application - will apply to caster since Rage is beneficial
	CombatManager.apply_buff_intelligently(rage_buff)

	# Trigger rage visual effect
	var params = {}
	if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
		params["origin_position"] = _params["origin_position"]
	else:
		params["origin_position"] = Vector2(0.5, 0.5)
	trigger_visual_effects("on_cast", params)