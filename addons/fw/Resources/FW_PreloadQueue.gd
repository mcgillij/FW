extends Node
class_name FW_PreloadQueue

signal progress(current: int, total: int, path: String)
signal completed(results: Dictionary)
signal cancelled()

const _SECTION := &"resources"
const _ENABLED_KEY := &"preload_enabled"
const _ITEMS_PER_FRAME_KEY := &"preload_items_per_frame"

@export var enabled := true
@export var items_per_frame := 1

var _config: FW_ConfigService
var _cache: Variant

var _running := false
var _paths: Array[String] = []
var _i := 0
var _results: Dictionary = {}

func configure(config: FW_ConfigService, cache: Variant = null) -> void:
	_config = config
	_cache = cache
	if _config != null:
		enabled = _config.get_bool(_SECTION, _ENABLED_KEY, enabled)
		items_per_frame = _config.get_int(_SECTION, _ITEMS_PER_FRAME_KEY, items_per_frame)
	items_per_frame = max(1, items_per_frame)

func start(paths: Array) -> void:
	_paths = []
	for p in paths:
		_paths.append(str(p))
	_i = 0
	_results = {}
	_running = true
	set_process(true)

func cancel() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	cancelled.emit()

func is_running() -> bool:
	return _running

func get_results() -> Dictionary:
	return _results

func _process(_delta: float) -> void:
	if not _running:
		return

	if not enabled:
		# Consider this a no-op preload; still emit completed for callers.
		_running = false
		set_process(false)
		completed.emit(_results)
		return

	var total := _paths.size()
	if _i >= total:
		_running = false
		set_process(false)
		completed.emit(_results)
		return

	var n := min(items_per_frame, total - _i)
	for _k in range(n):
		var path := _paths[_i]
		var r: Dictionary
		if _cache != null and _cache.has_method("get_result"):
			r = _cache.call("get_result", path)
		else:
			# Uncached load.
			if not ResourceLoader.exists(path):
				r = {"ok": false, "error": "resource.missing", "path": path}
			else:
				var res := ResourceLoader.load(path)
				r = {"ok": res != null, "path": path, "resource": res}
				if res == null:
					r["error"] = "resource.load_failed"

		_results[path] = r
		_i += 1
		progress.emit(_i, total, path)
