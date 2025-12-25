extends RefCounted
class_name FW_Bootstrap

const _SAVE_SERVICE_SCRIPT := preload("res://addons/fw/Save/FW_SaveService.gd")
const _SCENE_ROUTER_SCRIPT := preload("res://addons/fw/Scenes/FW_SceneRouter.gd")
const _INPUT_REBIND_SCRIPT := preload("res://addons/fw/Input/FW_InputRebindService.gd")
const _RESOURCE_CACHE_SCRIPT := preload("res://addons/fw/Resources/FW_ResourceCache.gd")
const _PRELOAD_QUEUE_SCRIPT := preload("res://addons/fw/Resources/FW_PreloadQueue.gd")
const _STATE_MACHINE_SCRIPT := preload("res://addons/fw/State/FW_StateMachine.gd")

static func init(options: Dictionary = {}) -> Dictionary:
	var warnings: Array[String] = []

	var root: Node = options.get("root", null)
	if root == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			root = tree.root

	var config: FW_ConfigService = options.get("config", null)
	if config == null and root != null:
		config = _find_first_config(root)
	if config == null:
		return {"ok": false, "error": "bootstrap.missing_config", "warnings": warnings}

	var config_path := str(options.get("config_path", FW_ConfigService.DEFAULT_PATH))
	var load_config := bool(options.get("load_config", true))
	if load_config:
		config.load(config_path)

	var apply_defaults := bool(options.get("apply_defaults", true))
	if apply_defaults:
		FW_FrameworkDefaults.apply(config)

	var services := {}

	var bus: FW_FrameworkBus = options.get("bus", null)
	if bus == null and root != null:
		bus = _find_first_bus(root)
	if bus != null:
		services["bus"] = bus
	else:
		warnings.append("missing.bus")

	var net: FW_NetService = options.get("net", null)
	if net == null and root != null:
		net = _find_first_net(root)
	if net != null:
		net.configure(config)
		services["net"] = net
	else:
		warnings.append("missing.net")

	var audio: FW_AudioService = options.get("audio", null)
	if audio == null and root != null:
		audio = _find_first_audio(root)
	if audio != null:
		audio.configure(config)
		services["audio"] = audio
	else:
		warnings.append("missing.audio")

	var save_service: Node = options.get("save", null)
	if save_service == null and root != null:
		save_service = _find_first_save(root)
	if save_service != null:
		save_service.call("configure", config)
		services["save"] = save_service
	else:
		warnings.append("missing.save")

	var scene_router: Node = options.get("scene_router", null)
	if scene_router == null and root != null:
		scene_router = _find_first_scene_router(root)
	if scene_router != null:
		scene_router.call("configure", config)
		services["scene_router"] = scene_router
	else:
		warnings.append("missing.scene_router")

	var input_rebind: Node = options.get("input_rebind", null)
	if input_rebind == null and root != null:
		input_rebind = _find_first_input_rebind(root)
	if input_rebind != null:
		# Framework can't know your action list; caller should pass actions explicitly.
		# If you want bootstrap to handle this, inject: {"input_actions": FW_InputActions.new()...}
		var input_actions: Variant = options.get("input_actions", null)
		if input_actions != null:
			input_rebind.call("configure", config, input_actions, options.get("input_autosave", true))
		services["input_rebind"] = input_rebind
	else:
		var opted_in := options.has("input_rebind") or options.has("input_actions") or bool(options.get("require_input_rebind", false))
		if opted_in:
			warnings.append("missing.input_rebind")

	var resource_cache: Node = options.get("resource_cache", null)
	if resource_cache == null and root != null and bool(options.get("create_resource_cache", false)):
		resource_cache = _RESOURCE_CACHE_SCRIPT.new()
		root.add_child(resource_cache)
	if resource_cache == null and root != null:
		resource_cache = _find_first_resource_cache(root)
	if resource_cache != null:
		resource_cache.call("configure", config)
		services["resource_cache"] = resource_cache
	else:
		var opted_in_cache := options.has("resource_cache") or bool(options.get("create_resource_cache", false)) or bool(options.get("require_resource_cache", false))
		if opted_in_cache:
			warnings.append("missing.resource_cache")

	var preload_queue: Node = options.get("preload_queue", null)
	if preload_queue == null and root != null and bool(options.get("create_preload_queue", false)):
		preload_queue = _PRELOAD_QUEUE_SCRIPT.new()
		root.add_child(preload_queue)
	if preload_queue == null and root != null:
		preload_queue = _find_first_preload_queue(root)
	if preload_queue != null:
		preload_queue.call("configure", config, resource_cache)
		services["preload_queue"] = preload_queue
	else:
		var opted_in_preload := options.has("preload_queue") or bool(options.get("create_preload_queue", false)) or bool(options.get("require_preload_queue", false))
		if opted_in_preload:
			warnings.append("missing.preload_queue")

	var state_machine: Node = options.get("state_machine", null)
	if state_machine == null and root != null and bool(options.get("create_state_machine", false)):
		state_machine = _STATE_MACHINE_SCRIPT.new()
		root.add_child(state_machine)
	if state_machine == null and root != null:
		state_machine = _find_first_state_machine(root)
	if state_machine != null:
		services["state_machine"] = state_machine
	else:
		var opted_in_sm := options.has("state_machine") or bool(options.get("create_state_machine", false)) or bool(options.get("require_state_machine", false))
		if opted_in_sm:
			warnings.append("missing.state_machine")

	var apply_window_prefs := bool(options.get("apply_window_prefs", true))
	var window_prefs: FW_WindowPrefs = options.get("window_prefs", null)
	if window_prefs == null and root != null:
		window_prefs = _find_first_window_prefs(root)
	if window_prefs != null:
		window_prefs.configure(config)
		if apply_window_prefs:
			if window_prefs.is_inside_tree():
				window_prefs.apply_to_current_window()
			else:
				warnings.append("window_prefs.not_in_tree")
		services["window_prefs"] = window_prefs
	else:
		warnings.append("missing.window_prefs")

	var init_steam := bool(options.get("init_steam", false))
	var steam: FW_SteamService = options.get("steam", null)
	if steam == null and root != null:
		steam = _find_first_steam(root)
	if steam != null:
		steam.configure(config)
		if init_steam:
			var ok := steam.initialize()
			if not ok:
				warnings.append("steam.initialize_failed")
		services["steam"] = steam
	else:
		warnings.append("missing.steam")

	return {"ok": true, "services": services, "warnings": warnings}

