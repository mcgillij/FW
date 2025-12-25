
class_name FW_GridUtils

# grid variables
class Grid:
	var width: int
	var height: int
	var x_start: int = 64
	var y_start: int = 800
	var offset: int = 64
	var y_offset: int = 2 # fall value

	func pixel_to_grid(x, y) -> Vector2:
		# Converts pixel coordinates to grid coordinates
		var new_x = round((x - x_start) / offset)
		var new_y = round((y - y_start) / -offset)
		return Vector2(new_x, new_y)

	func grid_to_pixel(col, row) -> Vector2:
		# Converts grid coordinates to pixel coordinates
		var new_x = x_start + offset * col
		var new_y = y_start + -offset * row
		return Vector2(new_x, new_y)

	func world_to_viewport_pixels(world_px: Vector2, viewport: Viewport) -> Vector2:
		# Project a world pixel position into viewport/screen pixel coords, using active Camera2D if available.
		if viewport == null:
			return world_px
		var viewport_size = viewport.get_visible_rect().size
		var viewport_center = viewport_size / 2.0

		var cam: Camera2D = viewport.get_camera_2d()
		if cam and is_instance_valid(cam):
			# Use Camera2D.offset when available -- PhaseWeb used offset and it matched visuals
			# Check property existence via get_property_list() to avoid runtime errors
			var props = cam.get_property_list()
			var has_offset = false
			for p in props:
				if typeof(p) == TYPE_DICTIONARY and p.has("name") and p["name"] == "offset":
					has_offset = true
					break
			if has_offset:
				var cam_offset = cam.offset
				return (world_px - cam_offset) * cam.zoom + viewport_center
			# Fallback: use global_position if offset not available
			var cam_pos = cam.global_position if cam.has_method("global_position") else cam.position
			return (world_px - cam_pos) * cam.zoom + viewport_center

	# End of camera handling

		# Fallback: assume camera is centered on grid middle cell
		@warning_ignore("integer_division")
		var camera_pixel_pos = grid_to_pixel(float(width/2-0.5), float(height/2-0.5))
		return world_px - camera_pixel_pos + viewport_center


	# Helper: convert a grid cell (col,row) to a normalized viewport position (0..1)
	# offset_mul allows small centering tweaks (default matches previous behavior)
	func grid_cell_to_normalized_target(col: int, row: float, viewport: Viewport, offset_mul: float = 0.0) -> Vector2:
		# grid_to_pixel already returns the center position for a cell in this project.
		# Do not add additional offsets by default; callers may pass offset_mul if needed.
		var world_px = grid_to_pixel(col, row)
		if offset_mul != 0.0:
			var grid_offset = offset * offset_mul
			world_px.x += grid_offset
			world_px.y += grid_offset

		var vp_size = Vector2(1, 1)
		if viewport:
			vp_size = viewport.get_visible_rect().size

		var screen_px = world_to_viewport_pixels(world_px, viewport)
		return Vector2(screen_px.x / max(vp_size.x, 1.0), screen_px.y / max(vp_size.y, 1.0))

	func is_in_grid(pos: Vector2) -> bool:
		# Checks if a position is within the grid bounds
		if pos.x >= 0 and pos.x < width:
			if pos.y >= 0 and pos.y < height:
				return true
		return false

class Moves:
	var selected_tiles: Array
	# swap back vars
	var previous_location: Vector2
	var previous_direction: Vector2

	func store_move_info(first_piece, second_piece, place: Vector2, direction: Vector2) -> void:
		selected_tiles = [first_piece, second_piece]
		previous_location = place
		previous_direction = direction

	func clear_move_info() -> void:
		selected_tiles.clear()
		previous_location = Vector2(-1, -1) # -1, -1 is a null value
		previous_direction = Vector2(-1, -1) # -1, -1 is a null value

	func valid() -> bool:
		# Checks if a move is valid (not null)
		if previous_direction == Vector2(-1, -1) or previous_location == Vector2(-1, -1):
			return false
		return true

