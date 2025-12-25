extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
	# Trigger visual effect
	trigger_visual_effects("on_cast")

	# Shield granting is handled by CombatManager using ability.effects (gain_shield)
	# Keep this method minimal so the .tres / ability.effects control behavior.
	return
