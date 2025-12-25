class_name FW_GameState
extends RefCounted

# Represents a move in the game that can be undone
class Move:
	var card: FW_Card
	var cards_moved: Array[FW_Card] = []  # For multi-card moves
	var source_pile: int  # PileType enum value
	var source_index: int
	var dest_pile: int
	var dest_index: int
	var revealed_card: FW_Card = null  # Card that was revealed by this move
	var from_stock: bool = false  # Was this a stock draw?

	func _init(c: FW_Card = null):
		card = c

# Move history
var move_history: Array[Move] = []
var max_history: int = 512

func add_move(move: Move) -> void:
	if move_history.size() >= max_history:
		move_history.pop_front()
	move_history.append(move)

func can_undo() -> bool:
	return not move_history.is_empty()

func pop_last_move() -> Move:
	if move_history.is_empty():
		return null
	return move_history.pop_back()

func clear() -> void:
	move_history.clear()
