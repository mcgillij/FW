extends FW_EventResource
var riddles: Array[Dictionary] = [
	{
		"question": "I flow but never walk,\nI murmur yet never talk.\nI hold no breath, yet give you drink,\nI wear away both stone and ink.\n\nWhat am I?",
		"correct": "A River",
		"choices": ["A River", "The Wind", "A Mirror"]
	},
	{
		"question": "You follow me but I leave no trail,\nI sing when stones and winds prevail.\nAt times I rage, at times I gleam,\nWhat am I—river, brook, or stream?",
		"correct": "River",
		"choices": ["River", "Cloud", "Tree"]
	},
	{
		"question": "Though I cut the land in two,\nI heal with life and shimmer blue.\nBridges cross me, fish may hide,\nGuess my name and name me right.",
		"correct": "Brook",
		"choices": ["Brook", "Road", "Shadow"]
	},
	{
		"question": "I reflect the sky and swallow rain,\nI twist and bend, yet feel no pain.\n\nWhat am I?",
		"correct": "Stream",
		"choices": ["Stream", "Wind", "Ice"]
	}
]

func _selected_riddle(context: Dictionary) -> Dictionary:
	var rng := make_deterministic_rng(context, "river_riddle")
	return riddles[rng.randi_range(0, riddles.size() - 1)]

func build_view(context: Dictionary = {}) -> Dictionary:
	var riddle := _selected_riddle(context)
	var rng := make_deterministic_rng(context, "river_shuffle")
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
