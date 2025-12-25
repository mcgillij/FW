extends FW_Buff

class_name FW_ButterpawsDebuff

func _init() -> void:
	name = "Butterpaws"
	duration = 99  # Will be set to end at combat end via special handling
	effect_strength = -20  # -20 shields
	stat_target = "shields"  # Target shields stat
	type = buff_type.discrete
	category = buff_category.harmful
	owner_type = "player"
	caster_type = "environment"  # The dropped berries/environment caused this
	log_message = "{caster} causes {target} to have butterpaws, reducing shields by {effect_strength} for the duration of combat!"

	# Special flag to indicate this should only last for one combat
	set_meta("combat_only", true)
	set_meta("apply_on_combat_start", true)

func get_caster_name() -> String:
	return "The dropped berries"

func get_description() -> String:
	"""Provide custom description for UI"""
	return "Butterpaws from dropping berries. Shields reduced by 20 for this combat."

func activate() -> void:
	"""Apply the shield reduction when the buff activates"""
	super.activate()
	# Reduce shields immediately when buff is applied
	if owner_type == "player":
		GDM.effect_manager.add_shields(int(effect_strength), true)
		EventBus.do_player_gain_shields.emit(int(effect_strength), texture, GDM.player.character.name)
	else:
		GDM.effect_manager.add_shields(int(effect_strength), false)
		EventBus.do_monster_gain_shields.emit(int(effect_strength), texture, GDM.monster_to_fight.name)

func get_formatted_log_message(vars: Dictionary = {}) -> String:
	"""Ensure target is correctly set for combat log messages"""
	# Add target if it's missing - this ensures the player name appears correctly
	if not vars.has("target"):
		vars["target"] = get_owner_name()
	return super.get_formatted_log_message(vars)