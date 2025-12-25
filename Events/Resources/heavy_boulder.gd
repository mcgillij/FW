extends FW_EventResource

class_name FW_TestEvent

const CHOICE_PUSH := "push"
const CHOICE_AROUND := "around"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var skill_check_res := FW_SkillCheckRes.new()
	skill_check_res.skill_name = "vigor"
	skill_check_res.target = 35
	skill_check_res.color = Color(1.0, 0.722, 0.424)

	var current_vigor := 0
	if GDM.player and GDM.player.stats:
		current_vigor = int(GDM.player.stats.get_stat("vigor"))
	var vigor_color := "#FFB86C"
	var stat_text := "[color=%s]Vigor: %d / %d[/color]" % [vigor_color, current_vigor, skill_check_res.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_PUSH,
				CHOICE_TEXT_KEY: "Attempt to move the boulder\n" + stat_text,
				CHOICE_SKILL_CHECK_KEY: skill_check_res,
			},
			{
				CHOICE_ID_KEY: CHOICE_AROUND,
				CHOICE_TEXT_KEY: "Look for another way around",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_PUSH:
			if skill_success:
				return [true, "With your mighty vigor, you push the boulder aside and clear the path!"]
			apply_failure_effects()
			return [false, "Despite your efforts, the boulder doesn't budge. You take some damage from the strain."]
		CHOICE_AROUND:
			return [false, "You find a narrow path around the boulder, avoiding the obstacle."]
		_:
			return [false, "Something went wrong."]
