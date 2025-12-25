extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
	var berzerk_buff: FW_Buff = load("res://Buffs/Berzerk.tres")
	CombatManager.apply_buff_intelligently(berzerk_buff)

	# Trigger fullscreen berzerk visual effect (on cast)
	if EventBus.has_signal("ability_visual_effect_requested"):
		EventBus.ability_visual_effect_requested.emit("berzerk_rage", {"duration": 1.2})
