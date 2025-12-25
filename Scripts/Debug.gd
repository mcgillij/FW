class_name FW_Debug

# Runtime toggle for debugging (can disable even in debug builds)
static var enabled: bool = true

enum Level {
	ERROR,
	WARN,
	INFO,
	DEBUG,
	VERBOSE
}

static var level: Level = Level.DEBUG
static var level_names: Array[String] = ["Error", "Warn", "Info", "Debug", "Verbose"]
static var _levels: Array[Level] = [Level.ERROR, Level.WARN, Level.INFO, Level.DEBUG, Level.VERBOSE]

static func set_level(value: int) -> void:
	level = _clamp_level(value)

static func _clamp_level(value: int) -> Level:
	var clamped: int = clamp(value, 0, _levels.size() - 1)
	return _levels[clamped]

static func _should_log(target_level: Level) -> bool:
	if not enabled:
		return false
	if not OS.is_debug_build():
		return false
	return int(target_level) <= int(level)

# Efficient debug logging that handles multiple arguments like print()
static func debug_log(args: Array, target_level: Level = Level.DEBUG) -> void:
	if not _should_log(target_level):
		return
	var msg := " ".join(args.map(func(x): return str(x)))
	print(msg)

# Convenience functions with levels
static func error(msg: String) -> void:
	_log(Level.ERROR, "[ERROR] " + msg)

static func warn(msg: String) -> void:
	_log(Level.WARN, "[WARN] " + msg)

static func info(msg: String) -> void:
	_log(Level.INFO, "[INFO] " + msg)

static func debug(msg: String) -> void:
	_log(Level.DEBUG, "[DEBUG] " + msg)

static func verbose(msg: String) -> void:
	_log(Level.VERBOSE, "[VERBOSE] " + msg)

static func _log(target_level: Level, msg: String) -> void:
	if not _should_log(target_level):
		return
	print(msg)
