extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
	var _shieldbash_resource: Resource = load("res://Buffs/Shieldbash.tres")

	# Trigger a fullscreen, punchy green shield bash VFX
	var params = {}
	if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
		params["origin_position"] = _params["origin_position"]
	else:
		params["origin_position"] = Vector2(0.5, 0.5)

	trigger_visual_effects("on_cast", params)
