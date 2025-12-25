extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	if grid == null:
		return
	var preferred_color := ""
	if effects.has("target_color"):
		preferred_color = String(effects["target_color"]).to_lower()
	if grid.has_method("apply_color_ice"):
		grid.apply_color_ice(self, preferred_color)
