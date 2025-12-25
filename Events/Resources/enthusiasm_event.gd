# enthusiasm_event.gd
extends FW_EventResource

const CHOICE_SPEECH := "speech"
const CHOICE_ENCOURAGE := "encourage"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var skill_check_res := FW_SkillCheckRes.new()
	skill_check_res.skill_name = "enthusiasm"
	skill_check_res.target = 44
	skill_check_res.color = Color(1.0, 0.475, 0.776)

	var current_enthusiasm := 0
	if GDM.player and GDM.player.stats:
		current_enthusiasm = int(GDM.player.stats.get_stat("enthusiasm"))
	var enthusiasm_color := "#FF79C6"
	var stat_text := "[color=%s]Enthusiasm: %d / %d[/color]" % [enthusiasm_color, current_enthusiasm, skill_check_res.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_SPEECH,
				CHOICE_TEXT_KEY: "Give an inspiring speech\n" + stat_text,
				CHOICE_SKILL_CHECK_KEY: skill_check_res,
			},
			{
				CHOICE_ID_KEY: CHOICE_ENCOURAGE,
				CHOICE_TEXT_KEY: "Offer quiet encouragement",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_SPEECH:
			if skill_success:
				return [true, "Your enthusiastic speech rallies everyone, boosting morale and providing bonuses!"]
			apply_failure_effects()
			return [false, "Your speech falls flat, leaving everyone feeling more discouraged."]
		CHOICE_ENCOURAGE:
			apply_failure_effects()
			return [false, "Your quiet words provide some comfort, though not as impactful."]
		_:
			return [false, "Something went wrong."]
