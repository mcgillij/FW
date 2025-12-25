extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var displacement_buff: FW_Buff = load("res://Buffs/Displacement.tres")
	# Use intelligent buff application - will apply to caster since Displacement is beneficial
	CombatManager.apply_buff_intelligently(displacement_buff)
	# Trigger displacement VFX
	var params = _params if _params != null else {}
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	if not params.has("origin_position"):
		params["origin_position"] = Vector2(0.5, 0.5)
	params["intensity"] = params.get("power", 1.0) * 1.2
	trigger_visual_effects("on_cast", params)
