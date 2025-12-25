extends FW_EventResource

const CHOICE_PREFIX := "path:"

const OPTIONS: Array[String] = [
	"A narrow icy bridge",
	"A snow-covered detour through the woods",
	"A cracking trail across the open lake"
]

func _correct_path(context: Dictionary) -> String:
	var rng := make_deterministic_rng(context, "frozen_lake")
	return OPTIONS[rng.randi_range(0, OPTIONS.size() - 1)]

func build_view(context: Dictionary = {}) -> Dictionary:
	var rng := make_deterministic_rng(context, "frozen_lake_shuffle")
	var shuffled := shuffled_copy(OPTIONS, rng)
	var view_choices: Array[Dictionary] = []
	for opt in shuffled:
		view_choices.append({
			CHOICE_ID_KEY: CHOICE_PREFIX + opt,
			CHOICE_TEXT_KEY: opt,
		})
	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: view_choices,
	}

func resolve_choice(choice: Dictionary, _skill_success: bool, context: Dictionary = {}) -> Array:
	var correct := _correct_path(context)
	var picked_text := str(choice.get(CHOICE_TEXT_KEY, choice.get("choice", "")))
	if picked_text == correct:
		return [true, "The Pomeranian bounds ahead safely! A hidden fish under the ice even smiles."]
	return [false, "The path was tricky... the little dog yelps but learns something important."]
