extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var buff: FW_Buff = load("res://Buffs/Brace.tres")
	# Use intelligent buff application - will apply to caster since Brace is beneficial
	CombatManager.apply_buff_intelligently(buff)
	# Trigger shield VFX
	var params = _params if _params != null else {}
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	if not params.has("origin_position"):
		params["origin_position"] = Vector2(0.5, 0.5)
	trigger_visual_effects("on_cast", params)
