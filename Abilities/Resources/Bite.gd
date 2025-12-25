extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	var bite_cols := _get_target_columns(grid)

	# Emit a visual effect for each column to allow overlay alignment
	for c in bite_cols:
		# Ask the manager to compute the canonical projection from grid cell
		# viewport available via manager; no need to store locally here
		@warning_ignore("integer_division")
		var center_row = float(GDM.grid.height/2 - 0.5)

		if EventBus.has_signal("debug_log"):
			FW_Debug.debug_log(["BITE VFX DEBUG: requesting manager compute for col=%d row=%s" % [c, str(center_row)]])
		else:
			FW_Debug.debug_log(["BITE VFX DEBUG: requesting manager compute for col=%d row=%s" % [c, str(center_row)]])

		var cell_vec = Vector2(float(c), center_row)
		trigger_visual_effects("on_cast", {"grid_cells": [cell_vec], "grid_cell": cell_vec, "duration": 0.6})

	# Perform the actual column clearing
	grid._handle_line_booster(self, bite_cols, "col")

func get_preview_tiles(grid: Node) -> Variant:
	var bite_cols := _get_target_columns(grid)
	var tiles: Array = []
	var grid_height := _resolve_grid_dimension(grid, "height", 7)
	for col in bite_cols:
		for row in grid_height:
			tiles.append(Vector2(col, row))
	return tiles

func _get_target_columns(grid: Node) -> Array:
	var cols: Array = []
	var width := _resolve_grid_dimension(grid, "width", 7)
	@warning_ignore("integer_division")
	var center := int((width - 1) / 2)
	match level:
		1:
			cols = [center]
		2:
			cols = [center - 2, center + 2]
		3:
			cols = [center - 2, center, center + 2]
	for i in range(cols.size() - 1, -1, -1):
		var idx: int = cols[i]
		if idx < 0 or idx >= width:
			cols.remove_at(i)
	return cols

func _resolve_grid_dimension(grid: Node, property_name: String, fallback: int) -> int:
	var resolved := fallback
	if grid != null:
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
