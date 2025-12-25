extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var blur_buff: FW_Buff = load("res://Buffs/Blur.tres")
	# Use intelligent buff application - will apply to caster since Blur is beneficial
	CombatManager.apply_buff_intelligently(blur_buff)
	# Trigger fullscreen blur VFX
	var params = _params if _params != null else {}
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	if not params.has("origin_position"):
		params["origin_position"] = Vector2(0.5, 0.5)
	params["intensity"] = params.get("power", 1.0) * 0.9
	trigger_visual_effects("on_cast", params)
