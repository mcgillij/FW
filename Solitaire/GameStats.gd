class_name FW_GameStats
extends RefCounted

## Stores statistics for a single solitaire game
class GameRecord:
	var timestamp: int  # Unix timestamp
	var date_string: String  # Human-readable date
	var won: bool
	var moves: int
	var time_seconds: float
	var score: int
	var foundation_cards: int  # How many cards made it to foundation
	var draw_mode: bool  # True = 3-card draw, False = 1-card draw
	var stock_cycles: int  # Number of times cycled through stock
	var undo_count: int  # Number of undos used
	var auto_completed: bool  # Whether auto-complete was used
	var game_duration_string: String  # Human-readable time like "5m 32s"

	func _init() -> void:
		timestamp = int(Time.get_unix_time_from_system())
		date_string = Time.get_datetime_string_from_system()
		won = false
		moves = 0
		time_seconds = 0.0
		score = 0
		foundation_cards = 0
		draw_mode = false
		stock_cycles = 0
		undo_count = 0
		auto_completed = false
		game_duration_string = "00:00"

	func to_dict() -> Dictionary:
		return {
			"timestamp": timestamp,
			"date_string": date_string,
			"won": won,
			"moves": moves,
			"time_seconds": time_seconds,
			"score": score,
			"foundation_cards": foundation_cards,
			"draw_mode": draw_mode,
			"stock_cycles": stock_cycles,
			"undo_count": undo_count,
			"auto_completed": auto_completed,
			"game_duration_string": game_duration_string
		}

	static func from_dict(data: Dictionary) -> GameRecord:
		var record = GameRecord.new()
		record.timestamp = data.get("timestamp", 0)
		record.date_string = data.get("date_string", "")
		record.won = data.get("won", false)
		record.moves = data.get("moves", 0)
		record.time_seconds = data.get("time_seconds", 0.0)
		record.score = data.get("score", 0)
		record.foundation_cards = data.get("foundation_cards", 0)
		# New fields with backward compatibility
		record.draw_mode = data.get("draw_mode", false)
		record.stock_cycles = data.get("stock_cycles", 0)
		record.undo_count = data.get("undo_count", 0)
		record.auto_completed = data.get("auto_completed", false)
		record.game_duration_string = data.get("game_duration_string", "00:00")
		return record

## Stores aggregate statistics
class Statistics:
	var total_games: int = 0
	var total_wins: int = 0
	var total_losses: int = 0
	var total_moves: int = 0
	var total_time_seconds: float = 0.0
	var best_time_seconds: float = 0.0  # Fastest win (0 = no wins yet)
	var best_moves: int = 0  # Fewest moves to win (0 = no wins yet)
	var highest_score: int = 0
	var current_streak: int = 0  # Current win streak
	var best_streak: int = 0  # Best win streak ever
	var games_history: Array[GameRecord] = []

	func to_dict() -> Dictionary:
		var history_array: Array = []
		for record in games_history:
			history_array.append(record.to_dict())

		return {
			"total_games": total_games,
			"total_wins": total_wins,
			"total_losses": total_losses,
			"total_moves": total_moves,
			"total_time_seconds": total_time_seconds,
			"best_time_seconds": best_time_seconds,
			"best_moves": best_moves,
			"highest_score": highest_score,
			"current_streak": current_streak,
			"best_streak": best_streak,
			"games_history": history_array
		}

	static func from_dict(data: Dictionary) -> Statistics:
		var stats = Statistics.new()
		stats.total_games = data.get("total_games", 0)
		stats.total_wins = data.get("total_wins", 0)
		stats.total_losses = data.get("total_losses", 0)
		stats.total_moves = data.get("total_moves", 0)
		stats.total_time_seconds = data.get("total_time_seconds", 0.0)
		stats.best_time_seconds = data.get("best_time_seconds", 0.0)
		stats.best_moves = data.get("best_moves", 0)
		stats.highest_score = data.get("highest_score", 0)
		stats.current_streak = data.get("current_streak", 0)
		stats.best_streak = data.get("best_streak", 0)

		var history_array = data.get("games_history", [])
		for record_data in history_array:
			if record_data is Dictionary:
				stats.games_history.append(GameRecord.from_dict(record_data))

		return stats

	func add_game(record: GameRecord) -> void:
		total_games += 1
		total_moves += record.moves
		total_time_seconds += record.time_seconds

		if record.won:
			total_wins += 1
			current_streak += 1
			if current_streak > best_streak:
				best_streak = current_streak

			# Update best time (if this is first win or faster)
			if best_time_seconds == 0.0 or record.time_seconds < best_time_seconds:
				best_time_seconds = record.time_seconds

			# Update best moves (if this is first win or fewer moves)
			if best_moves == 0 or record.moves < best_moves:
				best_moves = record.moves

			# Update highest score
			if record.score > highest_score:
				highest_score = record.score
		else:
			total_losses += 1
			current_streak = 0

		games_history.append(record)

		# Keep only the last MAX_HISTORY games to avoid file bloat. Use a loop to ensure
		# we never exceed the cap even if older files were larger.
		while games_history.size() > MAX_HISTORY:
			games_history.pop_front()

	func get_win_rate() -> float:
		if total_games == 0:
			return 0.0
		return float(total_wins) / float(total_games) * 100.0

	func get_average_time() -> float:
		if total_wins == 0:
			return 0.0
		var total_win_time: float = 0.0
		var win_count: int = 0
		for record in games_history:
			if record.won:
				total_win_time += record.time_seconds
				win_count += 1
		if win_count == 0:
			return 0.0
		return total_win_time / float(win_count)

	func get_average_moves() -> float:
		if total_wins == 0:
			return 0.0
		var total_win_moves: int = 0
		var win_count: int = 0
		for record in games_history:
			if record.won:
				total_win_moves += record.moves
				win_count += 1
		if win_count == 0:
			return 0.0
		return float(total_win_moves) / float(win_count)

