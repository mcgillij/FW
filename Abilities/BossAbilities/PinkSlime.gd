extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	if grid == null:
		return
	var slime_tiles: int = 3
	if effects.has("tile_count"):
		slime_tiles = int(effects["tile_count"])
	elif effects.has("slime_tiles"):
		slime_tiles = int(effects["slime_tiles"])
	slime_tiles = max(slime_tiles, 0)
	if grid.has_method("apply_pink_slime"):
		grid.apply_pink_slime(self, slime_tiles)
