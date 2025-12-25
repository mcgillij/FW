extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
	# Trigger VFX for piercing attack. This ability doesn't target a specific tile
	# so we keep the effect generic. We pass a single origin_position parameter
	# which defaults to the center of the screen (normalized coords).
	var params = {}

	if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
		params["origin_position"] = _params["origin_position"]
	else:
		# Default to center of the viewport (normalized coordinates)
		params["origin_position"] = Vector2(0.5, 0.5)

	trigger_visual_effects("on_cast", params)
