extends FW_EventResource
var riddles: Array[Dictionary] = [
	{
		"question": "Three archways stand, worn and old,\nCarved with stories never told.\nOne weeps vines, one echoes light,\nOne stands silent in the night.\n\nOnly one leads past the stone,\nWhich arch brings you safely home?",
		"correct": "The one that echoes light",
		"choices": ["The one that echoes light", "The one that weeps vines", "The one that stands silent"]
	},
	{
		"question": "In the city square, three statues rest,\nEach with symbols on their chest.\nOne holds a book, one holds a blade,\nOne holds nothing, yet none fade.\n\nOne will open a hidden way,\nWhich should the pup obey?",
		"correct": "The one that holds nothing",
		"choices": ["The one that holds nothing", "The one that holds a book", "The one that holds a blade"]
	},
	{
		"question": "Walls crack and whisper names long gone,\nOf kings and thieves and cursed song.\nOne name is heard again and again:\n'Thalen' in the wind’s refrain.\n\nBut two other names twist through the air:\n'Vorn' and 'Elka', both traps to snare.\n\nWhich name hides a truth to trust?",
		"correct": "Thalen",
		"choices": ["Thalen", "Vorn", "Elka"]
	},
	{
		"question": "A tall black door with no handle or frame,\nYet carved with runes that pulse like flame.\nThree items lie upon the ground.\n\nOnly one unlocks the way inside,\nWhich should the pup decide?",
		"correct": "A silver paw",
		"choices": ["A silver paw", "A cracked key", "A bell with no sound"]
	}
]

func _selected_riddle(context: Dictionary) -> Dictionary:
	var rng := make_deterministic_rng(context, "crumbling_city_riddle")
	return riddles[rng.randi_range(0, riddles.size() - 1)]

func build_view(context: Dictionary = {}) -> Dictionary:
	var riddle := _selected_riddle(context)
	var rng := make_deterministic_rng(context, "crumbling_city_shuffle")
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
