extends FW_Buff

class_name FW_StabbedDebuff

func _init() -> void:
	name = "Stabbed"
	duration = 99  # Will be set to end at combat end via special handling
	effect_strength = 1  # 1 damage per turn
	stat_target = ""  # No stat target for damage over time
	type = buff_type.discrete
	category = buff_category.harmful
	owner_type = "player"
	caster_type = "environment"  # The munchkin/environment caused this
	log_message = "{caster} stabs {target}, dealing {effect_strength} damage per turn for the duration of combat!"

	# Special flag to indicate this should only last for one combat
	set_meta("combat_only", true)
	set_meta("apply_on_combat_start", true)

func get_caster_name() -> String:
	return "The munchkin"

func get_description() -> String:
	"""Provide custom description for UI"""
	return "Stabbed by the munchkin. Takes 1 damage per turn for this combat."

func apply_per_turn_effects() -> void:
	"""Apply stab damage each turn"""
	duration_left -= 1
	emit_damage_over_time_effect(int(effect_strength), " from stab wound!")
	if duration_left <= 0:
		on_expire()

func get_formatted_log_message(vars: Dictionary = {}) -> String:
	"""Ensure target is correctly set for combat log messages"""
	# Add target if it's missing - this ensures the player name appears correctly
	if not vars.has("target"):
		vars["target"] = get_owner_name()
	return super.get_formatted_log_message(vars)