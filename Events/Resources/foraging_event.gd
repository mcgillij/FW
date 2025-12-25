# foraging_event.gd
extends FW_EventResource

const CHOICE_EXAMINE := "examine"
const CHOICE_GRAB := "grab"
const CHOICE_LEAVE := "leave"

@export var examine_failure_effects: Array[Resource] = []
@export var grab_failure_effects: Array[Resource] = []

func build_view(_context: Dictionary = {}) -> Dictionary:
	var alertness_check := FW_SkillCheckRes.new()
	alertness_check.skill_name = "alertness"
	alertness_check.target = 44
	alertness_check.color = Color(0.384, 0.447, 0.643)

	var reflex_check := FW_SkillCheckRes.new()
	reflex_check.skill_name = "reflex"
	reflex_check.target = 35
	reflex_check.color = Color(0.314, 0.98, 0.482, 1.0)

	var current_alertness := 0
	var current_reflex := 0
	if GDM.player and GDM.player.stats:
		current_alertness = int(GDM.player.stats.get_stat("alertness"))
		current_reflex = int(GDM.player.stats.get_stat("reflex"))

	var alertness_color := "#6272A4"
	var reflex_color := "#50fa7b"
	var alertness_stat_text := "[color=%s]Alertness: %d / %d[/color]" % [alertness_color, current_alertness, alertness_check.target]
	var reflex_stat_text := "[color=%s]Reflex: %d / %d[/color]" % [reflex_color, current_reflex, reflex_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_EXAMINE,
				CHOICE_TEXT_KEY: "Carefully examine and pick berries\n" + alertness_stat_text,
				CHOICE_SKILL_CHECK_KEY: alertness_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_GRAB,
				CHOICE_TEXT_KEY: "Quickly grab what you can\n" + reflex_stat_text,
				CHOICE_SKILL_CHECK_KEY: reflex_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_LEAVE,
				CHOICE_TEXT_KEY: "Leave them alone",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_EXAMINE:
			if skill_success:
				return [true, "You identify safe berries and gain nourishment!"]
			apply_effects(examine_failure_effects)
			return [false, "You pick a poisonous one and feel ill."]
		CHOICE_GRAB:
			if skill_success:
				return [true, "You snatch edible berries before they fall!"]
			apply_effects(grab_failure_effects)
			return [false, "You drop most of them in your haste."]
		CHOICE_LEAVE:
			return [false, "Better safe than sorry - you continue your journey."]
		_:
			return [false, "Something went wrong."]
