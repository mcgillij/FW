# alertness_event.gd
extends FW_EventResource

const CHOICE_INSPECT := "inspect"
const CHOICE_PROCEED := "proceed"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var skill_check_res := FW_SkillCheckRes.new()
	skill_check_res.skill_name = "alertness"
	skill_check_res.target = 45
	skill_check_res.color = Color(0.384, 0.447, 0.643)

	var current_alertness := 0
	if GDM.player and GDM.player.stats:
		current_alertness = int(GDM.player.stats.get_stat("alertness"))
	var alertness_color := "#6272A4"
	var stat_text := "[color=%s]Alertness: %d / %d[/color]" % [alertness_color, current_alertness, skill_check_res.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_INSPECT,
				CHOICE_TEXT_KEY: "Carefully inspect for traps\n" + stat_text,
				CHOICE_SKILL_CHECK_KEY: skill_check_res,
			},
			{
				CHOICE_ID_KEY: CHOICE_PROCEED,
				CHOICE_TEXT_KEY: "Proceed cautiously without checking",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_INSPECT:
			if skill_success:
				return [true, "Your keen alertness reveals the trap, allowing you to safely navigate around it!"]
			apply_failure_effects()
			return [false, "You miss the trap and fall in, leaving you feeling clumsy and accident-prone."]
		CHOICE_PROCEED:
			apply_failure_effects()
			return [false, "You step into the trap and suffer injuries from the fall, leaving you clumsy."]
		_:
			return [false, "Something went wrong."]
