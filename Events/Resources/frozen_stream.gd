extends FW_EventResource
var riddles: Array[Dictionary] = [
	{
		"question": "In the hollow where cold winds sigh,\nThe Pomeranian hears a distant cry.\nThree echoes bounce from icy stone—\nBut one voice calls from safety alone.\n\nWhich sound should the pup trust?",
		"correct": "A soft yip from high and clear",
		"choices": ["A soft yip from high and clear", "A sharp bark low and near", "A howl that fades but draws you near"]
	},
	{
		"question": "Fresh snow covers the forest path,\nBut pawprints lie in aftermath.\nThree sets lead to who knows where—\nOne is safe, tread with care.\n\nWhich track should the pup follow?",
		"correct": "A single track, steady stride",
		"choices": ["A single track, steady stride", "Tiny prints that dart then hide", "Heavy paws, deep and wide"]
	},
	{
		"question": "A frozen gust whispers through the trees,\nThe pup must pick the path with ease.\nEach route sings with a winter sound—\nBut only one is safe and sound.\n\nWhich path should the pup choose?",
		"correct": "A quiet glade with snow like a cloud",
		"choices": ["A quiet glade with snow like a cloud", "A tunnel of trees where the wind howls loud", "A ridge where gusts bite sharp and fast"]
	},
	{
		"question": "A sheet of ice, smooth and wide,\nShows reflections on either side.\nThe pup peers down and sees three sights—\nOne reveals the path that’s right.\n\nWhich reflection should the pup trust?",
		"correct": "Their own reflection looking back just so",
		"choices": ["Their own reflection looking back just so", "A flickering torchlight in the icy flow", "A reflection showing trees with no snow"]
	}
]

func _selected_riddle(context: Dictionary) -> Dictionary:
	var rng := make_deterministic_rng(context, "frozen_stream_riddle")
	return riddles[rng.randi_range(0, riddles.size() - 1)]

func build_view(context: Dictionary = {}) -> Dictionary:
	var riddle := _selected_riddle(context)
	var rng := make_deterministic_rng(context, "frozen_stream_shuffle")
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
