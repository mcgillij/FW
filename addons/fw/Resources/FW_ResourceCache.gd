extends Node
class_name FW_ResourceCache

# Simple LRU-ish resource cache.
# Designed to be safe in unit tests: no SceneTree required, no file IO.

const _SECTION := &"resources"
const _ENABLED_KEY := &"cache_enabled"
const _MAX_ENTRIES_KEY := &"cache_max_entries"

@export var enabled := true
@export var max_entries := 256 # 0/negative means unlimited

var _config: FW_ConfigService
var _cache: Dictionary = {} # path:String -> Resource
var _lru: Array[String] = []

func configure(config: FW_ConfigService) -> void:
	_config = config
	if _config != null:
		enabled = _config.get_bool(_SECTION, _ENABLED_KEY, enabled)
		max_entries = _config.get_int(_SECTION, _MAX_ENTRIES_KEY, max_entries)

func clear() -> void:
	_cache.clear()
	_lru.clear()

func clear_path(path: String) -> void:
	_cache.erase(path)
	_lru.erase(path)

func get_result(path: String) -> Dictionary:
	if path.is_empty():
		return {"ok": false, "error": "resource.empty_path"}
	if not enabled:
		return _load_uncached(path)

	if _cache.has(path):
		_touch(path)
		return {"ok": true, "path": path, "resource": _cache[path], "cached": true}

	var r := _load_uncached(path)
	if not r.get("ok", false):
		return r
	_cache[path] = r["resource"]
	_touch(path)
	_evict_if_needed()
	return {"ok": true, "path": path, "resource": r["resource"], "cached": false}

func get_resource(path: String) -> Resource:
	var r := get_result(path)
	return r.get("resource", null)

func get_typed(path: String, expected: Variant) -> Dictionary:
	var r := get_result(path)
	if not r.get("ok", false):
		return r
	var res: Resource = r.get("resource", null)
	if res == null:
		return {"ok": false, "error": "resource.load_failed", "path": path}

	if expected == null:
		return r

	# expected can be:
	# - String / StringName: class name (e.g., "Texture2D")
	# - Script: exact script match
	if expected is String or expected is StringName:
		var cls := str(expected)
		if not res.is_class(cls):
			return {"ok": false, "error": "resource.type_mismatch", "path": path, "expected": cls, "got": res.get_class()}
		return r

	if expected is Script:
		if res.get_script() != expected:
			return {"ok": false, "error": "resource.script_mismatch", "path": path}
		return r

	return {"ok": false, "error": "resource.unknown_expected_type", "path": path}

func _load_uncached(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {"ok": false, "error": "resource.missing", "path": path}
	var res := ResourceLoader.load(path)
	if res == null:
		return {"ok": false, "error": "resource.load_failed", "path": path}
	return {"ok": true, "path": path, "resource": res}

func _touch(path: String) -> void:
	_lru.erase(path)
	_lru.append(path)

func _evict_if_needed() -> void:
	if max_entries <= 0:
		return
	while _lru.size() > max_entries:
		var oldest := _lru.pop_front()
		_cache.erase(oldest)
