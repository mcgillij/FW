extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	# snag the color based on the ability to pass to the vfx so it's contextually
	# appropriate for the ability being used, since this is used for each of the
	# default attacks
	var color = FW_Colors.get_color(str(ABILITY_TYPES.keys()[ability_type]).to_lower())

	# Trigger visual effects with the appropriate color
	var params = {}
	if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
		params["origin_position"] = _params["origin_position"]
	else:
		params["origin_position"] = Vector2(0.5, 0.5)
	params["target_position"] = params["origin_position"]

	# Override the shader color parameter with the ability's color
	if visual_effect and "shader_params" in visual_effect:
		params["attack_color"] = color

	trigger_visual_effects("on_cast", params)
