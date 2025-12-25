extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	if grid == null:
		return
	var lock_count: int = 5
	if effects.has("lock_count"):
		lock_count = int(effects["lock_count"])
	elif effects.has("tile_count"):
		lock_count = int(effects["tile_count"])
	lock_count = max(lock_count, 0)
	if grid.has_method("apply_chains_lock"):
		grid.apply_chains_lock(self, lock_count)
