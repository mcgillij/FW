extends FW_EventResource

class_name FW_ReflexEvent

const CHOICE_DODGE := "dodge"
const CHOICE_WAIT := "wait"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var skill_check_res := FW_SkillCheckRes.new()
	skill_check_res.skill_name = "reflex"
	skill_check_res.target = 43
	skill_check_res.color = Color(0.314, 0.98, 0.482, 1.0)

	var current_reflex := 0
	if GDM.player and GDM.player.stats:
		current_reflex = int(GDM.player.stats.get_stat("reflex"))
	var reflex_color := "#50fa7bff"
	var stat_text := "[color=%s]Reflex: %d / %d[/color]" % [reflex_color, current_reflex, skill_check_res.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_DODGE,
				CHOICE_TEXT_KEY: "Dodge through the falling rocks\n" + stat_text,
				CHOICE_SKILL_CHECK_KEY: skill_check_res,
			},
			{
				CHOICE_ID_KEY: CHOICE_WAIT,
				CHOICE_TEXT_KEY: "Wait for the rocks to stop falling",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_DODGE:
			if skill_success:
				return [true, "Your lightning reflexes allow you to weave through the rocks unharmed!"]
			apply_failure_effects()
			return [false, "A rock hits you, causing some damage as you scramble to safety."]
		CHOICE_WAIT:
			return [false, "After waiting patiently, the rocks settle and you proceed cautiously."]
		_:
			return [false, "Something went wrong."]
