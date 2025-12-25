extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
	var spiral_coords := _get_target_coords()
	if spiral_coords.is_empty():
		return

	var alertness_buff: FW_Buff = load("res://Buffs/AlertnessEvasion.tres")
	CombatManager.apply_buff_intelligently(alertness_buff)

	var stage_configs := [
		{
			"stage_index": 1.0,
			"intensity": 1.05,
			"swirl_density": 9.5,
			"arc_thickness": 0.26,
			"tile_glow": 1.2,
			"trail_strength": 0.6,
			"ripple_strength": 0.35,
			"distortion_strength": 0.012,
			"chroma_shift": 0.003,
			"spark_density": 12.0,
			"noise_scale": 10.0,
			"core_color": Color(0.24, 0.48, 0.86, 1.0),
			"edge_color": Color(0.32, 0.86, 1.0, 1.0)
		},
		{
			"stage_index": 2.0,
			"intensity": 1.3,
			"swirl_density": 11.5,
			"arc_thickness": 0.2,
			"tile_glow": 1.45,
			"trail_strength": 0.85,
			"ripple_strength": 0.65,
			"distortion_strength": 0.016,
			"chroma_shift": 0.005,
			"spark_density": 18.0,
			"noise_scale": 13.0,
			"core_color": Color(0.18, 0.52, 0.94, 1.0),
			"edge_color": Color(0.36, 0.94, 1.0, 1.0)
		},
		{
			"stage_index": 3.0,
			"intensity": 1.65,
			"swirl_density": 13.5,
			"arc_thickness": 0.17,
			"tile_glow": 1.8,
			"trail_strength": 1.1,
			"ripple_strength": 0.95,
			"distortion_strength": 0.02,
			"chroma_shift": 0.0075,
			"spark_density": 24.0,
			"noise_scale": 16.0,
			"core_color": Color(0.12, 0.6, 1.0, 1.0),
			"edge_color": Color(0.48, 0.98, 1.0, 1.0)
		}
	]

	var stage_idx: int = int(clamp(level, 1, 3)) - 1
	var stage_settings: Dictionary = stage_configs[stage_idx].duplicate(true)
	var duration := 0.8 + float(level - 1) * 0.2

	var preview_settings: Dictionary = stage_settings.duplicate(true)
	preview_settings["intensity"] = min(3.0, preview_settings["intensity"] * 2.2)
	preview_settings["tile_glow"] = preview_settings["tile_glow"] * 2.3
	preview_settings["trail_strength"] = preview_settings["trail_strength"] * 1.6
	preview_settings["ripple_strength"] = preview_settings["ripple_strength"] * 0.6 + 0.35
	preview_settings["arc_thickness"] = max(0.12, preview_settings["arc_thickness"] * 1.35)
	preview_settings["chroma_shift"] = preview_settings["chroma_shift"] * 1.4

	var preview_params := {
		"grid_cells": spiral_coords,
		"grid_cell": spiral_coords[0],
		"duration": 0.14,
		"shader_params": preview_settings
	}
	trigger_visual_effects("on_cast", preview_params)

	grid._handle_coords_booster(spiral_coords, self)

	var final_params := {
		"grid_cells": spiral_coords,
		"grid_cell": spiral_coords[0],
		"duration": duration,
		"shader_params": stage_settings
	}
	trigger_visual_effects("on_cast", final_params)

	grid._handle_coords_booster(spiral_coords, self)

func get_preview_tiles(_grid: Node) -> Variant:
	return _get_target_coords()

func _get_target_coords() -> Array:
	var coords := []
	match level:
		1:
			coords = [
				Vector2(3, 3), Vector2(3, 2), Vector2(3, 4),
				Vector2(2, 5), Vector2(4, 1), Vector2(1, 4),
				Vector2(5, 2),
			]
		2:
			coords = [
				Vector2(3, 3), Vector2(3, 4), Vector2(3, 2),
				Vector2(5, 2), Vector2(5, 3),
				Vector2(2, 5), Vector2(4, 1), Vector2(1, 4),
				Vector2(1, 3)
			]
		3:
			coords = [
				Vector2(3, 3), Vector2(3, 4), Vector2(3, 2),
				Vector2(5, 2), Vector2(5, 3),
				Vector2(2, 5), Vector2(4, 1), Vector2(1, 4),
				Vector2(1, 3), Vector2(1, 2),
				Vector2(2, 1), Vector2(4, 5), Vector2(5, 4),
			]
	return coords
