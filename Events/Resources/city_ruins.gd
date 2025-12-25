extends FW_EventResource
var riddles: Array[Dictionary] = [
	{
		"question": "Amid the ruins, statues three,\nEach turned toward eternity.\nOne looks east, one west, one down,\nOne hides secrets beneath its frown.\n\nWhich direction hides the ancient clue?",
		"correct": "Down",
		"choices": ["Down", "East", "West"]
	},
	{
		"question": "The Pomeranian finds three archways tall,\nEach marked with a different symbol.\n\nOne way forward leads to light,\nThe others end in endless night.\n\nWhich arch should they walk through?",
		"correct": "A pawprint carved beside a mill",
		"choices": ["A pawprint carved beside a mill", "A tower cracked but standing still", "A sun half-set behind a hill"]
	},
	{
		"question": "In the center of the shattered square,\nVoices rise from empty air.\nEach speaks a phrase, soft and strange—\nBut one warns of a coming change.\n\nWhich whisper should the pup heed?",
		"correct": "Leave now or be made hollow.",
		"choices": ["Leave now or be made hollow.", "Stone forgets, but shadows know.", "Time bends where silence grows."]
	},
	{
		"question": "Amid the ruins lie broken tomes,\nAnd three doorways made of stone.\nEach marked with glyphs of different kind.\n\nWhich symbol guards the knowledge true?",
		"correct": "A key with teeth like flame",
		"choices": ["A key with teeth like flame", "A wolf’s eye without a name", "A spiral sun with rays entwined"]
	}
]

func _selected_riddle(context: Dictionary) -> Dictionary:
	var rng := make_deterministic_rng(context, "city_ruins_riddle")
	return riddles[rng.randi_range(0, riddles.size() - 1)]

func build_view(context: Dictionary = {}) -> Dictionary:
	var riddle := _selected_riddle(context)
	var rng := make_deterministic_rng(context, "city_ruins_shuffle")
	var shuffled := shuffled_copy(riddle.get("choices", []), rng)
	var view_choices: Array[Dictionary] = []
	for c in shuffled:
		view_choices.append({ CHOICE_ID_KEY: str(c), CHOICE_TEXT_KEY: str(c) })
	return {
		VIEW_DESCRIPTION_KEY: description + "\n\n" + str(riddle.get("question", "")),
		VIEW_CHOICES_KEY: view_choices,
	}

func resolve_choice(choice: Dictionary, _skill_success: bool, context: Dictionary = {}) -> Array:
	var riddle := _selected_riddle(context)
	var correct := str(riddle.get("correct", ""))
	var picked := str(choice.get(CHOICE_ID_KEY, ""))
	if picked == correct:
		return [true, "Correct!"]
	return [false, "Incorrect. Correct answer was: " + correct]
