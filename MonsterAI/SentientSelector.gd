extends FW_MoveSelector
class_name FW_SentientSelector

func pick_move(monster_moves: Array, board_state: Array, ai_data: Dictionary = {}):
    if next_selector != null and randf() < random_move_chance:
        return next_selector.pick_move(monster_moves, board_state, ai_data)
    # Prioritize matches of affinity colors, fallback to largest match, then random
    var affinity_colors = []
    if ai_data.has("affinity_colors"):
        affinity_colors = ai_data["affinity_colors"]

    var best_affinity_move = null
    var best_affinity_score := -1
    var best_move = null
    var best_score := -1

    for move in monster_moves:
        var x = move.x
        var y = move.y
        var dir = move.direction
        var new_x = x + int(dir.x)
        var new_y = y + int(dir.y)
        # Check bounds
        if not FW_MonsterAI.is_in_grid(board_state, new_x, new_y):
            continue
        var temp_array = FW_MonsterAI.copy_array(board_state)
        var temp = temp_array[x][y]
        temp_array[x][y] = temp_array[new_x][new_y]
        temp_array[new_x][new_y] = temp

        # Score move by largest match of affinity color
        var affinity_score = 0
        for affinity in affinity_colors:
            var move_score = _count_largest_match_of_color(temp_array, new_x, new_y, affinity)
            if move_score > affinity_score:
                affinity_score = move_score
        if affinity_score > best_affinity_score:
            best_affinity_score = affinity_score
            best_affinity_move = move

        # Also track largest match of any color
        var score = _count_largest_match(temp_array, new_x, new_y)
        if score > best_score:
            best_score = score
            best_move = move

    if best_affinity_score > 0:
        return best_affinity_move
    elif best_score > 0:
        return best_move
    if next_selector != null:
        return next_selector.pick_move(monster_moves, board_state, ai_data)
    return {}

# Helper functions
func _count_largest_match(array: Array, x: int, y: int) -> int:
    if array[x][y] == null:
        return 0
    var color = FW_MonsterAI.get_color(array[x][y])
    return _count_largest_match_of_color(array, x, y, color)

func _count_largest_match_of_color(array: Array, x: int, y: int, color: String) -> int:
    if array[x][y] == null or FW_MonsterAI.get_color(array[x][y]) != color:
        return 0
    var left = x - 1
    var right = x + 1
    var up = y - 1
    var down = y + 1
    var h_count = 1
    while left >= 0 and array[left][y] != null and FW_MonsterAI.get_color(array[left][y]) == color:
        h_count += 1
        left -= 1
    while right < array.size() and array[right][y] != null and FW_MonsterAI.get_color(array[right][y]) == color:
        h_count += 1
        right += 1

    var v_count = 1
    while up >= 0 and array[x][up] != null and FW_MonsterAI.get_color(array[x][up]) == color:
        v_count += 1
        up -= 1
    while down < array[0].size() and array[x][down] != null and FW_MonsterAI.get_color(array[x][down]) == color:
        v_count += 1
        down += 1

    return max(h_count, v_count)
