extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
	# Expected context: grid may provide attacker/target in params, but combat
	# flow can pass a non-dictionary (e.g. ""), so guard and fallback to GDM.
	var attacker = null
	var target = null

	if _params and typeof(_params) == TYPE_DICTIONARY:
		attacker = _params.get("attacker", null)
		target = _params.get("target", null)

	# Fallback: derive attacker/target from current turn state if not provided
	if not attacker or not target:
		if typeof(GDM) != TYPE_NIL and GDM.game_manager and GDM.game_manager.turn_manager:
			var is_player = GDM.game_manager.turn_manager.is_player_turn()
			if is_player:
				attacker = GDM.player if typeof(GDM.player) != TYPE_NIL else attacker
				target = GDM.monster_to_fight if typeof(GDM.monster_to_fight) != TYPE_NIL else target
			else:
				attacker = GDM.monster_to_fight if typeof(GDM.monster_to_fight) != TYPE_NIL else attacker
				target = GDM.player if typeof(GDM.player) != TYPE_NIL else target

	# Safe guards
	if not attacker or not target:
		push_warning("Sap_mana.activate_booster: missing attacker or target")
		return

	# Drain amount and damage - tuneable via resource values if desired
	var drain_amount = 5
	var dmg = damage

	# Drain target's mana if supported
	if target.has_method("modify_mana"):
		target.modify_mana(-drain_amount)

	# Give mana to attacker if supported
	if attacker.has_method("modify_mana"):
		attacker.modify_mana(drain_amount)

	# Apply damage to the target via a standard method if available
	if target.has_method("apply_damage"):
		target.apply_damage(dmg, attacker)

	# Trigger the visual effect: use a cool bluish tint for mana siphon
	var color = Color(0.45, 0.6, 1.0, 1.0)
	trigger_visual_effects("on_cast", {"effect_color": color, "intensity": 0.9, "duration": 1.0})
