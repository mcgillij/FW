extends FW_EventResource

class_name FW_LostCollarTagEvent

const CHOICE_DIG := "dig"
const CHOICE_SNIFF := "sniff"
const CHOICE_IGNORE := "ignore"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var luck_check := FW_SkillCheckRes.new()
	luck_check.skill_name = "luck"
	luck_check.target = 44
	luck_check.color = Color(0.98, 0.92, 0.3, 1.0)

	var alertness_check := FW_SkillCheckRes.new()
	alertness_check.skill_name = "alertness"
	alertness_check.target = 40
	alertness_check.color = Color(0.384, 0.447, 0.643)

	var cur_luck := 0
	var cur_alert := 0
	if GDM.player and GDM.player.stats:
		cur_luck = int(GDM.player.stats.get_stat("luck"))
		cur_alert = int(GDM.player.stats.get_stat("alertness"))

	var luck_text := "[color=#f7e463]Luck: %d / %d[/color]" % [cur_luck, luck_check.target]
	var alert_text := "[color=#6272A4]Alertness: %d / %d[/color]" % [cur_alert, alertness_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_DIG,
				CHOICE_TEXT_KEY: "Dig where the tag is half-buried\n" + luck_text,
				CHOICE_SKILL_CHECK_KEY: luck_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_SNIFF,
				CHOICE_TEXT_KEY: "Sniff around for a trail\n" + alert_text,
				CHOICE_SKILL_CHECK_KEY: alertness_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_IGNORE,
				CHOICE_TEXT_KEY: "Leave it and keep moving",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_DIG:
			if skill_success:
				return [true, "You unearth a lost collar tag… and tucked beneath it, a hidden treat!"]
			apply_failure_effects()
			return [false, "You dig and dig, but hit a sharp rock and yelp. No treasure today."]
		CHOICE_SNIFF:
			if skill_success:
				return [true, "The scent leads to a small pouch snagged on a branch. Jackpot!"]
			apply_failure_effects()
			return [false, "The trail is too faint. You circle in frustration until you give up."]
		CHOICE_IGNORE:
			return [false, "You decide not to get distracted. The road calls."]
		_:
			return [false, "Something went wrong."]
