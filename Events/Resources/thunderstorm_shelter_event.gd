extends FW_EventResource

class_name FW_ThunderstormShelterEvent

const CHOICE_SHELTER := "shelter"
const CHOICE_PUSH_ON := "push_on"
const CHOICE_DANCE := "dance"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var alertness_check := FW_SkillCheckRes.new()
	alertness_check.skill_name = "alertness"
	alertness_check.target = 43
	alertness_check.color = Color(0.384, 0.447, 0.643)

	var vigor_check := FW_SkillCheckRes.new()
	vigor_check.skill_name = "vigor"
	vigor_check.target = 44
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
				CHOICE_ID_KEY: CHOICE_SHELTER,
				CHOICE_TEXT_KEY: "Find a dry shelter nearby\n" + alert_text,
				CHOICE_SKILL_CHECK_KEY: alertness_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_PUSH_ON,
				CHOICE_TEXT_KEY: "Push on through the rain\n" + vigor_text,
				CHOICE_SKILL_CHECK_KEY: vigor_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_DANCE,
				CHOICE_TEXT_KEY: "Splash in puddles until the storm passes",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_SHELTER:
			if skill_success:
				return [true, "You spot an overhang and stay dry. The thunder feels far away now."]
			apply_failure_effects()
			return [false, "You pick a poor spot and wind up drenched and shivering."]
		CHOICE_PUSH_ON:
			if skill_success:
				return [true, "You power through the storm and reach calm skies sooner than expected!"]
			apply_failure_effects()
			return [false, "The wind knocks you around. You arrive tired and sore."]
		CHOICE_DANCE:
			return [true, "It’s cold, but your spirits stay high. The storm passes while you play."]
		_:
			return [false, "Something went wrong."]
