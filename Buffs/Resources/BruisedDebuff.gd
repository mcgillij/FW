extends FW_Buff

class_name FW_BruisedDebuff

func _init() -> void:
	name = "Bruised"
	duration = 99  # Will be set to end at combat end via special handling
	effect_strength = -0.1  # -10% damage resistance (increases damage taken)
	stat_target = "damage_resistance"
	type = buff_type.discrete
	category = buff_category.harmful
	owner_type = "player"
	caster_type = "environment"  # The falling rocks/environment caused this
	log_message = "{caster} bruises {target}, reducing damage resistance by {effect_strength_percent} for the duration of combat!"

	# Special flag to indicate this should only last for one combat
	set_meta("combat_only", true)
	set_meta("apply_on_combat_start", true)

func get_caster_name() -> String:
	return "The falling rocks"

func get_description() -> String:
	"""Provide custom description for UI"""
	return "Bruised from falling rocks. Damage resistance reduced by 10% for this combat."

func get_formatted_log_message(vars: Dictionary = {}) -> String:
	"""Ensure target is correctly set for combat log messages"""
	# Add target if it's missing - this ensures the player name appears correctly
	if not vars.has("target"):
		vars["target"] = get_owner_name()
	return super.get_formatted_log_message(vars)
