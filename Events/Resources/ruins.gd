extends FW_EventResource
var riddles: Array[Dictionary] = [
	{
		"question": "A broken tower leans with age,\nIts shadow still commands the stage.\nBeneath it lie three worn stone rings:\nOne glows blue, one hums and sings,\nOne stays still but smells of dust.\n\nWhich one holds the answer just?",
		"correct": "The one that hums and sings",
		"choices": ["The one that hums and sings", "The one that glows blue", "The one that smells of dust"]
	},
	{
		"question": "On shattered walls, old murals fade,\nOf heroes, beasts, and deals once made.\nOne shows a flame, one shows a throne,\nOne shows a pup that walks alone.\n\nOnly one is still alive.\nWhich tale will help the pup survive?",
		"correct": "The pup that walks alone",
		"choices": ["The pup that walks alone", "The throne", "The flame"]
	},
	{
		"question": "Stones lie cracked and left in place,\nEach one carved with a different face.\nOne is smiling, one looks sad,\nOne is missing all it had.\n\nWhich face still remembers lore,\nTo guide you through the broken floor?",
		"correct": "The one that looks sad",
		"choices": ["The one that looks sad", "The one that is smiling", "The one that is missing"]
	},
	{
		"question": "A gate half-gone, yet still it stands,\nNo doors, no guards, no guiding hands.\nOn the arch are three carved beasts:\nA lion asleep, a fox mid-feast,\nA wolf howling at the least.\n\nOne grants safe passage if named.\nWhich should not be blamed?",
		"correct": "The lion asleep",
		"choices": ["The lion asleep", "The fox mid-feast", "The wolf howling"]
	}
]

func _selected_riddle(context: Dictionary) -> Dictionary:
	var rng := make_deterministic_rng(context, "ruins_riddle")
	return riddles[rng.randi_range(0, riddles.size() - 1)]

func build_view(context: Dictionary = {}) -> Dictionary:
	var riddle := _selected_riddle(context)
	var rng := make_deterministic_rng(context, "ruins_shuffle")
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
