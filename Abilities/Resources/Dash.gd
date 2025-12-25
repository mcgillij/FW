extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
    var color = _get_target_color()
    grid._handle_color_booster(color, self)
    # Trigger dash VFX: pass origin and direction if provided by caller; fallback to center/right
    var params = _params if _params != null else {}
    if typeof(params) != TYPE_DICTIONARY:
        params = {}
    if not params.has("origin_position"):
        params["origin_position"] = Vector2(0.5, 0.5)
    if not params.has("direction"):
        params["direction"] = Vector2(1.0, 0.0)
    # Optional power scaling
    params["intensity"] = params.get("power", 1.0)
    trigger_visual_effects("on_cast", params)

func get_preview_tiles(grid: Node) -> Variant:
    var color = _get_target_color()
    return _collect_color_tiles(grid, color)

func _get_target_color() -> String:
    return "green"

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
