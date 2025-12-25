extends Node

# Set this to false to globally disable network features (offline mode)
var network_enabled: bool = true

# Whether we were able to reach the server on last check
var server_available: bool = false

# The base URL of your API server
#const server_url = "http://192.168.1.75:8000"
#const server_url = "http://localhost:8001"
const server_url = "https://aqserver.mcgillij.dev"

# Simple caching of the last server check to avoid hammering the server
var _last_check_time: float = 0.0
var _last_check_result: bool = false
var _cache_seconds: float = 2.0

# Optional global callback that will be called when the network is auto-disabled
var on_network_disabled: Callable = Callable()

# Set global network enabled/disabled (for user toggle like "offline mode")
func set_network_enabled(enabled: bool) -> void:
	network_enabled = enabled

# Return whether the game should attempt to use network features now
func should_use_network() -> bool:
	return network_enabled and server_available

# Checks if the server is up by hitting the root endpoint.
# - scene: Node to attach the temporary HTTPRequest to (usually a running scene root)
# - callback: Callable(result: bool) called with true if server is reachable
# - use_cache: whether to return cached result if it is recent
# - timeout_sec: not all environments expose timeout on HTTPRequest; this is kept for API parity
func is_server_up(scene: Node, callback: Callable, use_cache: bool = true, _timeout_sec: float = 5.0) -> void:
	# If networking was explicitly disabled, make sure server_available is false
	if not network_enabled:
		server_available = false
		if callback.is_valid():
			callback.call(false)
		return

	var now: float = Time.get_unix_time_from_system()
	if use_cache and now - _last_check_time < _cache_seconds:
		server_available = _last_check_result
		if callback.is_valid():
			callback.call(_last_check_result)
		return

	var http := HTTPRequest.new()

	# Connect the completed callback now (safe even before request)
	http.request_completed.connect(func(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		# Make sure http is still valid before using it
		if http.is_inside_tree():
			http.queue_free()
		var ok: bool = response_code == 200
		server_available = ok
		_last_check_time = Time.get_unix_time_from_system()
		_last_check_result = ok
		if callback.is_valid():
			callback.call(ok)
	)

	# Use provided scene or fallback to root if null
	if scene == null:
		scene = get_tree().root

	# Add the HTTPRequest deferred to avoid "Parent node is busy" errors,
	# then only call request() after the node enters the scene tree.
	scene.call_deferred("add_child", http)
	http.tree_entered.connect(func() -> void:
		# Now safe to call request because the HTTPRequest is in the scene tree
		http.request(server_url + "/")
	)

# Perform a HTTPRequest but automatically flip the network flag off if the request fails.
# - on_complete: Callable(result:int, response_code:int, headers:PackedStringArray, body:PackedByteArray)
# - auto_disable_on_fail: if true, sets `network_enabled = false` when request fails
func perform_request(scene: Node, url: String, on_complete: Callable, method: int = HTTPClient.METHOD_GET, headers: PackedStringArray = PackedStringArray(), body: String = "", auto_disable_on_fail: bool = true) -> void:
	if not network_enabled:
		# Immediately call back with a connection error
		if on_complete.is_valid():
			on_complete.call(ERR_CANT_CONNECT, -1, PackedStringArray(), PackedByteArray())
		return

	var http := HTTPRequest.new()

	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		# Queue free only if inside tree
		if http.is_inside_tree():
			http.queue_free()
		var success: bool = result == OK and response_code >= 200 and response_code < 300
		server_available = success
		if not success and auto_disable_on_fail:
			network_enabled = false
			if on_network_disabled.is_valid():
				# call without blocking in case caller wants to change scene tree
				on_network_disabled.call_deferred()
		# Pass through the original request args to the caller
		if on_complete.is_valid():
			on_complete.call(result, response_code, _headers, _body)
	)

	# Use provided scene or fallback to root if null
	if scene == null:
		scene = get_tree().root

	# Defer adding the child to avoid "parent busy" errors, and only call request after tree entered
	scene.call_deferred("add_child", http)
	http.tree_entered.connect(func() -> void:
		http.request(url, headers, method, body)
	)

# Convenience wrappers
func perform_get(scene: Node, url: String, on_complete: Callable, auto_disable_on_fail: bool = true) -> void:
	var headers := PackedStringArray(["X-API-Key: your-game-api-key-2025"])
	perform_request(scene, url, on_complete, HTTPClient.METHOD_GET, headers, "", auto_disable_on_fail)

func perform_post(scene: Node, url: String, on_complete: Callable, json_body: String, auto_disable_on_fail: bool = true) -> void:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"X-API-Key: your-game-api-key-2025"
	])
	perform_request(scene, url, on_complete, HTTPClient.METHOD_POST, headers, json_body, auto_disable_on_fail)
