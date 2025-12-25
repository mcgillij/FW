extends FW_EventResource

class_name FW_BarkEvent

const CHOICE_INTIMIDATE := "intimidate"
const CHOICE_SNEAK := "sneak"

func build_view(_context: Dictionary = {}) -> Dictionary:
	# Create a skill check resource for bark
	var skill_check_res := FW_SkillCheckRes.new()
	skill_check_res.skill_name = "bark"
	skill_check_res.target = 40
	skill_check_res.color = Color(1.0, 0.333, 0.333)

	var current_bark := 0
	if GDM.player and GDM.player.stats:
		current_bark = int(GDM.player.stats.get_stat("bark"))
	var bark_color := "#FF5555"
	var stat_text := "[color=%s]Bark: %d / %d[/color]" % [bark_color, current_bark, skill_check_res.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_INTIMIDATE,
				CHOICE_TEXT_KEY: "Intimidate the wolf with a fierce bark\n" + stat_text,
				CHOICE_SKILL_CHECK_KEY: skill_check_res,
			},
			{
				CHOICE_ID_KEY: CHOICE_SNEAK,
				CHOICE_TEXT_KEY: "Try to sneak past quietly",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_INTIMIDATE:
			if skill_success:
				return [true, "Your powerful bark cowers the wolf, allowing you to pass safely!"]
			apply_failure_effects()
			return [false, "The wolf snarls back and lunges at you! You barely escape but your leg is injured, hampering your movement."]
		CHOICE_SNEAK:
			return [false, "You manage to slip past the wolf unnoticed."]
		_:
			return [false, "Something went wrong."]
