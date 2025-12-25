extends Node
class_name FW_NetService

signal availability_changed(is_available: bool)
signal network_auto_disabled

var _config: FW_ConfigService

var enabled: bool = true
var base_url: String = ""
var api_key: String = ""

var auto_disable_on_fail: bool = false

var healthcheck_path: String = "/"
var healthcheck_cache_seconds: float = 2.0

var _last_health_time: float = -1.0
var _last_health_ok: bool = false
var _last_available: bool = false

func configure(config: FW_ConfigService) -> void:
	_config = config
	_apply_from_config()
	if _config != null and not _config.changed.is_connected(_on_config_changed):
		_config.changed.connect(_on_config_changed)

func _apply_from_config() -> void:
	if _config == null:
		return
	enabled = _config.get_bool(&"net", &"enabled", true)
	base_url = _config.get_string(&"net", &"base_url", "")
	api_key = _config.get_string(&"net", &"api_key", "")
	auto_disable_on_fail = _config.get_bool(&"net", &"auto_disable_on_fail", false)
	healthcheck_path = _config.get_string(&"net", &"healthcheck_path", "/")
	healthcheck_cache_seconds = _config.get_float(&"net", &"healthcheck_cache_seconds", 2.0)

func set_network_enabled(value: bool, autosave: bool = true) -> void:
	enabled = value
	_set_available(false if not enabled else _last_available)
	if _config != null:
		_config.set_value(&"net", &"enabled", enabled, autosave)

func should_use_network() -> bool:
	return enabled and _last_available

func is_available() -> bool:
	return _last_available

func health_check(callback: Callable, use_cache: bool = true, scene: Node = null) -> void:
	if not enabled:
		_set_available(false)
		callback.call(false, {"error": "net.disabled"})
		return
	if base_url.is_empty():
		_set_available(false)
		callback.call(false, {"error": "net.base_url_missing"})
		return

	var now := Time.get_unix_time_from_system()
	if use_cache and _last_health_time >= 0.0 and (now - _last_health_time) <= healthcheck_cache_seconds:
		callback.call(_last_health_ok, {"cached": true})
		return

	var url := _join_url(base_url, healthcheck_path)
	_request_raw(HTTPClient.METHOD_GET, url, PackedStringArray(), PackedByteArray(), func(ok: bool, result: Dictionary) -> void:
		_last_health_time = now
		_last_health_ok = ok
		_set_available(ok)
		callback.call(ok, result)
	, scene)

func request_json(method: int, path_or_url: String, payload: Variant, callback: Callable, extra_headers: PackedStringArray = PackedStringArray(), scene: Node = null, auto_disable_override: Variant = null) -> void:
	if not enabled:
		_set_available(false)
		callback.call(false, {"error": "net.disabled"})
		return
	if not path_or_url.begins_with("http") and base_url.is_empty():
		_set_available(false)
		callback.call(false, {"error": "net.base_url_missing"})
		return

	var url := path_or_url
	if not url.begins_with("http"):
		url = _join_url(base_url, path_or_url)

	var headers := _build_headers(extra_headers)
	var body_bytes := PackedByteArray()
	if payload != null:
		var json := JSON.stringify(payload)
		body_bytes = json.to_utf8_buffer()

	var auto_disable := auto_disable_on_fail
	if auto_disable_override != null:
		auto_disable = bool(auto_disable_override)

	_request_raw(method, url, headers, body_bytes, func(ok: bool, result: Dictionary) -> void:
		if not ok:
			callback.call(false, result)
			return
		var text: String = str(result.get("text", ""))
		var parsed: Variant = JSON.parse_string(text)
		if parsed == null and text != "":
			callback.call(false, {"error": "net.json_parse_failed", "text": text})
			return
		callback.call(true, {"data": parsed})
	, scene, auto_disable)

func _request_raw(method: int, url: String, headers: PackedStringArray, body: PackedByteArray, callback: Callable, scene: Node = null, auto_disable: bool = false) -> void:
	if not enabled:
		_set_available(false)
		callback.call(false, {"error": "net.disabled"})
		return

	if scene == null:
		var tree := get_tree()
		if tree == null:
			_set_available(false)
			callback.call(false, {"error": "net.no_scene_tree"})
			return
		scene = tree.root

	var req := HTTPRequest.new()

	req.request_completed.connect(func(result: int, response_code: int, response_headers: PackedStringArray, response_body: PackedByteArray) -> void:
		var text := ""
		if response_body.size() > 0:
			text = response_body.get_string_from_utf8()
		var ok := (result == HTTPRequest.RESULT_SUCCESS) and (response_code >= 200 and response_code < 300)
		if not ok:
			_set_available(false)
			if auto_disable:
				set_network_enabled(false, true)
				network_auto_disabled.emit()
			callback.call(false, {
				"error": "net.request_failed",
				"result": result,
				"status": response_code,
				"text": text,
			})
			if req.is_inside_tree():
				req.queue_free()
			return
		_set_available(true)
		callback.call(true, {
			"status": response_code,
			"headers": response_headers,
			"body": response_body,
			"text": text,
		})
		if req.is_inside_tree():
			req.queue_free()
	)

	scene.call_deferred("add_child", req)
	req.tree_entered.connect(func() -> void:
		var err: int = req.request_raw(url, headers, method, body)
		if err != OK:
			_set_available(false)
			if req.is_inside_tree():
				req.queue_free()
			callback.call(false, {"error": "net.request_setup_failed", "code": err})
	)

func _build_headers(extra_headers: PackedStringArray) -> PackedStringArray:
	var headers := PackedStringArray()
	headers.append("Content-Type: application/json")
	if not api_key.is_empty():
		headers.append("X-API-Key: %s" % api_key)
	for h in extra_headers:
		headers.append(h)
	return headers

func _join_url(a: String, b: String) -> String:
	if a.ends_with("/") and b.begins_with("/"):
		return a + b.substr(1)
	if not a.ends_with("/") and not b.begins_with("/"):
		return a + "/" + b
	return a + b

func _set_available(ok: bool) -> void:
	if _last_available == ok:
		return
	_last_available = ok
	availability_changed.emit(ok)

func _on_config_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section != &"net":
		return
	_apply_from_config()
