extends FW_Buff

class_name FW_DiscouragedDebuff

func _init() -> void:
	name = "Discouraged"
	duration = 99  # Will be set to end at combat end via special handling
	effect_strength = -0.1  # -10% enthusiasm
	stat_target = "enthusiasm"  # Target enthusiasm stat
	type = buff_type.discrete
	category = buff_category.harmful
	owner_type = "player"
	caster_type = "environment"  # The failed speech/environment caused this
	log_message = "{caster} leaves {target} feeling discouraged, reducing enthusiasm by {effect_strength_percent} for the duration of combat!"

	# Special flag to indicate this should only last for one combat
	set_meta("combat_only", true)
	set_meta("apply_on_combat_start", true)

func get_caster_name() -> String:
	return "The failed motivational speech"

func get_description() -> String:
	"""Provide custom description for UI"""
	return "Discouraged from failed speech. Enthusiasm reduced by 10% for this combat."