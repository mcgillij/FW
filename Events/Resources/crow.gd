extends FW_EventResource

func _choose_coins(context: Dictionary) -> int:
	var rng := make_deterministic_rng(context, "crow_coins")
	return rng.randi_range(5, 25)

func _prob_a_wins(starting_coins: int) -> float:
	# Exact probability via memoized recursion over (coins_left, is_a_turn, diff)
	# where diff = A_total - B_total.
	var memo: Dictionary = {}
	return _prob_a_wins_state(starting_coins, true, 0, memo)

func _prob_a_wins_state(coins_left: int, is_a_turn: bool, diff: int, memo: Dictionary) -> float:
	var key := "%d|%d|%d" % [coins_left, 1 if is_a_turn else 0, diff]
	if memo.has(key):
		return memo[key]
	if coins_left <= 0:
		return 1.0 if diff > 0 else 0.0
	var max_take := 2 if coins_left >= 2 else 1
	var p := 0.0
	for take in range(1, max_take + 1):
		var next_diff := diff + take if is_a_turn else diff - take
		p += _prob_a_wins_state(coins_left - take, not is_a_turn, next_diff, memo) * (1.0 / float(max_take))
	memo[key] = p
	return p

func _build_percent_choices(context: Dictionary, coins: int) -> Dictionary:
	var prob := _prob_a_wins(coins)
	var rounded := clampi(roundi(prob * 100.0), 0, 100)
	var correct := "%d%%" % rounded
	var question := "What is the chance that Crow A ends up with more coins than Crow B when starting with %d coins?" % coins

	var rng := make_deterministic_rng(context, "crow_distractors")
	var distractors: Array[int] = []
	while distractors.size() < 2:
		var sign_val := -1 if rng.randi_range(0, 1) == 0 else 1
		var offset: int = rng.randi_range(10, 30) * sign_val
		var d := clampi(rounded + offset, 0, 100)
		if abs(d - rounded) >= 10 and d not in distractors:
			distractors.append(d)

	var all: Array[String] = [correct, "%d%%" % distractors[0], "%d%%" % distractors[1]]
	var shuffled := shuffled_copy(all, make_deterministic_rng(context, "crow_shuffle"))
	return {
		"question": question,
		"correct": correct,
		"choices": shuffled,
	}

func build_view(context: Dictionary = {}) -> Dictionary:
	var coins := _choose_coins(context)
	var built := _build_percent_choices(context, coins)
	var view_choices: Array[Dictionary] = []
	for c in built["choices"]:
		view_choices.append({ CHOICE_ID_KEY: str(c), CHOICE_TEXT_KEY: str(c) })
	return {
		VIEW_DESCRIPTION_KEY: description + "\n\n" + str(built["question"]),
		VIEW_CHOICES_KEY: view_choices,
	}

func resolve_choice(choice: Dictionary, _skill_success: bool, context: Dictionary = {}) -> Array:
	var coins := _choose_coins(context)
	var built := _build_percent_choices(context, coins)
	var correct := str(built["correct"])
	var picked := str(choice.get(CHOICE_ID_KEY, ""))
	if picked == correct:
		return [true, "Correct! Congrats you won this time!"]
	return [false, "Incorrect. Correct answer was: " + correct]
