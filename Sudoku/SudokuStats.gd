# Title: Sudoku Stats
# Path: res://Sudoku/FW_SudokuStats.gd
# Description: Tracks per-game Sudoku records and aggregates for future persistence.
# Key functions: record_game, get_stats, get_best_time_label

class_name FW_SudokuStats
extends RefCounted

## Holds stats for a single Sudoku game
class GameRecord:
	var timestamp: int
	var won: bool
	var difficulty: String
	var time_seconds: float
	var mistakes: int
	var hints_used: int
	var hint_limit: int
	var formatted_time: String

	func _init() -> void:
		timestamp = int(Time.get_unix_time_from_system())
		won = false
		difficulty = "easy"
		time_seconds = 0.0
		mistakes = 0
		hints_used = 0
		hint_limit = 0
		formatted_time = "00:00"

	func to_dict() -> Dictionary:
		return {
			"timestamp": timestamp,
			"won": won,
			"difficulty": difficulty,
			"time_seconds": time_seconds,
			"mistakes": mistakes,
			"hints_used": hints_used,
			"hint_limit": hint_limit,
			"formatted_time": formatted_time,
		}

	static func from_dict(data: Dictionary) -> GameRecord:
		var rec := GameRecord.new()
		rec.timestamp = data.get("timestamp", 0)
		rec.won = data.get("won", false)
		rec.difficulty = data.get("difficulty", "easy")
		rec.time_seconds = data.get("time_seconds", 0.0)
		rec.mistakes = data.get("mistakes", 0)
		rec.hints_used = data.get("hints_used", 0)
		rec.hint_limit = data.get("hint_limit", 0)
		rec.formatted_time = data.get("formatted_time", "00:00")
		return rec

## Aggregated statistics across many games
class Statistics:
	var total_games: int = 0
	var total_wins: int = 0
	var total_losses: int = 0
	var total_time_seconds: float = 0.0
	var total_mistakes: int = 0
	var total_hints_used: int = 0
	var best_time_seconds: float = 0.0
	var best_time_by_difficulty: Dictionary = {}
	var current_streak: int = 0
	var best_streak: int = 0
	var games_history: Array[GameRecord] = []

	func to_dict() -> Dictionary:
		var history: Array = []
		for record in games_history:
			history.append(record.to_dict())

		return {
			"total_games": total_games,
			"total_wins": total_wins,
			"total_losses": total_losses,
			"total_time_seconds": total_time_seconds,
			"total_mistakes": total_mistakes,
			"total_hints_used": total_hints_used,
			"best_time_seconds": best_time_seconds,
			"best_time_by_difficulty": best_time_by_difficulty,
			"current_streak": current_streak,
			"best_streak": best_streak,
			"games_history": history,
		}

	static func from_dict(data: Dictionary) -> Statistics:
		var stats := Statistics.new()
		stats.total_games = data.get("total_games", 0)
		stats.total_wins = data.get("total_wins", 0)
		stats.total_losses = data.get("total_losses", 0)
		stats.total_time_seconds = data.get("total_time_seconds", 0.0)
		stats.total_mistakes = data.get("total_mistakes", 0)
		stats.total_hints_used = data.get("total_hints_used", 0)
		stats.best_time_seconds = data.get("best_time_seconds", 0.0)
		stats.best_time_by_difficulty = data.get("best_time_by_difficulty", {})
		stats.current_streak = data.get("current_streak", 0)
		stats.best_streak = data.get("best_streak", 0)

		var history_array = data.get("games_history", [])
		for entry in history_array:
			if entry is Dictionary:
				stats.games_history.append(GameRecord.from_dict(entry))
				if stats.games_history.size() > MAX_HISTORY:
					break

		return stats

	func add_game(record: GameRecord) -> void:
		total_games += 1
		total_time_seconds += record.time_seconds
		total_mistakes += record.mistakes
		total_hints_used += record.hints_used

		if record.won:
			total_wins += 1
			current_streak += 1
			if best_time_seconds == 0.0 or record.time_seconds < best_time_seconds:
				best_time_seconds = record.time_seconds
			var diff_key := record.difficulty
			var diff_best: float = float(best_time_by_difficulty.get(diff_key, 0.0))
			if diff_best == 0.0 or record.time_seconds < diff_best:
				best_time_by_difficulty[diff_key] = record.time_seconds
		else:
			total_losses += 1
			current_streak = 0

		if current_streak > best_streak:
			best_streak = current_streak

		games_history.append(record)
		while games_history.size() > MAX_HISTORY:
			games_history.pop_front()

	func get_win_rate() -> float:
		if total_games == 0:
			return 0.0
		return float(total_wins) / float(total_games) * 100.0

	func get_average_time() -> float:
		if total_wins == 0:
			return 0.0
		var total_win_time := 0.0
		for record in games_history:
			if record.won:
				total_win_time += record.time_seconds
		if total_wins == 0:
			return 0.0
		return total_win_time / float(total_wins)

	func get_best_time_for_difficulty(difficulty: String) -> float:
		return float(best_time_by_difficulty.get(difficulty, 0.0))

const MAX_HISTORY: int = 300

var _stats: Statistics = Statistics.new()

func record_game(won: bool, time_seconds: float, mistakes: int, hints_used: int, hint_limit: int, difficulty: String) -> GameRecord:
	var record := GameRecord.new()
	record.won = won
	record.time_seconds = time_seconds
	record.mistakes = mistakes
	record.hints_used = hints_used
	record.hint_limit = hint_limit
	record.difficulty = difficulty
	record.formatted_time = format_time(time_seconds)

	_stats.add_game(record)
	return record

func get_stats() -> Statistics:
	return _stats

func get_best_time_label(difficulty: String) -> String:
	var best: float = _stats.best_time_seconds if difficulty.is_empty() else _stats.get_best_time_for_difficulty(difficulty)
	if best <= 0.0:
		return "—"
	return format_time(best)

func format_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	var secs := int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]
