extends FW_EventResource

class_name FW_OldRopeBridgeEvent

const CHOICE_CROSS := "cross"
const CHOICE_CRAWL := "crawl"
const CHOICE_TURN_BACK := "turn_back"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var reflex_check := FW_SkillCheckRes.new()
	reflex_check.skill_name = "reflex"
	reflex_check.target = 45
	reflex_check.color = Color(0.314, 0.98, 0.482, 1.0)

	var alertness_check := FW_SkillCheckRes.new()
	alertness_check.skill_name = "alertness"
	alertness_check.target = 41
	alertness_check.color = Color(0.384, 0.447, 0.643)

	var cur_ref := 0
	var cur_alert := 0
	if GDM.player and GDM.player.stats:
		cur_ref = int(GDM.player.stats.get_stat("reflex"))
		cur_alert = int(GDM.player.stats.get_stat("alertness"))

	var ref_text := "[color=#50fa7b]Reflex: %d / %d[/color]" % [cur_ref, reflex_check.target]
	var alert_text := "[color=#6272A4]Alertness: %d / %d[/color]" % [cur_alert, alertness_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_CROSS,
				CHOICE_TEXT_KEY: "Cross quickly before it snaps\n" + ref_text,
				CHOICE_SKILL_CHECK_KEY: reflex_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_CRAWL,
				CHOICE_TEXT_KEY: "Crawl slowly, testing each plank\n" + alert_text,
				CHOICE_SKILL_CHECK_KEY: alertness_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_TURN_BACK,
				CHOICE_TEXT_KEY: "Turn back and look for another path",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_CROSS:
			if skill_success:
				return [true, "You dash across as the ropes creak. On the other side, you strike a proud pose."]
			apply_failure_effects()
			return [false, "A plank breaks and you slam into the ropes. You make it, but bruised and shaken."]
		CHOICE_CRAWL:
			if skill_success:
				return [true, "Slow and steady wins. You reach the other side without a single slip."]
			apply_failure_effects()
			return [false, "You choose a bad plank and it gives way. You scramble up, sore and embarrassed."]
		CHOICE_TURN_BACK:
			return [false, "You avoid the bridge, but the detour is long and you find nothing special."]
		_:
			return [false, "Something went wrong."]
