extends FW_EventResource

class_name FW_AncientTreatShrineEvent

const CHOICE_OFFER := "offer"
const CHOICE_PRAY := "pray"
const CHOICE_SNATCH := "snatch"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var enthusiasm_check := FW_SkillCheckRes.new()
	enthusiasm_check.skill_name = "enthusiasm"
	enthusiasm_check.target = 42
	enthusiasm_check.color = Color(1.0, 0.65, 0.25, 1.0)

	var luck_check := FW_SkillCheckRes.new()
	luck_check.skill_name = "luck"
	luck_check.target = 47
	luck_check.color = Color(0.98, 0.92, 0.3, 1.0)

	var cur_ent := 0
	var cur_luck := 0
	if GDM.player and GDM.player.stats:
		cur_ent = int(GDM.player.stats.get_stat("enthusiasm"))
		cur_luck = int(GDM.player.stats.get_stat("luck"))

	var ent_text := "[color=#ffa23f]Enthusiasm: %d / %d[/color]" % [cur_ent, enthusiasm_check.target]
	var luck_text := "[color=#f7e463]Luck: %d / %d[/color]" % [cur_luck, luck_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_OFFER,
				CHOICE_TEXT_KEY: "Leave a small offering (a leaf, a pebble)\n" + ent_text,
				CHOICE_SKILL_CHECK_KEY: enthusiasm_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_PRAY,
				CHOICE_TEXT_KEY: "Sit quietly and wish for good fortune\n" + luck_text,
				CHOICE_SKILL_CHECK_KEY: luck_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_SNATCH,
				CHOICE_TEXT_KEY: "Grab the treats immediately",
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_OFFER:
			if skill_success:
				return [true, "A warm feeling spreads through you. A treat appears as if the shrine approves."]
			apply_failure_effects()
			return [false, "Nothing happens… and the silence feels judgmental. You slink away."]
		CHOICE_PRAY:
			if skill_success:
				return [true, "Fortune smiles. You find a hidden compartment full of snacks!"]
			apply_failure_effects()
			return [false, "You wait and wait. Your paws go numb and the moment passes."]
		CHOICE_SNATCH:
			apply_failure_effects()
			return [false, "The shrine rumbles. Your greed earns you a nasty curse of bad luck."]
		_:
			return [false, "Something went wrong."]
