extends FW_EventResource

class_name FW_TresureEvent

const CHOICE_OPEN := "open"
const CHOICE_WAIT := "wait"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var skill_check_res := FW_SkillCheckRes.new()
	skill_check_res.skill_name = "luck"
	skill_check_res.target = 55
	skill_check_res.color = Color(0.945, 0.98, 0.549, 1.0)

	var current_luck := 0
	if GDM.player and GDM.player.stats:
		current_luck = int(GDM.player.stats.get_stat("luck"))
	var luck_color := "#f1fa8c"
	var stat_text := "[color=%s]Luck: %d / %d[/color]" % [luck_color, current_luck, skill_check_res.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_OPEN,
				CHOICE_TEXT_KEY: "Open the chest!\n" + stat_text,
				CHOICE_SKILL_CHECK_KEY: skill_check_res,
			},
			{
				CHOICE_ID_KEY: CHOICE_WAIT,
				CHOICE_TEXT_KEY: "Wait it could be trapped!!!",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_OPEN:
			if skill_success:
				return [true, "You were lucky — there's treasure inside!"]
			apply_failure_effects()
			return [false, "The chest was trapped! You take some damage."]
		CHOICE_WAIT:
			return [false, "You leave all that treasure behind!"]
		_:
			return [false, "Something went wrong."]
