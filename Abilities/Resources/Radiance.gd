extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
	var _radiance_resource: Resource = load("res://Buffs/Radiance.tres")

	# apply the buff (existing behavior)
	CombatManager.apply_buff_intelligently(_radiance_resource)

	# trigger juicy fullscreen Radiance VFX
	var params = _params if _params != null else {}
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	# default origin to center when not provided
	if not params.has("origin_position"):
		params["origin_position"] = Vector2(0.5, 0.5)
	# map optional power to shader intensity
	params["intensity"] = params.get("power", 1.0) * 1.3
	trigger_visual_effects("on_cast", params)
