extends FW_EventResource

class_name FW_SquirrelStashEvent

const CHOICE_CHASE := "chase"
const CHOICE_SNIFF := "sniff"
const CHOICE_SHARE := "share"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var reflex_check := FW_SkillCheckRes.new()
	reflex_check.skill_name = "reflex"
	reflex_check.target = 38
	reflex_check.color = Color(0.314, 0.98, 0.482, 1.0)

	var alertness_check := FW_SkillCheckRes.new()
	alertness_check.skill_name = "alertness"
	alertness_check.target = 42
	alertness_check.color = Color(0.384, 0.447, 0.643)

	var current_reflex := 0
	var current_alertness := 0
	if GDM.player and GDM.player.stats:
		current_reflex = int(GDM.player.stats.get_stat("reflex"))
		current_alertness = int(GDM.player.stats.get_stat("alertness"))

	var reflex_text := "[color=#50fa7b]Reflex: %d / %d[/color]" % [current_reflex, reflex_check.target]
	var alert_text := "[color=#6272A4]Alertness: %d / %d[/color]" % [current_alertness, alertness_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_CHASE,
				CHOICE_TEXT_KEY: "Chase the squirrel up the tree\n" + reflex_text,
				CHOICE_SKILL_CHECK_KEY: reflex_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_SNIFF,
				CHOICE_TEXT_KEY: "Sniff out where it hid the stash\n" + alert_text,
				CHOICE_SKILL_CHECK_KEY: alertness_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_SHARE,
				CHOICE_TEXT_KEY: "Sit calmly and offer a friendly tail wag",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_CHASE:
			if skill_success:
				return [true, "You scramble up after the squirrel and it drops a shiny trinket as it flees!"]
			apply_failure_effects()
			return [false, "You slip on the bark and tumble back down. Ouch."]
		CHOICE_SNIFF:
			if skill_success:
				return [true, "Your nose leads you to a hidden stash: a treat wrapped in a leaf!"]
			apply_failure_effects()
			return [false, "You sniff too close and get a faceful of dust. The squirrel escapes giggling."]
		CHOICE_SHARE:
			return [true, "The squirrel pauses, impressed by your manners, and leaves a small snack behind."]
		_:
			return [false, "Something went wrong."]
