extends Object
class_name FW_MoveSelector

# Allows chaining selectors for fallback logic
var next_selector: FW_MoveSelector = null
var random_move_chance: float = .25

# Base class for AI move selectors
func pick_move(monster_moves: Array, board_state: Array, ai_data: Dictionary = {}):
    # Override in subclasses. Should return a move dictionary or call next_selector for fallback.
    if next_selector != null:
        return next_selector.pick_move(monster_moves, board_state, ai_data)
    return {}
