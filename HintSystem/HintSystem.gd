extends Node

var hint = null
var hint_color: String = ""
var hint_effect: PackedScene

var grid = null

func _ready() -> void:
    pass

func set_grid(grid_ref) -> void:
    grid = grid_ref

func get_hints() -> Array:
    var hint_array = []
    var array_copy = grid.copy_array(grid.main_array)
    var directions = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)] # right, up, left, down

    for i in range(GDM.grid.width):
        for j in range(GDM.grid.height):
            if array_copy[i][j] != null and !grid.obstacle_manager.restricted_move(Vector2(i, j)):
                for dir in directions:
                    var new_pos = Vector2(i, j) + dir
                    if GDM.grid.is_in_grid(new_pos) and !grid.obstacle_manager.restricted_move(new_pos):
                        if switch_and_check(Vector2(i, j), dir, array_copy):
                            # Store as a move tuple to avoid duplicates
                            hint_array.append({ "from": Vector2(i, j), "to": new_pos })
    return hint_array

func generate_hint() -> void:
    var hints = get_hints()
    if hints != null and hints.size() > 0:
        destroy_hint()
        var move = hints[randi() % hints.size()]
        var from_pos = move["from"]
        var to_pos = move["to"]
        # Get the tile node from your grid using the coordinates
        var tile = grid.main_array[from_pos.x][from_pos.y]
        if tile == null:
            tile = grid.main_array[to_pos.x][to_pos.y]
        if tile != null and tile.has_node("Sprite2D"):
            var hint_texture: Texture2D = tile.get_node("Sprite2D").texture
            hint = hint_effect.instantiate()
            if hint:
                grid.add_child(hint)
                hint.setup(hint_texture)
                hint.position = tile.position

func destroy_hint() -> void:
    if hint:
        hint.queue_free()
        hint = null

func switch_and_check(loc: Vector2, direction: Vector2, array: Array) -> bool:
    switch_pieces(loc, direction, array)
    if grid.find_matches(true, array):
        switch_pieces(loc, direction, array)
        return true
    switch_pieces(loc, direction, array)
    return false

func switch_pieces(loc: Vector2, direction: Vector2, array: Array) -> void:
    if GDM.grid.is_in_grid(loc) and !grid.obstacle_manager.restricted_fill(loc):
        if GDM.grid.is_in_grid(loc + direction) and !grid.obstacle_manager.restricted_fill(loc + direction):
            var holder = array[loc.x + direction.x][loc.y + direction.y]
            array[loc.x + direction.x][loc.y + direction.y] = array[loc.x][loc.y]
            array[loc.x][loc.y] = holder
