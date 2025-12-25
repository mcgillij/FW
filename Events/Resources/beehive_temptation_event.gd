extends FW_EventResource

class_name FW_BeehiveTemptationEvent

const CHOICE_LICK := "lick"
const CHOICE_POKE := "poke"
const CHOICE_BACK_AWAY := "back_away"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var luck_check := FW_SkillCheckRes.new()
	luck_check.skill_name = "luck"
	luck_check.target = 46
	luck_check.color = Color(0.98, 0.92, 0.3, 1.0)

	var reflex_check := FW_SkillCheckRes.new()
	reflex_check.skill_name = "reflex"
	reflex_check.target = 44
	reflex_check.color = Color(0.314, 0.98, 0.482, 1.0)

	var cur_luck := 0
	var cur_ref := 0
	if GDM.player and GDM.player.stats:
		cur_luck = int(GDM.player.stats.get_stat("luck"))
		cur_ref = int(GDM.player.stats.get_stat("reflex"))

	var luck_text := "[color=#f7e463]Luck: %d / %d[/color]" % [cur_luck, luck_check.target]
	var ref_text := "[color=#50fa7b]Reflex: %d / %d[/color]" % [cur_ref, reflex_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_LICK,
				CHOICE_TEXT_KEY: "Try a tiny lick of honey\n" + luck_text,
				CHOICE_SKILL_CHECK_KEY: luck_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_POKE,
				CHOICE_TEXT_KEY: "Swat the hive and run\n" + ref_text,
				CHOICE_SKILL_CHECK_KEY: reflex_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_BACK_AWAY,
				CHOICE_TEXT_KEY: "Back away slowly and resist temptation",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_LICK:
			if skill_success:
				return [true, "Sweet victory! You get a perfect lick of honey without angering the bees."]
			apply_failure_effects()
			return [false, "The bees notice. You flee with a stinging reminder not to be greedy."]
		CHOICE_POKE:
			if skill_success:
				return [true, "You swat and dash! The bees chase, but you zig-zag away and keep your prize."]
			apply_failure_effects()
			return [false, "You trip mid-sprint. The bees catch up. Ouch, ouch, ouch."]
		CHOICE_BACK_AWAY:
			return [true, "You leave the hive alone. Sometimes the bravest choice is walking away."]
		_:
			return [false, "Something went wrong."]
