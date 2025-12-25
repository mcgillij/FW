extends FW_MoveSelector
class_name FW_RandomSelector

func pick_move(monster_moves: Array, _board_state: Array, _ai_data: Dictionary = {}):
    if monster_moves.size() == 0:
        return null
    var rand = randi() % monster_moves.size()
    return monster_moves[rand]
