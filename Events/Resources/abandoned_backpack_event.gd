extends FW_EventResource

class_name FW_AbandonedBackpackEvent

const CHOICE_OPEN := "open"
const CHOICE_DRAG := "drag"
const CHOICE_LEAVE := "leave"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var alertness_check := FW_SkillCheckRes.new()
	alertness_check.skill_name = "alertness"
	alertness_check.target = 42
	alertness_check.color = Color(0.384, 0.447, 0.643)

	var vigor_check := FW_SkillCheckRes.new()
	vigor_check.skill_name = "vigor"
	vigor_check.target = 43
	vigor_check.color = Color(0.95, 0.75, 0.35, 1.0)

	var cur_alert := 0
	var cur_vigor := 0
	if GDM.player and GDM.player.stats:
		cur_alert = int(GDM.player.stats.get_stat("alertness"))
		cur_vigor = int(GDM.player.stats.get_stat("vigor"))

	var alert_text := "[color=#6272A4]Alertness: %d / %d[/color]" % [cur_alert, alertness_check.target]
	var vigor_text := "[color=#f1c40f]Vigor: %d / %d[/color]" % [cur_vigor, vigor_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_OPEN,
				CHOICE_TEXT_KEY: "Open it carefully\n" + alert_text,
				CHOICE_SKILL_CHECK_KEY: alertness_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_DRAG,
				CHOICE_TEXT_KEY: "Drag it into the open and rummage\n" + vigor_text,
				CHOICE_SKILL_CHECK_KEY: vigor_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_LEAVE,
				CHOICE_TEXT_KEY: "Leave it alone. Could be trouble.",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_OPEN:
			if skill_success:
				return [true, "You open it gently and find supplies… plus a delicious snack tucked in a pocket!"]
			apply_failure_effects()
			return [false, "A strap snaps back and smacks your nose. You recoil, embarrassed and aching."]
		CHOICE_DRAG:
			if skill_success:
				return [true, "You haul it free and shake out goodies. Practical loot for a brave traveler!"]
			apply_failure_effects()
			return [false, "It’s heavier than it looks. You strain yourself and end up with nothing."]
		CHOICE_LEAVE:
			return [false, "You decide not to risk it. Sometimes caution is the best companion."]
		_:
			return [false, "Something went wrong."]
