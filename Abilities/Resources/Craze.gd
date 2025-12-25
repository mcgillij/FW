extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var buff: FW_Buff = load("res://Buffs/Craze.tres")
	# Use intelligent buff application - will apply to player since Craze is beneficial
	CombatManager.apply_buff_intelligently(buff)

	# Trigger the Craze visual effect
	trigger_visual_effects("on_cast", {})
