extends FW_Buff

class_name FW_ClumsyDebuff

func _init() -> void:
	name = "Clumsy"
	duration = 99  # Will be set to end at combat end via special handling
	effect_strength = -0.1  # -10% critical strike chance and evasion chance
	stat_target = "critical_strike_chance"  # Primary target: critical strike chance
	type = buff_type.discrete
	category = buff_category.harmful
	owner_type = "player"
	caster_type = "environment"  # The trap/environment caused this
	log_message = "{caster} causes {target} to feel clumsy, reducing critical strike chance and evasion by {effect_strength_percent} for the duration of combat!"

	# Special flag to indicate this should only last for one combat
	set_meta("combat_only", true)
	set_meta("apply_on_combat_start", true)

func get_caster_name() -> String:
	return "The hidden trap"

func get_description() -> String:
	"""Provide custom description for UI"""
	return "Clumsy from falling into trap. Critical strike chance and evasion reduced by 10% for this combat."

func activate() -> void:
	"""Apply the stat reductions when the buff activates"""
	super.activate()
	# Apply additional stat reduction for evasion_chance
	if owner_type == "player":
		GDM.player.stats.apply_temporary_bonus("evasion_chance", effect_strength)
	else:
		# For monsters, we'd need to handle this differently
		pass

func on_expire() -> void:
	"""Clean up when the buff expires"""
	super.on_expire()
	# Clean up the evasion_chance bonus
	if owner_type == "player":
		GDM.player.stats._on_temporary_bonus_timeout("evasion_chance", effect_strength)
	else:
		# For monsters, we'd need to handle this differently
		pass