# Check if placing a piece of given color at position (i,j) would create a match
# by looking at the 2 pieces to the left/right and up/down
static func match_at(array: Array, i: int, j: int, color: String, _width: int, _height: int) -> bool:
	if i > 1:
		if array[i-1][j] != null && array[i-2][j] != null:
			if array[i-1][j].color == color && array[i-2][j].color == color:
				return true
	if j > 1:
		if array[i][j-1] != null && array[i][j-2] != null:
			if array[i][j-1].color == color && array[i][j-2].color == color:
				return true
	return false

# Check if a piece at position (i,j) in the array is null
static func is_piece_null(array: Array, i: int, j: int) -> bool:
	if array[i][j] == null:
		return true
	return false

# Check if a piece at position (col,row) in the array is a sinker
static func is_piece_sinker(array: Array, col: int, row: int) -> bool:
	if col < 0 or col >= array.size() or row < 0 or row >= array[0].size():
		return false
	if array[col][row] != null:
		if array[col][row].color == "sinker":
			return true
	return false

# Color dictionary utility functions
static func zero_color_dict(colors_dict: Dictionary) -> void:
	for item in colors_dict.keys():
		colors_dict[item] = 0

static func tally_colors(colors_dict: Dictionary, color: String) -> void:
	if color in colors_dict.keys():
		colors_dict[color] += 1

# Calculate swap direction from two grid positions
static func calculate_touch_direction(grid_pos1: Vector2, grid_pos2: Vector2) -> Vector2:
	var difference = grid_pos2 - grid_pos1
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			return Vector2(1, 0)  # move to the right
		elif difference.x < 0:
			return Vector2(-1, 0)  # move to the left
	elif abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			return Vector2(0, 1)  # move up
		elif difference.y < 0:
			return Vector2(0, -1)  # move down
	return Vector2.ZERO  # no clear direction

# Get all clearable positions on the board (non-null, non-sinker pieces)
static func get_clearable_positions(array: Array, width: int, height: int) -> Array:
	var positions = []
	for i in width:
		for j in height:
			if not is_piece_null(array, i, j) and not is_piece_sinker(array, i, j):
				positions.append(Vector2(i, j))
	return positions

# Get all positions of pieces with a specific color (non-null pieces)
static func get_tiles_by_color(array: Array, width: int, height: int, color: String) -> Array:
	var positions = []
	for i in width:
		for j in height:
			if not is_piece_null(array, i, j):
				var piece = array[i][j]
				if piece.color == color:
					positions.append(Vector2(i, j))
	return positions

static func get_longest_sequence_length(matches: Array, dimension: String) -> int:
	if matches.size() == 0:
		return 0

	var groups = {}
	# For bomb creation, the dimension parameter is counter-intuitive.
	# "rows" is used to find the longest VERTICAL sequence (a column of pieces).
	# "cols" is used to find the longest HORIZONTAL sequence (a row of pieces).
	var sequence_dim = "y" if dimension == "rows" else "x"
	var group_dim = "x" if dimension == "rows" else "y"

	for match in matches:
		var group_key = match[group_dim]
		if not groups.has(group_key):
			groups[group_key] = []
		groups[group_key].append(match[sequence_dim])

	var max_len = 0
	for group_key in groups:
		var indices = groups[group_key]
		var current_sequence_len = get_sequence_length(indices)
		if current_sequence_len > max_len:
			max_len = current_sequence_len
	return max_len


static func is_valid_sequence(matches: Array, dimension: String) -> bool:
	if matches.size() == 0:
		return false

	var constant_value = -1  # To store the constant row or column value

	for match in matches:
		if dimension == "cols":
			if constant_value == -1:
				constant_value = match.y  # The constant row value for columns
			elif constant_value != match.y:
				return false  # Row values should be the same for a valid vertical line
		elif dimension == "rows":
			if constant_value == -1:
				constant_value = match.x  # The constant column value for rows
			elif constant_value != match.x:
				return false  # Column values should be the same for a valid horizontal line

	return true  # If all values are consistent, it's a valid sequence

