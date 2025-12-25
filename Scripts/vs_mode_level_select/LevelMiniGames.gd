extends RefCounted

class_name FW_LevelMiniGames

static func generate_random_minigames(_rng: RandomNumberGenerator) -> String:
	"""Generate a random event"""
	var games = [
		"res://HighLow/HighLow.tscn",
		"res://LightsOff/LightsOff.tscn",
		"res://MemoryGame/MemoryGame.tscn",
		"res://MineSweep/MineSweep.tscn",
		"res://Plinko/Plinko.tscn",
		"res://SlotGame/SlotGame.tscn",
	]

	var random_index = _rng.randi() % games.size()
	return games[random_index]
