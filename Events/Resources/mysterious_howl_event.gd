extends FW_EventResource

class_name FW_MysteriousHowlEvent

const CHOICE_HOWL := "howl"
const CHOICE_HIDE := "hide"
const CHOICE_BEFriend := "befriend"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var bark_check := FW_SkillCheckRes.new()
	bark_check.skill_name = "bark"
	bark_check.target = 42
	bark_check.color = Color(0.85, 0.85, 0.95, 1.0)

	var alertness_check := FW_SkillCheckRes.new()
	alertness_check.skill_name = "alertness"
	alertness_check.target = 44
	alertness_check.color = Color(0.384, 0.447, 0.643)

	var enthusiasm_check := FW_SkillCheckRes.new()
	enthusiasm_check.skill_name = "enthusiasm"
	enthusiasm_check.target = 41
	enthusiasm_check.color = Color(1.0, 0.65, 0.25, 1.0)

	var cur_bark := 0
	var cur_alert := 0
	var cur_ent := 0
	if GDM.player and GDM.player.stats:
		cur_bark = int(GDM.player.stats.get_stat("bark"))
		cur_alert = int(GDM.player.stats.get_stat("alertness"))
		cur_ent = int(GDM.player.stats.get_stat("enthusiasm"))

	var bark_text := "[color=#dfe3ff]Bark: %d / %d[/color]" % [cur_bark, bark_check.target]
	var alert_text := "[color=#6272A4]Alertness: %d / %d[/color]" % [cur_alert, alertness_check.target]
	var ent_text := "[color=#ffa23f]Enthusiasm: %d / %d[/color]" % [cur_ent, enthusiasm_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_HOWL,
				CHOICE_TEXT_KEY: "Howl back bravely\n" + bark_text,
				CHOICE_SKILL_CHECK_KEY: bark_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_HIDE,
				CHOICE_TEXT_KEY: "Hide and listen closely\n" + alert_text,
				CHOICE_SKILL_CHECK_KEY: alertness_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_BEFriend,
				CHOICE_TEXT_KEY: "Approach with friendly excitement\n" + ent_text,
				CHOICE_SKILL_CHECK_KEY: enthusiasm_check,
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_HOWL:
			if skill_success:
				return [true, "Your howl echoes strong. The distant caller quiets… and leaves a gift of safe passage."]
			apply_failure_effects()
			return [false, "Your howl cracks. The forest answers with laughter, and your confidence takes a hit."]
		CHOICE_HIDE:
			if skill_success:
				return [true, "You spot a harmless critter practicing scary noises. You relax and move on."]
			apply_failure_effects()
			return [false, "You wait too long in the cold. The sound fades, but you feel stiff and uneasy."]
		CHOICE_BEFriend:
			if skill_success:
				return [true, "It was another wandering pet! You share a moment, then part ways with smiles."]
			apply_failure_effects()
			return [false, "You rush in and spook it. The awkward moment lingers as you walk away."]
		_:
			return [false, "Something went wrong."]
