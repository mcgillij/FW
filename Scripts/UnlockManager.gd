extends Node

var just_unlocked_act: String = ""

@onready var path: String = "user://save/unlocks.ini"

var _signals_connected := false
var achievement_to_character = {
	"atiya": "res://Characters/Atiya.tres",
	"rosie": "res://Characters/Rosie.tres",
	"raiden": "res://Characters/Raiden.tres",
	"bonk": "res://Characters/Bonk.tres",
	"boomer": "res://Characters/Boomer.tres",
	"tilly": "res://Characters/Tilly.tres",
	"bentley": "res://Characters/Bentley.tres",
	"echo": "res://Characters/Echo.tres"
}

func set_just_unlocked_act(act: String) -> void:
	just_unlocked_act = act

func get_just_unlocked_act() -> String:
	return just_unlocked_act

func clear_just_unlocked_act() -> void:
	just_unlocked_act = ""

var char_unlocks := {} # {resource_path: bool}
var progression := {} # {progress_key: value}
var job_wins := {} # {job_name: bool}

const DEFAULT_HIGHEST_ACT := 1

func _ready() -> void:
	if not _signals_connected:
		if Achievements and Achievements.has_signal("achievement_unlocked"):
			Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
			_signals_connected = true
	load_unlocks()

func save_unlocks() -> void:
	var config = ConfigFile.new()
	# Save character unlocks
	for char_path in achievement_to_character.values():
		config.set_value("characters", char_path, char_unlocks.get(char_path, false))
	# Save progression
	for key in progression.keys():
		config.set_value("progression", key, progression[key])
	# Save job wins
	for job_name in job_wins.keys():
		config.set_value("job_wins", job_name, job_wins[job_name])
	var err = config.save(path)
	if err != OK:
		printerr("Something went wrong writing the config file")

func _on_achievement_unlocked(char_name: String, _achievement: Dictionary) -> void:
	var lower_char_name = char_name.to_lower()
	if achievement_to_character.has(lower_char_name):
		var char_path = achievement_to_character[lower_char_name]
		unlock_character(char_path)

func load_unlocks() -> void:
	var config = ConfigFile.new()
	var err = config.load(path)
	char_unlocks = {}
	progression = {}
	job_wins = {}
	if err == OK:
		for char_path in achievement_to_character.values():
			# Only the first character is unlocked by default
			var default_unlock = achievement_to_character.values().find(char_path) == 0
			char_unlocks[char_path] = config.get_value("characters", char_path, default_unlock)
		# Load progression
		if config.has_section("progression"):
			for key in config.get_section_keys("progression"):
				progression[key] = config.get_value("progression", key, 0)
		# Load job wins
		if config.has_section("job_wins"):
			for key in config.get_section_keys("job_wins"):
				job_wins[key] = config.get_value("job_wins", key, false)
	else:
		# If no config, unlock only the first character by default
		for i in achievement_to_character.values().size():
			char_unlocks[achievement_to_character.values()[i]] = (i == 0)
		progression["highest_act_unlocked"] = DEFAULT_HIGHEST_ACT
		save_unlocks() # Save defaults
	if not progression.has("highest_act_unlocked"):
		progression["highest_act_unlocked"] = DEFAULT_HIGHEST_ACT
		save_unlocks()

func is_character_unlocked(char_path: String) -> bool:
	return char_unlocks.get(char_path, false)

func unlock_character(char_path: String) -> void:
	if achievement_to_character.values().has(char_path):
		char_unlocks[char_path] = true
		save_unlocks()

func get_unlocked_characters() -> Array:
	var unlocked = []
	for char_path in achievement_to_character.values():
		if char_unlocks.get(char_path, false):
			unlocked.append(char_path)
	return unlocked

# progress unlocks
# maybe have environments locked initially
# maybe have the level selection locked up initially

func set_progress(key: String, value) -> void:
	progression[key] = value
	save_unlocks()

func get_progress(key: String, default_value = 0):
	var value = progression.get(key, default_value)
	return value

func get_highest_act_unlocked() -> int:
	return maxi(int(progression.get("highest_act_unlocked", DEFAULT_HIGHEST_ACT)), DEFAULT_HIGHEST_ACT)

