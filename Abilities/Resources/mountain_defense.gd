extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var buff: FW_Buff = load("res://Buffs/MountainDefense.tres")
	# Use intelligent buff application - will apply to caster since Brace is beneficial
	CombatManager.apply_buff_intelligently(buff)

	# Trigger the visual effect associated with this ability (no grid targeting needed)
	# The Ability base will merge defaults from the AbilityVisualEffect resource.
	trigger_visual_effects("on_cast", {})
