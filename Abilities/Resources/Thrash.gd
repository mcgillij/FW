extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	var random_list = FW_GridUtils.get_random_positions(grid.main_array, GDM.grid.width, GDM.grid.height, 7)
	grid._handle_coords_booster(random_list, self)

	# Trigger randomized thrash VFX
	var params = {}
	params["seed"] = randi()
	params["splatter_count"] = randi() % 7 + 3
	params["intensity"] = 0.9 + randf() * 0.7
	var float_cells: Array = []
	for cell in random_list:
		float_cells.append(Vector2(float(cell.x), float(cell.y)))
	params["grid_cells"] = float_cells
	params["shockwave_strength"] = 0.045 + randf() * 0.04
	params["shockwave_width"] = 0.2 + randf() * 0.06
	params["chromatic_offset"] = 0.003 + randf() * 0.002
	params["warp_intensity"] = 0.16 + randf() * 0.12
	params["flash_strength"] = 0.85 + randf() * 0.45
	params["grain_intensity"] = 0.22 + randf() * 0.3
	params["flare_intensity"] = 0.7 + randf() * 0.35
	params["smear_strength"] = 0.45 + randf() * 0.25
	params["splatter_gamma"] = 0.9 + randf() * 0.3
	params["position_jitter"] = 0.07 + randf() * 0.05
	var fallback_origin := Vector2(0.5, 0.5)
	if typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
		fallback_origin = _params["origin_position"]
	var origin := fallback_origin
	var norm_positions: Array = []
	var viewport := grid.get_viewport()
	if viewport and typeof(GDM) != TYPE_NIL and GDM and GDM.grid:
		for cell in float_cells:
			if typeof(cell) == TYPE_VECTOR2:
				var norm = GDM.grid.grid_cell_to_normalized_target(int(cell.x), cell.y, viewport)
				norm.x = clamp(norm.x, 0.0, 1.0)
				norm.y = clamp(norm.y, 0.0, 1.0)
				norm_positions.append(norm)
	if norm_positions.size() > 0:
		var avg := Vector2.ZERO
		for norm in norm_positions:
			avg += norm
		origin = avg / norm_positions.size()
		params["positions"] = norm_positions
		params["target_position"] = origin
	if float_cells.size() > 0:
		params["grid_cell"] = float_cells[0]
	params["target_position"] = params.get("target_position", origin)
	params["origin_position"] = origin
	trigger_visual_effects("on_cast", params)

func get_preview_tiles(grid: Node) -> Variant:
	if grid == null:
		return {}
	var width: int = _resolve_grid_dimension(grid, "width", 0)
	var height: int = _resolve_grid_dimension(grid, "height", 0)
	if width <= 0 or height <= 0:
		return {}
	var pool = FW_GridUtils.get_clearable_positions(grid.main_array, width, height)
	return {
		"mode": "random_sample",
		"pool": pool,
		"sample_size": 7,
		"interval": 0.4
	}

func _resolve_grid_dimension(grid: Node, property_name: String, fallback: int) -> int:
	var resolved := fallback
	var value = grid.get(property_name)
	if typeof(value) == TYPE_INT:
		resolved = value
	elif typeof(value) == TYPE_FLOAT:
		resolved = int(value)
	elif typeof(GDM) != TYPE_NIL and GDM and GDM.grid:
		var global_value = GDM.grid.get(property_name)
		if typeof(global_value) == TYPE_INT:
			resolved = global_value
		elif typeof(global_value) == TYPE_FLOAT:
			resolved = int(global_value)
	return resolved