const SAVE_PATH = "user://solitaire_stats.json" # legacy combined file (kept for backward compatibility)
const HISTORY_PATH = "user://solitaire_history.json" # per-game detailed history (capped)
const SUMMARY_PATH = "user://solitaire_summary.json" # aggregate summary for long-term stats and fast loads
const MAX_HISTORY: int = 1000

var current_stats: Statistics = Statistics.new()
var _stats_loaded: bool = false  # Track if we've loaded from disk yet

func _init() -> void:
	# Don't load stats in _init() anymore - load on demand for better performance
	pass

## Ensure stats are loaded before accessing them
func ensure_loaded() -> void:
	if not _stats_loaded:
		load_stats()

## Load statistics from file (called lazily on first access)
func load_stats() -> void:
	if _stats_loaded:
		return  # Already loaded, don't reload

	_stats_loaded = true

	# Preferred layout: separate summary + history files for fast loads and long-term storage
	if FileAccess.file_exists(SUMMARY_PATH) or FileAccess.file_exists(HISTORY_PATH):
		# Start with a fresh stats object
		current_stats = Statistics.new()

		# Load summary (if present) - this gives us aggregates quickly
		if FileAccess.file_exists(SUMMARY_PATH):
			var sum_file = FileAccess.open(SUMMARY_PATH, FileAccess.READ)
			if sum_file == null:
				push_error("Failed to open summary file: " + str(FileAccess.get_open_error()))
			else:
				var sum_text = sum_file.get_as_text()
				sum_file.close()
				var j = JSON.new()
				if j.parse(sum_text) == OK:
					var sum_data = j.get_data()
					if sum_data is Dictionary:
						current_stats = Statistics.from_dict(sum_data)
					else:
						push_error("Summary file has invalid format")
				else:
					push_error("Failed to parse summary JSON")

		# Load history (if present) and attach detailed records. If no summary was present
		# we'll recompute aggregates from history.
		if FileAccess.file_exists(HISTORY_PATH):
			var hist_file = FileAccess.open(HISTORY_PATH, FileAccess.READ)
			if hist_file == null:
				push_error("Failed to open history file: " + str(FileAccess.get_open_error()))
			else:
				var hist_text = hist_file.get_as_text()
				hist_file.close()
				var jh = JSON.new()
				if jh.parse(hist_text) == OK:
					var hist_data = jh.get_data()
					if hist_data is Array:
						# Attach records (preserve order). We avoid modifying aggregates here
						current_stats.games_history.clear()
						for record_data in hist_data:
							if record_data is Dictionary:
								current_stats.games_history.append(GameRecord.from_dict(record_data))
						# Trim to MAX_HISTORY if file was larger
						while current_stats.games_history.size() > MAX_HISTORY:
							current_stats.games_history.pop_front()
						# If summary wasn't present (or looks empty), recompute aggregates
						if current_stats.total_games == 0 and current_stats.total_wins == 0 and current_stats.total_losses == 0:
							current_stats = _recompute_stats_from_history(hist_data)
					else:
						push_error("History file has invalid format")
				else:
					push_error("Failed to parse history JSON")

		return

	# Fallback: legacy combined save file
	if not FileAccess.file_exists(SAVE_PATH):
		current_stats = Statistics.new()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open stats file: " + str(FileAccess.get_open_error()))
		current_stats = Statistics.new()
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse stats JSON")
		current_stats = Statistics.new()
		return

	var data = json.get_data()
	if data is Dictionary:
		current_stats = Statistics.from_dict(data)
	else:
		push_error("Stats file has invalid format")
		current_stats = Statistics.new()