func set_highest_act_unlocked(act_index: int) -> void:
	var target = maxi(act_index, DEFAULT_HIGHEST_ACT)
	if target == get_highest_act_unlocked():
		return
	progression["highest_act_unlocked"] = target
	save_unlocks()

func unlock_next_act(current_act_index: int) -> bool:
	var highest := get_highest_act_unlocked()
	if current_act_index != highest:
		return false
	var next_act := current_act_index + 1
	if not FW_AscensionHelper.has_act(next_act):
		return false
	set_highest_act_unlocked(next_act)
	var next_world_id: String = FW_AscensionHelper.get_world_id_for_act(next_act)
	if next_world_id != "":
		set_just_unlocked_act(next_world_id)
	return true

# Ascension level management (per-character meta-progression)
# Stored in progression dict as "ascension_<lowercase_name>": int
func set_ascension_level(character_name: String, level: int) -> void:
	var key = "ascension_" + character_name.to_lower()
	progression[key] = maxi(level, 0)  # Clamp to non-negative
	save_unlocks()

func get_ascension_level(character_name: String) -> int:
	var key = "ascension_" + character_name.to_lower()
	return progression.get(key, 0)

# Optional: Increment ascension (e.g., call on world completion)
func increment_ascension_level(character_name: String) -> void:
	var current = get_ascension_level(character_name)
	set_ascension_level(character_name, current + 1)

# Doghouse unlock management (global meta-progression)
func is_doghouse_unlocked() -> bool:
	return progression.get("doghouse_unlocked", false)

func unlock_doghouse() -> void:
	progression["doghouse_unlocked"] = true
	save_unlocks()

# Forge unlock management (global meta-progression)
func is_forge_unlocked() -> bool:
	return progression.get("forge_unlocked", false)

func unlock_forge() -> void:
	progression["forge_unlocked"] = true
	save_unlocks()

# Per-forge-item unlocks (persisted in progression as "forge_item_<name>")
func _forge_item_key(item_name: String) -> String:
	return "forge_item_" + item_name.to_lower()

func is_forge_item_unlocked(item_name: String) -> bool:
	var key = _forge_item_key(item_name)
	return progression.get(key, false)

func unlock_forge_item(item_name: String) -> void:
	var key = _forge_item_key(item_name)
	progression[key] = true
	save_unlocks()

# Garden unlock management (global meta-progression)
func is_garden_unlocked() -> bool:
	return progression.get("garden_unlocked", false)

func unlock_garden() -> void:
	progression["garden_unlocked"] = true
	save_unlocks()

# Per-garden-potion unlocks (persisted in progression as "garden_potion_<index>")
func _garden_potion_key(index: int) -> String:
	return "garden_potion_" + str(index)

func is_garden_potion_unlocked(index: int) -> bool:
	var key = _garden_potion_key(index)
	return progression.get(key, false)

func unlock_garden_potion(index: int) -> void:
	var key = _garden_potion_key(index)
	progression[key] = true
	save_unlocks()

# Solitaire unlock management (global meta-progression)
func is_solitaire_unlocked() -> bool:
	return progression.get("solitaire_unlocked", false)

func unlock_solitaire() -> void:
	progression["solitaire_unlocked"] = true
	save_unlocks()

# Sudoku unlock management (global meta-progression)
func is_sudoku_unlocked() -> bool:
	return progression.get("sudoku_unlocked", false)

func unlock_sudoku() -> void:
	progression["sudoku_unlocked"] = true
	save_unlocks()

# Job win management (for job mastery achievement)
func mark_job_win(job_name: String) -> void:
	if not job_wins.has(job_name):
		job_wins[job_name] = true
		save_unlocks()
		if is_all_jobs_won():
			Achievements.unlock_achievement("job_master")
			GDM.safe_steam_set_achievement("Mastery")

func is_all_jobs_won() -> bool:
	return job_wins.size() >= FW_JobManager.get_total_jobs()

func has_job_win(job_name: String) -> bool:
	return job_wins.get(job_name, false)

func get_job_wins_count() -> int:
	return job_wins.size()

func get_job_win_names() -> Array[String]:
	var names: Array[String] = []
	for key in job_wins.keys():
		if job_wins[key]:
			names.append(key)
	return names
