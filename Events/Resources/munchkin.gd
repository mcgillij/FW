extends FW_EventResource

const CHOICE_LEFT := "left"
const CHOICE_RIGHT := "right"

func _winning_choice_id(context: Dictionary) -> String:
	var rng := make_deterministic_rng(context, "munchkin")
	return CHOICE_LEFT if rng.randi_range(0, 1) == 0 else CHOICE_RIGHT

func build_view(_context: Dictionary = {}) -> Dictionary:
	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: [
			{ CHOICE_ID_KEY: CHOICE_LEFT, CHOICE_TEXT_KEY: "Left" },
			{ CHOICE_ID_KEY: CHOICE_RIGHT, CHOICE_TEXT_KEY: "Right" },
		],
	}

func resolve_choice(choice: Dictionary, _skill_success: bool, context: Dictionary = {}) -> Array:
	var winning_id := _winning_choice_id(context)
	var picked_id := str(choice.get(CHOICE_ID_KEY, ""))
	if picked_id == winning_id:
		return [true, "You win the munchkin's game and gain a small reward!"]
	apply_failure_effects()
	return [false, "The munchkin stabs you with a tiny dagger!"]
