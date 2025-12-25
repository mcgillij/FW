class_name FW_Card
extends RefCounted

enum Suit {HEARTS, DIAMONDS, CLUBS, SPADES}
enum Rank {ACE = 1, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING}

var suit: Suit
var rank: Rank
var face_up: bool = false

func _init(s: Suit, r: Rank) -> void:
	suit = s
	rank = r

func get_color() -> String:
	return "red" if suit in [Suit.HEARTS, Suit.DIAMONDS] else "black"

func get_suit_name() -> String:
	match suit:
		Suit.HEARTS: return "hearts"
		Suit.DIAMONDS: return "diamonds"
		Suit.CLUBS: return "clubs"
		Suit.SPADES: return "spades"
	return ""

func get_rank_name() -> String:
	match rank:
		Rank.ACE: return "ace"
		Rank.JACK: return "jack"
		Rank.QUEEN: return "queen"
		Rank.KING: return "king"
		_: return str(rank)

func _to_string() -> String:
	return get_rank_name() + "_of_" + get_suit_name()

func is_opposite_color(other: FW_Card) -> bool:
	return get_color() != other.get_color()

func can_stack_on_tableau(other: FW_Card) -> bool:
	# For tableau: must be opposite color and one rank lower
	var opposite = is_opposite_color(other)
	var rank_check = rank == other.rank - 1
	var result = opposite and rank_check

	return result

func can_stack_on_foundation(other: FW_Card) -> bool:
	# For foundation: same suit and one rank higher
	return suit == other.suit and rank == other.rank + 1
