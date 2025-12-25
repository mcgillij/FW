extends CanvasLayer

class_name FW_ManaMatchVFXController

const MAX_PROJECTILES := 48
const MIN_TRAVEL_TIME := 0.24
const MAX_TRAVEL_TIME := 0.68
const BASE_TRAVEL_TIME := 0.38
const TRAVEL_DISTANCE_SLOPE := 0.0011
const STAGGER_STEP := 0.035
const MANA_BAR_Y_OFFSET := 10.0  # Offset landing position (negative = up)

var _player_targets: Dictionary = {}
var _monster_targets: Dictionary = {}
var _projectile_pool: Array[FW_ManaMatchProjectile] = []

func _ready() -> void:
	# Don't disable processing - we need tweens to work!
	layer = 120
	EventBus.mana_match_fx_requested.connect(_on_mana_match_fx_requested)
	EventBus.mana_bar_targets_ready.connect(_on_mana_bar_targets_ready)
	var viewport := get_viewport()
	if viewport:
		FW_Debug.debug_log(["ManaMatchVFX", "ready", {"layer": layer, "viewport_size": viewport.get_visible_rect().size}])
	else:
		FW_Debug.debug_log(["ManaMatchVFX", "ready", "controller_online"])
	call_deferred("_request_target_refresh")

func _exit_tree() -> void:
	if EventBus.mana_match_fx_requested.is_connected(_on_mana_match_fx_requested):
		EventBus.mana_match_fx_requested.disconnect(_on_mana_match_fx_requested)
	if EventBus.mana_bar_targets_ready.is_connected(_on_mana_bar_targets_ready):
		EventBus.mana_bar_targets_ready.disconnect(_on_mana_bar_targets_ready)

func _request_target_refresh() -> void:
	if EventBus.has_signal("request_mana_bar_targets"):
		EventBus.request_mana_bar_targets.emit()

func _on_mana_bar_targets_ready(player_targets: Dictionary, monster_targets: Dictionary) -> void:
	_player_targets = _build_target_dict(player_targets)
	_monster_targets = _build_target_dict(monster_targets)
	FW_Debug.debug_log(["ManaMatchVFX", "targets_ready", {"player": _player_targets.keys(), "monster": _monster_targets.keys()}])

func _build_target_dict(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source.keys():
		var node = source[key]
		if node and is_instance_valid(node):
			result[key.to_lower()] = weakref(node)
	return result

func _world_to_screen(point: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport:
		return viewport.get_canvas_transform() * point
	return point

func _on_mana_match_fx_requested(match_tiles: Array, _mana_totals: Dictionary, owner_is_player: bool) -> void:
	if match_tiles.is_empty():
		return
	var target_dict := _player_targets if owner_is_player else _monster_targets
	if target_dict.is_empty():
		FW_Debug.debug_log(["ManaMatchVFX", "no_targets", {"owner_is_player": owner_is_player}])
		return
	var limit: int = min(match_tiles.size(), MAX_PROJECTILES)
	FW_Debug.debug_log(["ManaMatchVFX", "launch_request", {"owner_is_player": owner_is_player, "tile_count": match_tiles.size(), "limit": limit}])
	for index in range(limit):
		var tile_data = match_tiles[index]
		var color_key := String(tile_data.get("color", "")).to_lower()
		if !target_dict.has(color_key):
			FW_Debug.debug_log(["ManaMatchVFX", "missing_target_color", color_key])
			continue
		var target_ref: WeakRef = target_dict[color_key]
		var target_node = target_ref.get_ref()
		if target_node == null:
			target_dict.erase(color_key)
			FW_Debug.debug_log(["ManaMatchVFX", "stale_target", color_key])
			continue
		var start_position_variant = _resolve_start_position(tile_data)
		if typeof(start_position_variant) != TYPE_VECTOR2:
			FW_Debug.debug_log(["ManaMatchVFX", "no_start_position", tile_data])
			continue
		var start_position: Vector2 = start_position_variant
		var target_position_variant = _get_target_position_from_node(target_node)
		if typeof(target_position_variant) != TYPE_VECTOR2:
			FW_Debug.debug_log(["ManaMatchVFX", "no_target_position", color_key])
			continue
		var target_position: Vector2 = target_position_variant
		target_position += _random_target_offset(target_node)
		var projectile := _acquire_projectile()
		var travel_time := _compute_travel_time(start_position, target_position)
		var delay: float = min(index * STAGGER_STEP, 0.3)
		var projectile_color := FW_Colors.get_mana_color(color_key)
		var release_callable := Callable(self, "_release_projectile").bind(projectile)
		projectile.launch(start_position, target_position, projectile_color, travel_time, delay, release_callable)
		FW_Debug.debug_log(["ManaMatchVFX", "launch", {"color": color_key, "start": start_position, "target": target_position, "travel": travel_time, "delay": delay}])

func _resolve_start_position(tile_data: Dictionary):
	var world_position = tile_data.get("world_position", null)
	if typeof(world_position) == TYPE_VECTOR2:
		return _world_to_screen(world_position)
	if tile_data.has("grid_position") and GDM.grid:
		var cell = tile_data["grid_position"]
		if typeof(cell) == TYPE_VECTOR2:
			var world_pos := GDM.grid.grid_to_pixel(cell.x, cell.y)
			return _world_to_screen(world_pos)
	return null

func _get_target_position_from_node(node: Object):
	if node is Control:
		var control := node as Control
		# Controls are already in screen space - no transform needed
		var center := control.get_global_rect().get_center()
		center.y += MANA_BAR_Y_OFFSET
		return center
	if node is Node2D:
		var pos := _world_to_screen(node.global_position)
		pos.y += MANA_BAR_Y_OFFSET
		return pos
	return null

func _random_target_offset(node: Object) -> Vector2:
	if node is Control:
		var control := node as Control
		var radius: float = min(control.size.x, control.size.y) * 0.2
		return Vector2(
			randf_range(-radius, radius),
			randf_range(-radius, radius)
		)
	return Vector2(
		randf_range(-16.0, 16.0),
		randf_range(-12.0, 12.0)
	)

func _compute_travel_time(start: Vector2, target: Vector2) -> float:
	var distance := start.distance_to(target)
	var computed := BASE_TRAVEL_TIME + distance * TRAVEL_DISTANCE_SLOPE
	return clamp(computed, MIN_TRAVEL_TIME, MAX_TRAVEL_TIME)

func _acquire_projectile() -> FW_ManaMatchProjectile:
	var projectile: FW_ManaMatchProjectile = null
	if !_projectile_pool.is_empty():
		projectile = _projectile_pool.pop_back()
	else:
		projectile = FW_ManaMatchProjectile.new()
		add_child(projectile)
	return projectile

func _release_projectile(projectile: FW_ManaMatchProjectile) -> void:
	if projectile == null:
		return
	if !_projectile_pool.has(projectile):
		_projectile_pool.append(projectile)