## Save statistics to file(s)
func save_stats() -> void:
	# Prepare history array (detailed per-game records)
	var history_array: Array = []
	for record in current_stats.games_history:
		history_array.append(record.to_dict())

	# Write history file (detailed, capped to MAX_HISTORY)
	var hist_file = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if hist_file == null:
		push_error("Failed to create history file: " + str(FileAccess.get_open_error()))
	else:
		hist_file.store_string(JSON.stringify(history_array, "\t"))
		hist_file.close()

	# Write summary file (lightweight aggregates)
	var summary_dict = _stats_to_summary_dict(current_stats)
	var sum_file = FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if sum_file == null:
		push_error("Failed to create summary file: " + str(FileAccess.get_open_error()))
	else:
		sum_file.store_string(JSON.stringify(summary_dict, "\t"))
		sum_file.close()

	# Also write legacy combined file for compatibility with older versions
	var legacy_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if legacy_file == null:
		push_error("Failed to create legacy stats file: " + str(FileAccess.get_open_error()))
	else:
		legacy_file.store_string(JSON.stringify(current_stats.to_dict(), "\t"))
		legacy_file.close()


func _stats_to_summary_dict(stats: Statistics) -> Dictionary:
	# Produce a compact summary dictionary (no per-game details)
	return {
		"total_games": stats.total_games,
		"total_wins": stats.total_wins,
		"total_losses": stats.total_losses,
		"total_moves": stats.total_moves,
		"total_time_seconds": stats.total_time_seconds,
		"best_time_seconds": stats.best_time_seconds,
		"best_moves": stats.best_moves,
		"highest_score": stats.highest_score,
		"current_streak": stats.current_streak,
		"best_streak": stats.best_streak,
		"games_history_count": stats.games_history.size()
	}


func _recompute_stats_from_history(history_array: Array) -> Statistics:
	# Build a fresh Statistics object by replaying the history entries.
	var stats = Statistics.new()
	for record_data in history_array:
		if record_data is Dictionary:
			var rec = GameRecord.from_dict(record_data)
			stats.add_game(rec)
	return stats

## Record a completed game
func record_game(won: bool, moves: int, time_seconds: float, score: int, foundation_cards: int, draw_mode: bool = false, stock_cycles: int = 0, undo_count: int = 0, auto_completed: bool = false) -> void:
	ensure_loaded()  # Make sure stats are loaded before recording

	var record = GameRecord.new()
	record.won = won
	record.moves = moves
	record.time_seconds = time_seconds
	record.score = score
	record.foundation_cards = foundation_cards
	record.draw_mode = draw_mode
	record.stock_cycles = stock_cycles
	record.undo_count = undo_count
	record.auto_completed = auto_completed
	record.game_duration_string = format_time(time_seconds)

	current_stats.add_game(record)
	save_stats()

## Get the current statistics
func get_stats() -> Statistics:
	ensure_loaded()  # Lazy load on first access
	return current_stats

## Get a formatted summary string
func get_summary() -> String:
	ensure_loaded()  # Lazy load on first access
	var s = current_stats
	var summary = ""
	summary += "Games Played: %d\n" % s.total_games
	summary += "Wins: %d | Losses: %d\n" % [s.total_wins, s.total_losses]
	summary += "Win Rate: %.1f%%\n" % s.get_win_rate()

	if s.total_wins > 0:
		summary += "\nBest Records:\n"
		summary += "  Best Time: %s\n" % format_time(s.best_time_seconds)
		summary += "  Fewest Moves: %d\n" % s.best_moves
		summary += "  Highest Score: %d\n" % s.highest_score
		summary += "\nAverages (Wins only):\n"
		summary += "  Avg Time: %s\n" % format_time(s.get_average_time())
		summary += "  Avg Moves: %.1f\n" % s.get_average_moves()

	summary += "\nStreaks:\n"
	summary += "  Current: %d\n" % s.current_streak
	summary += "  Best: %d\n" % s.best_streak

	return summary

## Format seconds into MM:SS
func format_time(seconds: float) -> String:
	var minutes = int(seconds / 60.0)
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]
