extends Node

class_name FW_LevelManager

# Static experience configuration
static var experience_thresholds: Array = [250, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000]

var player
const POINTS_TO_ALLOCATE: int = 3

func _init(_player: FW_Player):
	player = _player

func add_xp(points: int) -> void:
	player.xp += points
	_check_level_up()

func _check_level_up() -> void:
	while player.current_level < experience_thresholds.size() and player.xp >= experience_thresholds[player.current_level - 1]:
		_level_up()

func _level_up() -> void:
	player.current_level += 1
	player.allocate_points(POINTS_TO_ALLOCATE)  # Allocate 5 points for each level up
	player.levelup = true
	# For level-up achievements we want to trigger the specific achievement
	# tied to the new level (eg. "leveledup2" for reaching level 2) rather
	# than incrementing progress on every levelup entry. This avoids
	# accidentally progressing higher-level achievements on earlier levels.
	var level_ach_key := "leveledup" + str(player.current_level)
	# If a specifically-named achievement exists, unlock it; otherwise preserve
	# previous behavior by incrementing all levelup achievements for backward
	# compatibility.
	if Achievements.get_achievement(level_ach_key).size() > 0:
		Achievements.unlock_achievement(level_ach_key)
	else:
		# Backwards compatibility: if no explicit key found, increment type as before
		Achievements.increment_achievement_progress_by_type("levelup")

func get_experience_to_next_level() -> int:
	return FW_LevelManager.get_experience_to_next_level_static(player.current_level, player.xp)

func get_progress_to_next_level() -> float:
	return FW_LevelManager.get_progress_to_next_level_static(player.current_level, player.xp)

# Static utility methods for level calculations
static func get_experience_to_next_level_static(current_level: int, current_xp: int) -> int:
	if current_level < experience_thresholds.size():
		return experience_thresholds[current_level - 1] - current_xp
	return 0  # Max level reached

static func get_progress_to_next_level_static(current_level: int, current_xp: int) -> float:
	if current_level < experience_thresholds.size():
		return float(current_xp) / experience_thresholds[current_level - 1]
	return 1.0  # Max level reached

static func get_level_from_xp(xp: int) -> int:
	var level = 1
	for threshold in experience_thresholds:
		if xp >= threshold:
			level += 1
		else:
			break
	return level

static func is_max_level(level: int) -> bool:
	return level >= experience_thresholds.size()

static func get_max_level() -> int:
	return experience_thresholds.size()
