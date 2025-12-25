extends FW_EventResource
var riddles: Array[Dictionary] = [
	{
		"question": "The waterfall roars, yet you hear...\nA whisper hidden in its tear.\nIt speaks of treasures tucked away,\nBehind the veil where waters spray.\n\nA hidden passage waits somewhere in the mist.\nWhich path hides the ancient dream?",
		"correct": "A cave straight through the crashing stream",
		"choices": ["A cave straight through the crashing stream", "A vine-covered crack with mossy gleam", "A tunnel to the left, narrow and tall"]
	},
	{
		"question": "Three stones sit beneath the fall,\nEach etched with glyphs beyond recall.\nOne hums low, one hums high,\nOne lies quiet, cold, and dry.\n\nTo pass, the Pomeranian must choose:\nWhich stone holds the water’s truth?",
		"correct": "The stone that hums low",
		"choices": ["The stone that hums low", "The stone that hums high", "The stone that lies quiet"]
	},
	{
		"question": "Mist rises where sunlight weeps,\nAnd voices call from canyon deeps.\nOne speaks of the past, one of fear,\nOne of something drawing near.\n\nOnly one voice leads to safety’s end,\nWhich should the pup defend?",
		"correct": "The voice that speaks of fear",
		"choices": ["The voice that speaks of fear", "The voice that speaks of the past", "The voice that speaks of something near"]
	},
	{
		"question": "The waterfall ends in a sheer drop,\nBelow, a pool no eyes can spot.\nBut three things fall beside the stream.\n\nOne will guide the pup if they leap,\nWhich one offers secrets deep?",
		"correct": "A feather, caught in golden gleam",
		"choices": ["A feather, caught in golden gleam", "A stone, smooth and cold and grey", "A leaf that floats and fades away"]
	}
]

func _selected_riddle(context: Dictionary) -> Dictionary:
	var rng := make_deterministic_rng(context, "waterfall_riddle")
	return riddles[rng.randi_range(0, riddles.size() - 1)]

func build_view(context: Dictionary = {}) -> Dictionary:
	var riddle := _selected_riddle(context)
	var rng := make_deterministic_rng(context, "waterfall_shuffle")
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
