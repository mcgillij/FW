extends FW_Buff

class_name FW_CursedLuckDebuff

func _init() -> void:
	name = "Cursed Luck"
	duration = 99  # Will be set to end at combat end via special handling
	effect_strength = -0.15  # -15% luck
	stat_target = "luck"
	type = buff_type.discrete
	category = buff_category.harmful
	owner_type = "player"
	caster_type = "environment"  # The trapped chest/environment caused this
	log_message = "{caster} curses {target}'s luck, reducing luck by {effect_strength_percent} for the duration of combat!"

	# Special flag to indicate this should only last for one combat
	set_meta("combat_only", true)
	set_meta("apply_on_combat_start", true)

func get_caster_name() -> String:
	return "The trapped chest"

func get_description() -> String:
	"""Provide custom description for UI"""
	return "Cursed by a trapped chest. Luck reduced by 15% for this combat."

func get_formatted_log_message(vars: Dictionary = {}) -> String:
	"""Ensure target is correctly set for combat log messages"""
	# Add target if it's missing - this ensures the player name appears correctly
	if not vars.has("target"):
		vars["target"] = get_owner_name()
	return super.get_formatted_log_message(vars)