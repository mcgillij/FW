extends FW_EventResource

class_name FW_KindCampfireEvent

const CHOICE_SHARE := "share"
const CHOICE_BEG := "beg"
const CHOICE_SNEAK := "sneak"

func build_view(_context: Dictionary = {}) -> Dictionary:
	var enthusiasm_check := FW_SkillCheckRes.new()
	enthusiasm_check.skill_name = "enthusiasm"
	enthusiasm_check.target = 40
	enthusiasm_check.color = Color(1.0, 0.65, 0.25, 1.0)

	var luck_check := FW_SkillCheckRes.new()
	luck_check.skill_name = "luck"
	luck_check.target = 45
	luck_check.color = Color(0.98, 0.92, 0.3, 1.0)

	var reflex_check := FW_SkillCheckRes.new()
	reflex_check.skill_name = "reflex"
	reflex_check.target = 42
	reflex_check.color = Color(0.314, 0.98, 0.482, 1.0)

	var cur_ent := 0
	var cur_luck := 0
	var cur_ref := 0
	if GDM.player and GDM.player.stats:
		cur_ent = int(GDM.player.stats.get_stat("enthusiasm"))
		cur_luck = int(GDM.player.stats.get_stat("luck"))
		cur_ref = int(GDM.player.stats.get_stat("reflex"))

	var ent_text := "[color=#ffa23f]Enthusiasm: %d / %d[/color]" % [cur_ent, enthusiasm_check.target]
	var luck_text := "[color=#f7e463]Luck: %d / %d[/color]" % [cur_luck, luck_check.target]
	var ref_text := "[color=#50fa7b]Reflex: %d / %d[/color]" % [cur_ref, reflex_check.target]

	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{
				CHOICE_ID_KEY: CHOICE_SHARE,
				CHOICE_TEXT_KEY: "Offer a leaf and a friendly wag\n" + ent_text,
				CHOICE_SKILL_CHECK_KEY: enthusiasm_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_BEG,
				CHOICE_TEXT_KEY: "Sit politely and hope for a snack\n" + luck_text,
				CHOICE_SKILL_CHECK_KEY: luck_check,
			},
			{
				CHOICE_ID_KEY: CHOICE_SNEAK,
				CHOICE_TEXT_KEY: "Sneak a bite when no one is looking\n" + ref_text,
				CHOICE_SKILL_CHECK_KEY: reflex_check,
			},
		],
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	match str(choice.get(CHOICE_ID_KEY, "")):
		CHOICE_SHARE:
			if skill_success:
				return [true, "The traveler laughs and shares a warm meal. You feel ready for anything."]
			apply_failure_effects()
			return [false, "You try your best, but the traveler misunderstands and shoos you away."]
		CHOICE_BEG:
			if skill_success:
				return [true, "Luck is on your side. A tasty morsel lands right at your paws!"]
			apply_failure_effects()
			return [false, "No luck this time. Your stomach grumbles louder than the fire." ]
		CHOICE_SNEAK:
			if skill_success:
				return [true, "Quick as lightning, you snag a snack and slip away unseen!"]
			apply_failure_effects()
			return [false, "A twig snaps underfoot. Embarrassing. You retreat without a prize."]
		_:
			return [false, "Something went wrong."]
