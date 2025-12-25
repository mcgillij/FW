extends FW_MoveSelector
class_name FW_SelfAwareSelector

func pick_move(monster_moves: Array, board_state: Array, ai_data: Dictionary = {}):
    if next_selector != null and randf() < random_move_chance:
        return next_selector.pick_move(monster_moves, board_state, ai_data)
    # Find the ability that needs the least mana to become usable
    var mana_pool = {}
    if ai_data.has("mana_pool"):
        mana_pool = ai_data["mana_pool"]
    var abilities = []
    if ai_data.has("abilities"):
        abilities = ai_data["abilities"]
    if mana_pool.size() == 0 or abilities.size() == 0:
        if next_selector != null:
            var result = next_selector.pick_move(monster_moves, board_state, ai_data)
            if result == null or result.size() == 0:
                return {}
            return result
        return {}
    var needed_mana = _get_needed_mana_for_abilities(abilities, mana_pool)
    # Prioritize moves that gather needed mana
    var mana_move = _pick_best_mana_gathering_move(monster_moves, board_state, needed_mana)
    if mana_move != null and mana_move.size() > 0:
        return mana_move
    if next_selector != null:
        var result = next_selector.pick_move(monster_moves, board_state, ai_data)
        if result == null or result.size() == 0:
            return {}
        return result
    return {}

func _get_needed_mana_for_abilities(abilities, mana_pool):
    # Return a dictionary of mana needed for each ability
    var needed = {}
    for ability in abilities:
        for color in ability.cost.keys():
            var diff = max(0, ability.cost[color] - mana_pool[color])
            needed[color] = needed.get(color, 0) + diff
    return needed

func _pick_best_mana_gathering_move(monster_moves, board_state, needed_mana):
    # Simulate moves and pick one that matches tiles of needed mana color
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
        # Score move by how many needed mana tiles are matched
        var score = 0
        for color in needed_mana.keys():
            if needed_mana[color] > 0:
                score += _count_matches_for_color(temp_array, color, new_x, new_y)
                score += _count_matches_for_color(temp_array, color, x, y)
        if score > best_score:
            best_score = score
            best_move = move
    if best_score > 0:
        return best_move
    return null

func _count_matches_for_color(array: Array, color: String, x: int, y: int) -> int:
    # Count horizontal and vertical matches for a specific color at (x, y)
    if array[x][y] == null or FW_MonsterAI.get_color(array[x][y]) != color:
        return 0
    var count := 1
    var left := x - 1
    while left >= 0 and array[left][y] != null and FW_MonsterAI.get_color(array[left][y]) == color:
        count += 1
        left -= 1
    var right := x + 1
    while right < array.size() and array[right][y] != null and FW_MonsterAI.get_color(array[right][y]) == color:
        count += 1
        right += 1
    var score := 0
    if count >= 3:
        score += count
    # Check vertical
    count = 1
    var up := y - 1
    while up >= 0 and array[x][up] != null and FW_MonsterAI.get_color(array[x][up]) == color:
        count += 1
        up -= 1
    var down := y + 1
    while down < array[0].size() and array[x][down] != null and FW_MonsterAI.get_color(array[x][down]) == color:
        count += 1
        down += 1
    if count >= 3:
        score += count
    return score
