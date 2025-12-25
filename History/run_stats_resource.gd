extends Resource

class_name FW_RunStatistics

var history_file_path = OS.get_user_data_dir() + "/save/history.json"

@export var character_name: String
@export var character_image_path: String
@export var character_resource_path: String
@export var affinities: Array
@export var level_reached: int
@export var gold: int
@export var xp: int
@export var monsters_encountered: int
@export var datetime: String
@export var floors_cleared: int
@export var difficulty: int
@export var job_name: String
@export var job_color: String
@export var game_version: String
@export var cause_of_death: String
@export var ascension_level: int

# run duration
# seed
# maybe map location where died
# abilities used
# equipment summary
# highest damage dealt
# most used ability

func load_all_statistics() -> Array:
	var all_runs := []
	if FileAccess.file_exists(history_file_path):
		var file = FileAccess.open(history_file_path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			var result = JSON.parse_string(text)
			if typeof(result) == TYPE_DICTIONARY and result.has("runs"):
				all_runs = result["runs"]
			file.close()
	return all_runs

func append_run_to_archive(run_data: Dictionary) -> void:
	var runs = []
	if FileAccess.file_exists(history_file_path):
		var stats_file = FileAccess.open(history_file_path, FileAccess.READ)
		if stats_file:
			var text = stats_file.get_as_text()
			var result = JSON.parse_string(text)
			if typeof(result) == TYPE_DICTIONARY and result.has("runs"):
				runs = result["runs"]
			stats_file.close()
	if run_data.has("job_color"):
		var jc = run_data["job_color"]
		if typeof(jc) == TYPE_OBJECT and jc is Color:
			run_data["job_color"] = jc.to_html()
		elif typeof(jc) == TYPE_STRING:
			# Assume it's already a hex string
			pass
	runs.append(run_data)
	var archive = { "runs": runs }
	var file = FileAccess.open(history_file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(archive, "\t")) # pretty print
		file.close()

func to_dict() -> Dictionary:
	return {
		"character_name": character_name,
		"character_image_path": character_image_path,
		"character_resource_path": character_resource_path,
		"level_reached": level_reached,
		"gold": gold,
		"xp": xp,
		"monsters_encountered": monsters_encountered,
		"floors_cleared": floors_cleared,
		"datetime": datetime,
		"difficulty": difficulty,
		"job_name": job_name,
		"job_color": job_color,
		"affinities": affinities,
		"game_version": game_version,
		"cause_of_death": cause_of_death,
		"ascension_level": ascension_level,
	}

func _to_string() -> String:
	return "RunStatistics(character_name=%s, level_reached=%d, gold=%d, xp=%d, monsters_encountered=%d, floors_cleared=%d, datetime=%s, difficulty=%d, job_name=%s, job_color=%s, game_version=%s, cause_of_death=%s, ascension_level=%s)" % [
		character_name,
		level_reached,
		gold,
		xp,
		monsters_encountered,
		floors_cleared,
		datetime,
		difficulty,
		job_name,
		job_color,
		game_version,
		cause_of_death,
		ascension_level
	]
