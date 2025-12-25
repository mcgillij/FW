extends FW_Ability

# Claw ability VFX contract note:
# This ability follows the project's canonical VFX contract (see docs/vfx.md).
# Prefer providing `grid_cells` (Array[Vector2]) for scene effects. Because claw
# triggers shader overlays per-row, we also provide a single `grid_cell` so the
# CombatVisualEffectsManager can compute normalized shader uniforms.


func activate_booster(grid: Node, _params) -> void:
	var claw_rows := _get_target_rows(grid)
	if claw_rows.is_empty():
		return

	var grid_width := _resolve_grid_dimension(grid, "width", 7)
	var center_col := float(grid_width) * 0.5 - 0.5
	var grid_cells: Array = []
	for r in claw_rows:
		grid_cells.append(Vector2(center_col, float(r)))

	if EventBus.has_signal("debug_log"):
		FW_Debug.debug_log(["CLAW VFX DEBUG: rows=%s" % [claw_rows]])

	var vfx_params := {
		"grid_cells": grid_cells,
		"grid_cell": grid_cells[0],
		"duration": effect_duration,
		"row_variant": min(3, claw_rows.size()),
		"claw_rows": claw_rows,
		"claw_anchor_col": center_col
	}
	var row_count := claw_rows.size()
	var level_factor := float(row_count - 1)
	vfx_params["slash_intensity"] = 1.3 * (1.0 + level_factor * 0.35)
	vfx_params["glow_intensity"] = 1.0 + level_factor * 0.25
	vfx_params["spark_density"] = clamp(0.35 + level_factor * 0.18, 0.0, 0.95)
	vfx_params["scratch_frequency"] = 4.0 + level_factor * 0.8
	trigger_visual_effects("on_cast", vfx_params)

	grid._handle_line_booster(self, claw_rows, "row")

func get_preview_tiles(grid: Node) -> Variant:
	var claw_rows := _get_target_rows(grid)
	var tiles: Array = []
	var grid_width := _resolve_grid_dimension(grid, "width", 7)
	for row in claw_rows:
		for col in grid_width:
			tiles.append(Vector2(col, row))
	return tiles

func _get_target_rows(grid: Node) -> Array:
	var rows: Array = []
	var height := _resolve_grid_dimension(grid, "height", 7)
	@warning_ignore("integer_division")
	var center := int((height - 1) / 2)
	match level:
		1:
			rows = [center]
		2:
			rows = [center - 2, center + 2]
		3:
			rows = [center - 2, center, center + 2]
	for i in range(rows.size() - 1, -1, -1):
		var idx: int = rows[i]
		if idx < 0 or idx >= height:
			rows.remove_at(i)
	return rows

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