static func _find_first_config(root: Node) -> FW_ConfigService:
	for c in root.get_children():
		if c is FW_ConfigService:
			return c
	return null

static func _find_first_bus(root: Node) -> FW_FrameworkBus:
	for c in root.get_children():
		if c is FW_FrameworkBus:
			return c
	return null

static func _find_first_net(root: Node) -> FW_NetService:
	for c in root.get_children():
		if c is FW_NetService:
			return c
	return null

static func _find_first_audio(root: Node) -> FW_AudioService:
	for c in root.get_children():
		if c is FW_AudioService:
			return c
	return null

static func _find_first_window_prefs(root: Node) -> FW_WindowPrefs:
	for c in root.get_children():
		if c is FW_WindowPrefs:
			return c
	return null


static func _find_first_save(root: Node) -> Node:
	for c in root.get_children():
		if c.get_script() == _SAVE_SERVICE_SCRIPT:
			return c
	return null

static func _find_first_scene_router(root: Node) -> Node:
	for c in root.get_children():
		if c.get_script() == _SCENE_ROUTER_SCRIPT:
			return c
	return null

static func _find_first_input_rebind(root: Node) -> Node:
	for c in root.get_children():
		if c.get_script() == _INPUT_REBIND_SCRIPT:
			return c
	return null

static func _find_first_resource_cache(root: Node) -> Node:
	for c in root.get_children():
		if c.get_script() == _RESOURCE_CACHE_SCRIPT:
			return c
	return null

static func _find_first_preload_queue(root: Node) -> Node:
	for c in root.get_children():
		if c.get_script() == _PRELOAD_QUEUE_SCRIPT:
			return c
	return null

static func _find_first_state_machine(root: Node) -> Node:
	for c in root.get_children():
		if c.get_script() == _STATE_MACHINE_SCRIPT:
			return c
	return null

static func _find_first_steam(root: Node) -> FW_SteamService:
	for c in root.get_children():
		if c is FW_SteamService:
			return c
	return null
