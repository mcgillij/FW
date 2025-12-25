extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var regenerate_buff: FW_Buff = load("res://Buffs/Regenerate.tres")
	# Use intelligent buff application - will apply to caster since Regenerate is beneficial
	CombatManager.apply_buff_intelligently(regenerate_buff)

	# Trigger juicy regenerate VFX
	var params = _params if _params != null else {}
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	if not params.has("origin_position"):
		params["origin_position"] = Vector2(0.5, 0.5)
	params["seed"] = randi()
	params["intensity"] = params.get("power", 1.0)
	trigger_visual_effects("on_cast", params)