static func get_sequence_length(array: Array) -> int:
	if array.size() == 0:
		return 0

	array = collapse_duplicates(array)  # Collapse duplicates
	array.sort()  # Sort the array

	var longest = 1
	var current_length = 1

	for i in range(1, array.size()):
		if array[i] == array[i - 1] + 1:
			current_length += 1
		else:
			if current_length > longest:
				longest = current_length
			current_length = 1

	# Final check for the last sequence
	if current_length > longest:
		longest = current_length

	return longest

static func collapse_duplicates(array: Array) -> Array:
	var result = []
	for value in array:
		if result.size() == 0 or result[result.size() - 1] != value:
			result.append(value)
	return result

static func has_intersection(matches: Array) -> bool:
	var row_map = {}
	var col_map = {}

	# Build maps to count how many times each row and column are used
	for match in matches:
		var col = match.x
		var row = match.y

		# Count occurrences in rows
		if not row_map.has(row):
			row_map[row] = []
		row_map[row].append(col)

		# Count occurrences in columns
		if not col_map.has(col):
			col_map[col] = []
		col_map[col].append(row)

	# Check for intersections by verifying if a coordinate is part of both sequences
	for match in matches:
		var col = match.x
		var row = match.y

		# Check if current position is part of both a horizontal and vertical sequence
		if row_map[row].size() >= 3 and col_map[col].size() >= 3:
			return true  # Intersection found
	return false  # No intersection found


static func add_to_array(value: Vector2, array: Array) -> void:
	if !array.has(value):
		array.append(value)

static func is_in_array(array: Array, item: Vector2) -> bool:
	for i in array.size():
		if array[i] == item:
			return true
	return false

static func remove_from_array(array: Array, item: Vector2) -> void:
	for i in range(array.size() - 1, -1, -1): #loop backwards to not run into nulls
		if array[i] == item:
			array.remove_at(i)


# Finds the point in a match group that has both horizontal and vertical neighbors
# within the same group. This is the intersection of an L or T shape.
static func get_intersection_point(match_group: Array) -> Vector2:
	if match_group.size() < 3:
		return Vector2(-1, -1)

	# For faster lookups, convert the array to a dictionary/hash set
	var match_set = {}
	for pos in match_group:
		match_set[pos] = true

	for pos in match_group:
		var has_horizontal_neighbor = match_set.has(pos + Vector2.RIGHT) or match_set.has(pos + Vector2.LEFT)
		var has_vertical_neighbor = match_set.has(pos + Vector2.UP) or match_set.has(pos + Vector2.DOWN)

		if has_horizontal_neighbor and has_vertical_neighbor:
			return pos # This is the intersection point

	return Vector2(-1, -1) # No intersection found

static func simulate_find_matches(array: Array, min_match: int = 3) -> Array:
	var matches = []

	# Horizontal matches
	for j in range(array[0].size()):
		var i = 0
		while i < array.size() - (min_match - 1):
			var p1 = array[i][j]
			if p1 == null:
				i += 1
				continue

			var match_coords = [Vector2(i, j)]
			for k in range(i + 1, array.size()):
				var p_next = array[k][j]
				if p_next != null and p_next.color == p1.color:
					match_coords.append(Vector2(k, j))
				else:
					break

			if match_coords.size() >= min_match:
				for coord in match_coords:
					matches.append(coord)
				i += match_coords.size()
			else:
				i += 1

	# Vertical matches
	for i in range(array.size()):
		var j = 0
		while j < array[0].size() - (min_match - 1):
			var p1 = array[i][j]
			if p1 == null:
				j += 1
				continue

			var match_coords = [Vector2(i, j)]
			for k in range(j + 1, array[0].size()):
				var p_next = array[i][k]
				if p_next != null and p_next.color == p1.color:
					match_coords.append(Vector2(i, k))
				else:
					break

			if match_coords.size() >= min_match:
				for coord in match_coords:
					matches.append(coord)
				j += match_coords.size()
			else:
				j += 1

	return matches

