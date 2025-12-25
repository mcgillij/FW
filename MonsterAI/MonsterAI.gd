extends Object

class_name FW_MonsterAI

enum monster_ai { RANDOM, SENTIENT, BOMBER, SELF_AWARE }

static func affinity_to_colors(affinities: Array) -> Array:
    var colors := []
    for a in affinities:
        match a:
            FW_Ability.ABILITY_TYPES.Bark:
                colors.append("red")
            FW_Ability.ABILITY_TYPES.Reflex:
                colors.append("green")
            FW_Ability.ABILITY_TYPES.Alertness:
                colors.append("blue")
            FW_Ability.ABILITY_TYPES.Vigor:
                colors.append("orange")
            FW_Ability.ABILITY_TYPES.Enthusiasm:
                colors.append("pink")
    return colors

# Shared utility functions for all MonsterAI subclasses
static func is_in_grid(grid, x: int, y: int) -> bool:
    # Accepts either grid Node (with main_array) or Array
    if typeof(grid) == TYPE_OBJECT and grid.has("main_array"):
        var arr = grid.main_array
        return x >= 0 and x < arr.size() and y >= 0 and y < arr[0].size()
    else:
        return x >= 0 and x < grid.size() and y >= 0 and y < grid[0].size()

static func copy_array(array: Array) -> Array:
    var new_array = []
    for element in array:
        if element == null:
            new_array.append(null)
            continue

        var element_type = typeof(element)

        if element_type == TYPE_ARRAY:
            # This is a nested array, so we recurse.
            new_array.append(copy_array(element))
        elif element_type == TYPE_OBJECT:
            if element.has_method("duplicate"):
                new_array.append(element.duplicate())
            else:
                new_array.append(element) # Cannot duplicate, append as is.
        elif element_type == TYPE_DICTIONARY:
            new_array.append(element.duplicate(true)) # Deep copy for dictionary
        else:
            # This covers String, int, float, bool etc.
            # These are value types, so direct assignment is a copy.
            new_array.append(element)
    return new_array

## Helper to parse color and bomb type from board_state
static func get_color(tile):
    if tile == null:
        return null
    var t := typeof(tile)
    if t == TYPE_OBJECT:
        if "color" in tile:
            return tile.color
    elif t == TYPE_DICTIONARY:
        if tile.has("color"):
            return tile["color"]
    elif t == TYPE_STRING:
        return str(tile).split(":")[0]
    return null

static func get_bomb_type(tile):
    if tile == null:
        return ""
    var t := typeof(tile)
    if t == TYPE_OBJECT:
        if "bomb_type" in tile:
            return tile.bomb_type
    elif t == TYPE_DICTIONARY:
        if tile.has("bomb_type"):
            return tile["bomb_type"]
    elif t == TYPE_STRING:
        var parts = str(tile).split(":")
        if parts.size() > 1:
            return parts[1]
    return ""

# Find all contiguous matches of 3+ (returns Array of Vector2)
static func simulate_find_matches(array: Array) -> Array:
    var matches = []
    var w = array.size()
    if w == 0:
        return []
    var h = array[0].size()
    # Horizontal
    for y in range(h):
        var streak = 1
        for x in range(1, w):
            if array[x][y] != null and colors_match(array[x][y], array[x-1][y]):
                streak += 1
            else:
                if streak >= 3:
                    for k in range(x-streak, x):
                        matches.append(Vector2(k, y))
                streak = 1
            if array[x][y] == null:
                streak = 1
        # End of row
        if streak >= 3:
            for k in range(w-streak, w):
                matches.append(Vector2(k, y))
    # Vertical
    for x in range(w):
        var streak = 1
        for y in range(1, h):
            if array[x][y] != null and colors_match(array[x][y], array[x][y-1]):
                streak += 1
            else:
                if streak >= 3:
                    for k in range(y-streak, y):
                        matches.append(Vector2(x, k))
                streak = 1
            if array[x][y] == null:
                streak = 1
        # End of col
        if streak >= 3:
            for k in range(h-streak, h):
                matches.append(Vector2(x, k))
    return matches

static func colors_match(tile1, tile2) -> bool:
    if tile1 == null or tile2 == null:
        return false

    var color1 = get_color(tile1)
    var color2 = get_color(tile2)

    if color1 == null or color2 == null:
        return false

    var bomb1 = get_bomb_type(tile1)
    var bomb2 = get_bomb_type(tile2)

    if bomb1 == "color_bomb" or bomb2 == "color_bomb":
        return true

    return color1 == color2

# Group contiguous matches (returns Array of Arrays of Vector2)
static func group_contiguous_matches(matches: Array) -> Array:
    var groups = []
    var visited = {}
    for pos in matches:
        if visited.has(str(pos)):
            continue
        var group = [pos]
        visited[str(pos)] = true
        var queue = [pos]
        while queue.size() > 0:
            var current = queue.pop_front()
            for other in matches:
                if visited.has(str(other)):
                    continue
                if abs(current.x - other.x) + abs(current.y - other.y) == 1:
                    group.append(other)
                    queue.append(other)
                    visited[str(other)] = true
        groups.append(group)
    return groups

# Bomb trigger: 4+ in a row/col or T/L/+ shape
static func is_bomb_trigger_group(group: Array) -> bool:
    if group.size() < 3:
        return false
    var xs = []
    var ys = []
    for pos in group:
        xs.append(pos.x)
        ys.append(pos.y)
    var min_x = xs.min()
    var max_x = xs.max()
    var min_y = ys.min()
    var max_y = ys.max()
    if max_x - min_x + 1 >= 4 or max_y - min_y + 1 >= 4:
        return true
    # T/L/+ shape: at least 3 in one direction and at least 2 in the other
    if max_x - min_x + 1 >= 3 and max_y - min_y + 1 >= 2:
        return true
    if max_y - min_y + 1 >= 3 and max_x - min_x + 1 >= 2:
        return true
    return false

# Bomb create: 4/5 in a row/col or T/L/+ shape
static func is_bomb_create_group(group: Array) -> bool:
    if group.size() < 3:
        return false
    var xs = []
    var ys = []
    for pos in group:
        xs.append(pos.x)
        ys.append(pos.y)
    var min_x = xs.min()
    var max_x = xs.max()
    var min_y = ys.min()
    var max_y = ys.max()
    if max_x - min_x + 1 >= 5 or max_y - min_y + 1 >= 5:
        return true
    if max_x - min_x + 1 >= 4 or max_y - min_y + 1 >= 4:
        return true
    # T/L/+ shape: at least 3 in one direction and at least 2 in the other
    if max_x - min_x + 1 >= 3 and max_y - min_y + 1 >= 2:
        return true
    if max_y - min_y + 1 >= 3 and max_x - min_x + 1 >= 2:
        return true
    return false
