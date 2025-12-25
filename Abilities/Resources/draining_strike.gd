extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
	# Fullscreen draining strike visual — no tile targeting required.
	var params = {}
	if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
		params["origin_position"] = _params["origin_position"]
	else:
		params["origin_position"] = Vector2(0.5, 0.5)

	trigger_visual_effects("on_cast", params)
