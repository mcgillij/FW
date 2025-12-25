extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var buff: FW_Buff = load("res://Buffs/Bleed.tres")
	# Use intelligent buff application - will apply to monster since Bleed is harmful
	CombatManager.apply_buff_intelligently(buff)

	# trigger subtle bleed VFX
	var params = {}
	if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
		params["origin_position"] = _params["origin_position"]
	else:
		params["origin_position"] = Vector2(0.5, 0.5)
	trigger_visual_effects("on_cast", params)
