class_name FW_Deck
extends RefCounted

var cards: Array[FW_Card] = []

func _init() -> void:
	reset()

func reset() -> void:
	cards.clear()
	for suit in FW_Card.Suit.values():
		for rank in FW_Card.Rank.values():
			cards.append(FW_Card.new(suit, rank))
	shuffle()

func shuffle() -> void:
	cards.shuffle()

func draw() -> FW_Card:
	if cards.is_empty():
		return null
	return cards.pop_back()

func size() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()
