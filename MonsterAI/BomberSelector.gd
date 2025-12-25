extends FW_MoveSelector
class_name FW_BomberSelector

func pick_move(monster_moves: Array, board_state: Array, ai_data: Dictionary = {}):
	if next_selector != null and randf() < random_move_chance:
		return next_selector.pick_move(monster_moves, board_state, ai_data)
	# Prioritize moves that activate bombs, then create bombs
	var color_bomb_moves = []
	var bomb_activation_moves = []
	var bomb_trigger_moves = []
	var bomb_create_moves = []

	for move in monster_moves:
		var x = move.x
		var y = move.y
		var dir = move.direction
		var new_x = x + int(dir.x)
		var new_y = y + int(dir.y)
		if not FW_MonsterAI.is_in_grid(board_state, new_x, new_y):
			continue

		var tile1 = board_state[x][y]
		var tile2 = board_state[new_x][new_y]

		# Any move involving a color bomb is high priority.
		if FW_MonsterAI.get_bomb_type(tile1) == "color_bomb" or FW_MonsterAI.get_bomb_type(tile2) == "color_bomb":
			color_bomb_moves.append(move)
			continue

		var temp_array = FW_MonsterAI.copy_array(board_state)
		var temp = temp_array[x][y]
		temp_array[x][y] = temp_array[new_x][new_y]
		temp_array[new_x][new_y] = temp

		var simulated_matches = FW_MonsterAI.simulate_find_matches(temp_array)
		var match_groups = FW_MonsterAI.group_contiguous_matches(simulated_matches)

		var activates_bomb = false
		var triggers = false
		var creates = false

		for group in match_groups:
			for pos in group:
				var tile = temp_array[int(pos.x)][int(pos.y)]
				var bomb_type = FW_MonsterAI.get_bomb_type(tile)
				if bomb_type in ["color_bomb", "adjacent_bomb", "row_bomb", "col_bomb"]:
					activates_bomb = true
			if FW_MonsterAI.is_bomb_trigger_group(group):
				triggers = true
			if FW_MonsterAI.is_bomb_create_group(group):
				creates = true

		if activates_bomb:
			bomb_activation_moves.append(move)
		elif triggers:
			bomb_trigger_moves.append(move)
		elif creates:
			bomb_create_moves.append(move)

	if color_bomb_moves.size() > 0:
		return color_bomb_moves[0]
	elif bomb_activation_moves.size() > 0:
		return bomb_activation_moves[0]
	elif bomb_trigger_moves.size() > 0:
		return bomb_trigger_moves[0]
	elif bomb_create_moves.size() > 0:
		return bomb_create_moves[0]
	if next_selector != null:
		return next_selector.pick_move(monster_moves, board_state, ai_data)
	return {}
