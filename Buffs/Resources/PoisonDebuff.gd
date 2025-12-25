extends FW_Buff

class_name FW_PoisonDebuff

func _init() -> void:
	name = "Poisoned"
	duration = 99  # Will be set to end at combat end via special handling
	effect_strength = 2  # 2 damage per round
	stat_target = ""  # No stat target for damage over time
	type = buff_type.discrete
	category = buff_category.harmful
	owner_type = "player"
	caster_type = "environment"  # The poisonous berries/environment caused this
	log_message = "{caster} poisons {target}, dealing {effect_strength} damage per round for the duration of combat!"

	# Special flag to indicate this should only last for one combat
	set_meta("combat_only", true)
	set_meta("apply_on_combat_start", true)

func get_caster_name() -> String:
	return "The poisonous berries"

func get_description() -> String:
	"""Provide custom description for UI"""
	return "Poisoned by bad berries. Takes 2 damage per round for this combat."

func apply_per_turn_effects() -> void:
	"""Apply poison damage each round"""
	duration_left -= 1
	emit_damage_over_time_effect(int(effect_strength), "from poison!")
	if duration_left <= 0:
		on_expire()

func get_formatted_log_message(vars: Dictionary = {}) -> String:
	"""Ensure target is correctly set for combat log messages"""
	# Add target if it's missing - this ensures the player name appears correctly
	if not vars.has("target"):
		vars["target"] = get_owner_name()
	return super.get_formatted_log_message(vars)
