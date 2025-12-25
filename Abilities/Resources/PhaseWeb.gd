extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	var coords := _get_target_coords()
	grid._handle_coords_booster(coords, self)
	# Trigger visual effect: hand off raw grid coords to the manager so it can
	# perform a consistent, camera-aware projection into screen space.
	var col = FW_Colors.get_color("enthusiasm") if FW_Colors.has_color("enthusiasm") else FW_Colors.enthusiasm
	# Convert integer coords to float grid positions for precise center targeting
	var grid_cells = []
	for c in coords:
		grid_cells.append(Vector2(float(c.x), float(c.y)))

	trigger_visual_effects("on_cast", {"grid_cells": grid_cells, "duration": 1.1, "color": col})

func get_preview_tiles(_grid: Node) -> Variant:
	return _get_target_coords()

func _get_target_coords() -> Array:
	var coords = []
	match level:
		1:
			coords = [
				Vector2(3, 3),
				Vector2(3, 1),
				Vector2(1, 3),
				Vector2(3, 5),
				Vector2(5, 3),
			]
		2:
			coords = [
				Vector2(1, 5),
				Vector2(1, 3),
				Vector2(1, 1),
				Vector2(3, 3),

				Vector2(3, 5),
				Vector2(3, 1),
				Vector2(5, 5),
				Vector2(5, 3),
				Vector2(5, 1),
			]
		3:
			coords = [
				Vector2(1, 5),
				Vector2(1, 3),
				Vector2(1, 1),
				Vector2(3, 3),

				Vector2(3, 5),
				Vector2(3, 1),
				Vector2(5, 5),
				Vector2(5, 3),
				Vector2(5, 1),

				Vector2(2, 4),
				Vector2(2, 2),
				Vector2(4, 4),
				Vector2(4, 2),
			]
	return coords
