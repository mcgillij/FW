extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
	# Shield granting is managed centrally via CombatManager using the
	# ability.effects["gain_shield"] value. Keep this method empty so the
	# resource drives behavior instead of direct calls.
	# Trigger a juicy fullscreen VFX. Abilities are resources and can't
	# call scene APIs, so we rely on the caller to provide normalized
	# origin_position in _params. Default to center if not provided.
	var params = _params if _params != null else {}
	if typeof(params) != TYPE_DICTIONARY:
		params = {}
	if not params.has("origin_position"):
		params["origin_position"] = Vector2(0.5, 0.5)
	# Allow scaling intensity by a runtime power value if provided
	if params.has("power"):
		params["intensity"] = float(params["power"]) * 1.0
	else:
		params["intensity"] = 1.0
	trigger_visual_effects("on_cast", params)
