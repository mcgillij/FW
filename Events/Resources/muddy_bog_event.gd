extends FW_EventResource

class_name FW_MuddyBogEvent

const CHOICE_STONES := "stones"
const CHOICE_SPRINT := "sprint"
const CHOICE_DETOUR := "detour"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var alertness_check := FW_SkillCheckRes.new()
	alertness_check.skill_name = "alertness"
	alertness_check.target = 40
	alertness_check.color = Color(0.384, 0.447, 0.643)

	var vigor_check := FW_SkillCheckRes.new()
	vigor_check.skill_name = "vigor"
	vigor_check.target = 42
	vigor_check.color = Color(0.95, 0.75, 0.35, 1.0)

	var current_alertness := 0
	var current_vigor := 0
	if GDM.player and GDM.player.stats:
		current_alertness = int(GDM.player.stats.get_stat("alertness"))
		current_vigor = int(GDM.player.stats.get_stat("vigor"))

	var alert_text := "[color=#6272A4]Alertness: %d / %d[/color]" % [current_alertness, alertness_check.target]
	var vigor_text := "[color=#f1c40f]Vigor: %d / %d[/color]" % [current_vigor, vigor_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_STONES,
				CHOICE_TEXT_KEY: "Pick safe stones to hop across\n" + alert_text,
				CHOICE_SKILL_CHECK_KEY: alertness_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_SPRINT,
				CHOICE_TEXT_KEY: "Sprint through the mud and hope for the best\n" + vigor_text,
				CHOICE_SKILL_CHECK_KEY: vigor_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_DETOUR,
				CHOICE_TEXT_KEY: "Take a long detour around the bog",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_STONES:
			if skill_success:
				return [true, "You hop from stone to stone and stay clean and quick-footed!"]
			apply_failure_effects()
			return [false, "A stone sinks and you splash into the mud. You're sore and soaked."]
		CHOICE_SPRINT:
			if skill_success:
				return [true, "You blast through the muck and burst out the other side like a champion!"]
			apply_failure_effects()
			return [false, "The mud grabs your paws and you strain your legs getting free."]
		CHOICE_DETOUR:
			return [false, "You play it safe, but the detour costs time and you find nothing of value."]
		_:
			return [false, "Something went wrong."]
