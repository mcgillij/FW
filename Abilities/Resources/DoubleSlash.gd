extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	var coords := _get_target_coords()
	grid._handle_coords_booster(coords, self)
	var effect_params := {
		"grid_cells": coords,
		"tier": float(level),
		"intensity": 1.0 + 0.45 * float(level - 1)
	}
	trigger_visual_effects("on_cast", effect_params)

func get_preview_tiles(_grid: Node) -> Variant:
	return _get_target_coords()

func _get_target_coords() -> Array:
	var coords = []
	match level:
		1:
			coords = [
				Vector2(3, 2),
				Vector2(2, 3),
				Vector2(4, 3),
				Vector2(3, 4),
			]
		2:
			coords = [
				Vector2(1, 3),
				Vector2(2, 4),
				Vector2(2, 2),
				Vector2(3, 3),

				Vector2(4, 4),
				Vector2(4, 2),
				Vector2(5, 3),
			]
		3:
			coords = [
				Vector2(1, 3),
				Vector2(2, 4),
				Vector2(2, 2),
				Vector2(3, 5),

				Vector2(3, 3),
				Vector2(3, 1),
				Vector2(4, 2),
				Vector2(4, 4),

				Vector2(5, 3)
			]
	return coords
