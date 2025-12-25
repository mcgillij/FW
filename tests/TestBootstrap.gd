extends Node

var _net_done := false
var _preload_done := false
var _preload_results: Dictionary = {}
var _failed := false

func _fail(message: String) -> void:
	_failed = true
	push_error(message)

func _ready() -> void:
	# Resource cache + preload queue setup (passed into bootstrap)
	var resource_cache: Variant = preload("res://addons/fw/Resources/FW_ResourceCache.gd").new()
	var preload_queue: Variant = preload("res://addons/fw/Resources/FW_PreloadQueue.gd").new()
	var state_machine: Variant = preload("res://addons/fw/State/FW_StateMachine.gd").new()
	add_child(resource_cache)
	add_child(preload_queue)
	add_child(state_machine)

	# Input rebinding setup (passed into bootstrap; game-owned action list)
	var input_actions: Variant = preload("res://addons/fw/Input/FW_InputActions.gd").new()
	var k := InputEventKey.new()
	k.keycode = KEY_K
	var default_events: Array[InputEvent] = []
	default_events.append(k)
	input_actions.add_action(&"fw.test_action", default_events)
	var input_rebind: Variant = preload("res://addons/fw/Input/FW_InputRebindService.gd").new()
	add_child(input_rebind)

	var r := FW_Bootstrap.init({
		"init_steam": false,
		"resource_cache": resource_cache,
		"preload_queue": preload_queue,
		"state_machine": state_machine,
		"input_rebind": input_rebind,
		"input_actions": input_actions,
		"input_autosave": false,
	})
	print("FW_Bootstrap.init -> ", r)
	if not r.get("ok", false):
		_fail("bootstrap.failed")
	else:
		var services: Dictionary = r.get("services", {})
		if not services.has("scene_router"):
			_fail("bootstrap.missing.scene_router")
		if not services.has("input_rebind"):
			_fail("bootstrap.missing.input_rebind")
		if not services.has("resource_cache"):
			_fail("bootstrap.missing.resource_cache")
		if not services.has("preload_queue"):
			_fail("bootstrap.missing.preload_queue")
		if not services.has("state_machine"):
			_fail("bootstrap.missing.state_machine")

	# Save/load smoke test
	var save_result := SaveService.save_slot(0, {"hello": "world"}, {})
	print("SaveService.save_slot(0) -> ", save_result)
	if not save_result.get("ok", false):
		_fail("save.save_slot.failed")

	var load_result := SaveService.load_slot(0)
	print("SaveService.load_slot(0) -> ", load_result)
	if not load_result.get("ok", false):
		_fail("save.load_slot.failed")
	else:
		var data: Dictionary = load_result.get("data", {})
		if data.get("hello", "") != "world":
			_fail("save.load_slot.mismatch")

	# Scene router smoke test (no shader/texture configured; should not crash)
	var router := preload("res://addons/fw/Scenes/FW_SceneRouter.gd").new()
	router.enable_rotation = false
	router.configure(Config)
	add_child(router)
	print("FW_SceneRouter smoke test complete")

	# Input rebinding smoke assertions (bootstrap-configured)
	if not InputMap.has_action(&"fw.test_action"):
		_fail("input.ensure_actions_exist.failed")
	input_rebind.apply_event(&"fw.test_action", k)

	# Resource cache smoke test
	var cache_ok: Dictionary = resource_cache.call("get_result", "res://addons/fw/Config/FW_ConfigService.gd")
	if not cache_ok.get("ok", false):
		_fail("resource_cache.load_failed")

	# Preload queue smoke test (includes one missing resource)
	_preload_done = false
	_preload_results = {}
	preload_queue.completed.connect(func(results: Dictionary) -> void:
		_preload_results = results
		_preload_done = true
	)
	preload_queue.call("start", [
		"res://addons/fw/Net/FW_NetService.gd",
		"res://does_not_exist_please_ignore.tres",
	])

	# State machine smoke test
	var entered: Array[String] = []
	var exited: Array[String] = []
	var state_a := {
		"on_enter": func(_prev: StringName, _data: Variant) -> void: entered.append("a"),
		"on_exit": func(_next: StringName) -> void: exited.append("a"),
	}
	var state_b := {
		"on_enter": func(_prev: StringName, _data: Variant) -> void: entered.append("b"),
		"on_exit": func(_next: StringName) -> void: exited.append("b"),
	}
	state_machine.call("add_state", &"a", state_a)
	state_machine.call("add_state", &"b", state_b)
	var start_r: Dictionary = state_machine.call("start", &"a")
	if not start_r.get("ok", false):
		_fail("state_machine.start_failed")
	var tr: Dictionary = state_machine.call("transition_to", &"b")
	if not tr.get("ok", false):
		_fail("state_machine.transition_failed")
	if entered.size() < 2 or entered[0] != "a" or entered[1] != "b":
		_fail("state_machine.enter_order")
	if exited.is_empty() or exited[0] != "a":
		_fail("state_machine.exit_order")

	# Net smoke test: relative paths require base_url; should fail fast.
	_net_done = false
	Net.request_json(HTTPClient.METHOD_GET, "/", null, func(ok: bool, result: Dictionary) -> void:
		print("Net.request_json(relative) -> ", ok, " ", result)
		if ok:
			_fail("net.expected_failure")
		elif result.get("error", "") != "net.base_url_missing":
			_fail("net.unexpected_error")
		_net_done = true
	)

	# Unit-test mode: init using explicit instances (no autoload/tree discovery required).
	var unit_root := Node.new()
	add_child(unit_root)
	var cfg := FW_ConfigService.new()
	var net2 := FW_NetService.new()
	var audio2 := FW_AudioService.new()
	var save2 := FW_SaveService.new()
	unit_root.add_child(cfg)
	unit_root.add_child(net2)
	unit_root.add_child(audio2)
	unit_root.add_child(save2)
	var input_actions2: Variant = preload("res://addons/fw/Input/FW_InputActions.gd").new()
	var k2 := InputEventKey.new()
	k2.keycode = KEY_J
	var default_events2: Array[InputEvent] = []
	default_events2.append(k2)
	input_actions2.add_action(&"fw.test_action2", default_events2)
	var input_rebind2: Variant = preload("res://addons/fw/Input/FW_InputRebindService.gd").new()
	unit_root.add_child(input_rebind2)
	var r2 := FW_Bootstrap.init({
		"config": cfg,
		"net": net2,
		"audio": audio2,
		"save": save2,
		"input_rebind": input_rebind2,
		"input_actions": input_actions2,
		"input_autosave": false,
		"load_config": false,
		"apply_defaults": false,
		"apply_window_prefs": false,
		"init_steam": false,
	})
	print("FW_Bootstrap.init(unit-test mode) -> ", r2)
	if not r2.get("ok", false):
		_fail("bootstrap.unit_test_mode.failed")
	else:
		var services2: Dictionary = r2.get("services", {})
		if not services2.has("input_rebind"):
			_fail("bootstrap.unit_test_mode.missing.input_rebind")
		if not InputMap.has_action(&"fw.test_action2"):
			_fail("input.unit_test_mode.ensure_actions_exist.failed")

	# Audio smoke test (configure-before-ready happens via bootstrap)
	Audio.register_sfx(&"ui.click", null)
	Audio.play_sfx(&"ui.click")
	print("Audio smoke test complete")

	# Give async callbacks a moment, then cleanly free test-only nodes.
	var net_deadline_ms := Time.get_ticks_msec() + 1000
	while not _net_done and Time.get_ticks_msec() < net_deadline_ms:
		await get_tree().process_frame
	if not _net_done:
		_fail("net.timeout")
	var preload_deadline_ms := Time.get_ticks_msec() + 1000
	while not _preload_done and Time.get_ticks_msec() < preload_deadline_ms:
		await get_tree().process_frame
	if not _preload_done:
		_fail("preload.timeout")
	else:
		var ok1: Dictionary = _preload_results.get("res://addons/fw/Net/FW_NetService.gd", {})
		if not ok1.get("ok", false):
			_fail("preload.expected_ok")
		var bad: Dictionary = _preload_results.get("res://does_not_exist_please_ignore.tres", {})
		if bad.get("ok", true):
			_fail("preload.expected_missing")

	input_rebind.queue_free()
	preload_queue.queue_free()
	resource_cache.queue_free()
	state_machine.queue_free()
	if InputMap.has_action(&"fw.test_action"):
		InputMap.erase_action(&"fw.test_action")
	input_rebind2.queue_free()
	if InputMap.has_action(&"fw.test_action2"):
		InputMap.erase_action(&"fw.test_action2")
	router.queue_free()
	unit_root.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failed else 0)
