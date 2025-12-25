extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	if grid == null:
		return
	var cluster_size: int = 2
	if effects.has("cluster_size"):
		cluster_size = max(1, int(effects["cluster_size"]))
	elif effects.has("tile_count"):
		var total_tiles: int = max(1, int(effects["tile_count"]))
		var root_tiles := sqrt(float(total_tiles))
		cluster_size = max(1, int(ceil(root_tiles)))
	if grid.has_method("apply_castle_concrete"):
		grid.apply_castle_concrete(self, cluster_size)