# Takes a flat array of matched coordinates and groups them into contiguous blocks.
# Example In: [(0,0), (1,0), (3,3), (4,3)]
# Example Out: [ [(0,0), (1,0)], [(3,3), (4,3)] ]
static func group_contiguous_matches(flat_matches: Array) -> Array:
	var groups = []
	var visited = {} # Use a dictionary as a hash set for fast lookups

	for pos in flat_matches:
		if not visited.has(pos):
			# This position hasn't been assigned to a group yet. Start a new one.
			var new_group = []
			var queue = [pos]
			visited[pos] = true

			while not queue.is_empty():
				var current_pos = queue.pop_front()
				new_group.append(current_pos)

				var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
				for dir in directions:
					var neighbor_pos = current_pos + dir
					# Check if the neighbor is in our original match list and we haven't visited it yet.
					if flat_matches.has(neighbor_pos) and not visited.has(neighbor_pos):
						visited[neighbor_pos] = true
						queue.append(neighbor_pos)

			groups.append(new_group)
	return groups

static func simulate_bomb_creation(array: Array, match_group: Array, swap_from: Vector2, swap_to: Vector2) -> bool:
	if match_group.is_empty():
		return false

	var color = array[match_group[0].x][match_group[0].y].color
	if color == "sinker":
		return false

	var longest_col = FW_GridUtils.get_longest_sequence_length(match_group, "rows")
	var longest_row = FW_GridUtils.get_longest_sequence_length(match_group, "cols")

	var bomb_type = null
	if longest_col >= 5 or longest_row >= 5:
		bomb_type = "color"
	elif FW_GridUtils.has_intersection(match_group):
		bomb_type = "adjacent"
	elif longest_col >= 4:
		bomb_type = "column"
	elif longest_row >= 4:
		bomb_type = "row"

	if bomb_type == null:
		return false

	# Determine bomb position (intersection, swap_to, swap_from, middle)
	var bomb_pos = Vector2(-1, -1)
	if bomb_type == "adjacent":
		bomb_pos = FW_GridUtils.get_intersection_point(match_group)
	if bomb_pos == Vector2(-1, -1) and match_group.has(swap_to):
		bomb_pos = swap_to
	elif bomb_pos == Vector2(-1, -1) and match_group.has(swap_from):
		bomb_pos = swap_from
	elif bomb_pos == Vector2(-1, -1):
		var sorted = match_group.duplicate()
		sorted.sort_custom(func(a, b): return a.x < b.x or a.y < b.y)
		@warning_ignore("integer_division")
		bomb_pos = sorted[floor(sorted.size() / 2)]

	# Set bomb flag on simulated array
	if bomb_pos != Vector2(-1, -1):
		var piece = array[bomb_pos.x][bomb_pos.y]
		if piece != null:
			match bomb_type:
				"adjacent": piece.is_adjacent_bomb = true
				"column": piece.is_col_bomb = true
				"row": piece.is_row_bomb = true
				"color": piece.is_color_bomb = true
			return true
	return false

# Get random non-null, non-sinker positions from the grid array
static func get_random_positions(array: Array, width: int, height: int, count: int, exclude: Vector2 = Vector2(-1, -1)) -> Array:
	if array.is_empty() or array[0].is_empty():
		return []
	var available = []
	for x in range(min(width, array.size())):
		for y in range(min(height, array[x].size())):
			var pos = Vector2(x, y)
			if pos != exclude and not is_piece_null(array, x, y) and not is_piece_sinker(array, x, y):
				available.append(pos)
	var selected = []
	for i in range(min(count, available.size())):
		if available.size() > 0:
			var rand_pos = available.pick_random()
			selected.append(rand_pos)
			available.erase(rand_pos)
	return selected
