extends Node

signal achievement_unlocked(name: String, achievement: Dictionary)
signal achievement_updated(name: String, achievement: Dictionary)
signal achievement_reset(name: String, achievement: Dictionary)
signal all_achievements_unlocked

var _signals_connected := false
var current_achievements: Dictionary = {}
var unlocked_achievements: Dictionary = {}
var achievements_keys: PackedStringArray = []

## Basic achievement
# in the root achievements.json has the dictionary structure

var user_dir = OS.get_user_data_dir() + "/save"
var user_file = "achievements.json"
var local_source_file = "res://achievements.json"

func _ready():
	if not _signals_connected:
		achievement_updated.connect(_on_achievement_updated)
		achievement_unlocked.connect(_on_achievement_updated)
		_signals_connected = true
	_create_save_directory(user_dir)
	_prepare_achievements()

func get_achievement(a_name: String) -> Dictionary:
	if current_achievements.has(a_name):
		return current_achievements[a_name]
	return {}

func update_achievement(a_name: String, data: Dictionary) -> void:
	if current_achievements.has(a_name):
		current_achievements[a_name].merge(data, true)
		achievement_updated.emit(a_name, data)

func increment_achievement_progress_by_type(type: String = "eliminate_monsters", amount: int = 1) -> void:
	for key in current_achievements.keys():
		var achievement = current_achievements[key]
		if achievement.has("type") and achievement["type"] == type and not achievement["unlocked"]:
			achievement["current_progress"] += amount
			if achievement["current_progress"] >= achievement["count_goal"]:
				achievement["current_progress"] = achievement["count_goal"]
				unlock_achievement(key)
			else:
				update_achievement(key, {"current_progress": achievement["current_progress"]})

func unlock_achievement(a_name: String, force:bool = false) -> void:
	if current_achievements.has(a_name):
		var achievement: Dictionary = current_achievements[a_name]
		if not achievement["unlocked"] or force:
			achievement["unlocked"] = true
			achievement["current_progress"] = 100.0
			unlocked_achievements[a_name] = achievement
			achievement_unlocked.emit(a_name, achievement)
			if EventBus and EventBus.has_signal("achievement_trigger"):
				var achievement_data = Achievements.get_achievement(a_name)
				EventBus.achievement_trigger.emit(achievement_data)

func reset_achievement(a_name: String, data: Dictionary = {}) -> void:
	if current_achievements.has(a_name):
		current_achievements[a_name].merge(data, true)
		current_achievements[a_name]["unlocked"] = false
		current_achievements[a_name]["current_progress"] = 0.0
		if unlocked_achievements.has(a_name):
			unlocked_achievements.erase(a_name)
		achievement_reset.emit(a_name, current_achievements[a_name])
		achievement_updated.emit(a_name, current_achievements[a_name])

func _read_from_local_source() -> void:
	if FileAccess.file_exists(local_source_file):
		var content = JSON.parse_string(FileAccess.get_file_as_string(local_source_file))
		if content == null:
			push_error("Achievements: Failed reading achievement file {path}".format({"path": local_source_file}))
			return
		current_achievements = content
		achievements_keys = current_achievements.keys()

func _create_save_directory(path: String) -> void:
	DirAccess.make_dir_absolute(path)

func _prepare_achievements() -> void:
	_read_from_local_source()
	_sync_achievements_with_saved_file()
	for key in current_achievements.keys():
		if current_achievements[key]["unlocked"]:
			unlocked_achievements[key] = current_achievements[key]

func _sync_achievements_with_saved_file() -> void:
	var saved_file_path = _save_file_path()
	if FileAccess.file_exists(saved_file_path):
		var content = FileAccess.open(saved_file_path, FileAccess.READ)
		if content == null:
			push_error("Achievements: Failed reading saved achievement file {path} with error {error}".format({"path": saved_file_path, "error": FileAccess.get_open_error()}))
			return
		var achievements = JSON.parse_string(content.get_as_text())
		if achievements:
			current_achievements.merge(achievements, true)

func _check_if_all_achievements_are_unlocked() -> bool:
	var all_unlocked = unlocked_achievements.size() == current_achievements.size()
	if all_unlocked:
		all_achievements_unlocked.emit()
	return all_unlocked

func _update_save_file() -> void:
	if current_achievements.is_empty():
		return
	var saved_file_path = _save_file_path()
	var file = FileAccess.open(saved_file_path, FileAccess.WRITE)
	if file == null:
		push_error("Achievements: Failed writing saved achievement file {path} with error {error}".format({"path": saved_file_path, "error": FileAccess.get_open_error()}))
		return
	file.store_string(JSON.stringify(current_achievements))
	file.close()

func _save_file_path() -> String:
	return user_dir.path_join(user_file)

func _on_achievement_updated(_name: String, _achievement: Dictionary) -> void:
	_update_save_file()
	_check_if_all_achievements_are_unlocked()

func reset_all_achievements() -> void:
	var save_path = _save_file_path()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	current_achievements.clear()
	unlocked_achievements.clear()
	_read_from_local_source()
	for key in current_achievements.keys():
		if current_achievements[key]["unlocked"]:
			unlocked_achievements[key] = current_achievements[key]
	#FW_Debug.debug_log(["Achievements reset to default"])
