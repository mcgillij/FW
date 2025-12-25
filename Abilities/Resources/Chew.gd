extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
    var color = _get_target_color()
    
    # Collect positions of pink tiles for VFX targeting
    var pink_cells = _collect_color_tiles(grid, color)
    
    # Trigger visual effect
    trigger_visual_effects("on_cast", {
        "grid_cells": pink_cells,
        "duration": 0.8
    })
    
    # Perform the actual color clearing
    grid._handle_color_booster(color, self)

func get_preview_tiles(grid: Node) -> Variant:
    var color = _get_target_color()
    return _collect_color_tiles(grid, color)

func _get_target_color() -> String:
    return "pink"

func _collect_color_tiles(grid: Node, color: String) -> Array:
    if grid == null:
        return []
    var width: int = _resolve_grid_dimension(grid, "width", 0)
    var height: int = _resolve_grid_dimension(grid, "height", 0)
    return FW_GridUtils.get_tiles_by_color(grid.main_array, width, height, color)

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
