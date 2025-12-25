extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(_grid: Node, _params) -> void:
	var buff: FW_Buff = load("res://Buffs/EvasiveRecovery.tres")
	# Use intelligent buff application - will apply to caster since Evasive Recovery is beneficial
	CombatManager.apply_buff_intelligently(buff)

	# Immediate burst of vitality when Odin's Shield manifests
	var heal_amount := 10
	var heal_context: Dictionary = {}
	if typeof(GDM) != TYPE_NIL and GDM and GDM.game_manager and GDM.game_manager.turn_manager:
		heal_context["is_player_turn"] = GDM.game_manager.turn_manager.is_player_turn()
	else:
		heal_context["is_player_turn"] = true
	CombatManager.apply_effect_resource("res://Effects/EvasiveRecoveryHeal.tres", heal_amount, heal_context)

	# Trigger evasive recovery VFX
	var params = _params if _params != null else {}
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	if not params.has("origin_position"):
		params["origin_position"] = Vector2(0.5, 0.5)
	# use optional power to scale intensity
	params["intensity"] = params.get("power", 1.0)
	trigger_visual_effects("on_cast", params)
