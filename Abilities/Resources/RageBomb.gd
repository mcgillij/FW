extends FW_Ability

class_name FW_Ragebomb

var player_color := Color.RED
var enemy_color := Color.DARK_RED

func activate_booster(grid: Node, _params) -> void:
    grid._handle_sinker_booster(self)

func get_preview_tiles(grid: Node) -> Variant:
    if grid == null:
        return {}
    var width := _resolve_grid_dimension(grid, "width", 0)
    var height := _resolve_grid_dimension(grid, "height", 0)
    if width <= 0 or height <= 0:
        return {}
    return {
        "mode": "sinker_sequence",
        "ability": self,
        "interval": 1.4,
        "step_delay": 0.085,
        "step_hold": 0.1,
        "explosion_hold": 0.4,
        "sequence_type": "ragebomb"
    }

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
