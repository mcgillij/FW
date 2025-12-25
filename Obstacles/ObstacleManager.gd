extends Node

var ice_spaces: PackedVector2Array = PackedVector2Array()
var locked_spaces: PackedVector2Array = PackedVector2Array()
var concrete_spaces: PackedVector2Array = PackedVector2Array()
var heavy_concrete_spaces: PackedVector2Array = PackedVector2Array()
var slime_spaces: Array = []
var pink_slime_spaces: Array = []

var damaged_slime: bool = false
var damaged_pink_slime: bool = false

var level_obstacle_data: Dictionary = {
	"concrete": [],
	"heavy_concrete": [],
	"ice": [],
	"locked": [],
	"slime": [],
	"pink_slime": []
}

var grid = null # We will pass the grid in

func set_grid(grid_ref) -> void:
	grid = grid_ref

func load_obstacle_data(level: int) -> void:
	level_obstacle_data = load_obstacle_data_from_file(level)
	concrete_spaces = PackedVector2Array(level_obstacle_data["concrete"])
	if level_obstacle_data.has("heavy_concrete"):
		heavy_concrete_spaces = PackedVector2Array(level_obstacle_data["heavy_concrete"])
	ice_spaces = PackedVector2Array(level_obstacle_data["ice"])
	locked_spaces = PackedVector2Array(level_obstacle_data["locked"])
	slime_spaces = level_obstacle_data["slime"].duplicate() # Use Array
	if level_obstacle_data.has("pink_slime"):
		pink_slime_spaces = level_obstacle_data["pink_slime"].duplicate() # Use Array

func load_obstacle_data_from_file(level: int) -> Dictionary:
	var path = "res://Levels/level" + str(level) + ".dat"
	var file = FileAccess.open(path, FileAccess.READ)
	if file != null:
		var data = file.get_var()
		if data:
			return data
		else:
			return level_obstacle_data
	else:
		return level_obstacle_data

func spawn_obstacles() -> void:
	spawn_ice()
	spawn_locks()
	spawn_concrete()
	spawn_slime()

func spawn_ice() -> void:
	for i in ice_spaces.size():
		grid.emit_signal("make_ice", ice_spaces[i])

func spawn_locks() -> void:
	for i in locked_spaces.size():
		grid.emit_signal("make_lock", locked_spaces[i])

func spawn_concrete() -> void:
	for i in concrete_spaces.size():
		grid.emit_signal("make_concrete", concrete_spaces[i])
	for j in heavy_concrete_spaces.size():
		grid.emit_signal("make_heavy_concrete", heavy_concrete_spaces[j])

func spawn_slime() -> void:
	for i in slime_spaces.size():
		grid.emit_signal("make_slime", slime_spaces[i])
	for j in pink_slime_spaces.size():
		grid.emit_signal("make_pink_slime", pink_slime_spaces[j])

func register_ice_tile(location: Vector2) -> void:
	if FW_GridUtils.is_in_array(ice_spaces, location):
		return
	ice_spaces.append(location)
	if level_obstacle_data.has("ice"):
		FW_GridUtils.add_to_array(location, level_obstacle_data["ice"])

func register_slime_tile(location: Vector2) -> void:
	if !FW_GridUtils.is_in_array(slime_spaces, location):
		slime_spaces.append(location)
		damaged_slime = false

func register_pink_slime_tile(location: Vector2) -> void:
	if !FW_GridUtils.is_in_array(pink_slime_spaces, location):
		pink_slime_spaces.append(location)
		damaged_pink_slime = false

func register_concrete_tile(location: Vector2) -> void:
	if FW_GridUtils.is_in_array(concrete_spaces, location):
		return
	concrete_spaces.append(location)
	if level_obstacle_data.has("concrete"):
		FW_GridUtils.add_to_array(location, level_obstacle_data["concrete"])

func register_heavy_concrete_tile(location: Vector2) -> void:
	if FW_GridUtils.is_in_array(heavy_concrete_spaces, location):
		return
	heavy_concrete_spaces.append(location)
	if level_obstacle_data.has("heavy_concrete"):
		FW_GridUtils.add_to_array(location, level_obstacle_data["heavy_concrete"])

func register_lock_tile(location: Vector2) -> void:
	if FW_GridUtils.is_in_array(locked_spaces, location):
		return
	locked_spaces.append(location)
	if level_obstacle_data.has("locked"):
		FW_GridUtils.add_to_array(location, level_obstacle_data["locked"])

func damage_obstacles_adjacent_to(pos: Vector2) -> void:
	damage_special(pos.x, pos.y)

func damage_special(col, row) -> void:
	grid.emit_signal("damage_ice", Vector2(col, row))
	grid.emit_signal("damage_lock", Vector2(col, row))
	check_concrete(col, row)
	check_heavy_concrete(col, row)
	check_slime(col, row)
	check_pink_slime(col, row)

func check_special_damage(col, row, signal_name: String) -> void:
	# check right
	if col < GDM.grid.width -1:
		grid.emit_signal(signal_name, Vector2(col+1, row))
	# check left
	if col > 0:
		grid.emit_signal(signal_name, Vector2(col-1, row))
	# check up
	if row < GDM.grid.height -1:
		grid.emit_signal(signal_name, Vector2(col, row + 1))
	# check down
	if row > 0:
		grid.emit_signal(signal_name, Vector2(col, row - 1))

func check_heavy_concrete(col, row) -> void:
	check_special_damage(col, row, "damage_heavy_concrete")

func check_concrete(col, row) -> void:
	check_special_damage(col, row, "damage_concrete")

func check_pink_slime(col, row) -> void:
	check_special_damage(col, row, "damage_pink_slime")

func check_slime(col, row) -> void:
	check_special_damage(col, row, "damage_slime")

func restricted_fill(place: Vector2) -> bool:
	if FW_GridUtils.is_in_array(grid.empty_spaces, place):
		return true
	if FW_GridUtils.is_in_array(concrete_spaces, place):
		return true
	if FW_GridUtils.is_in_array(heavy_concrete_spaces, place):
		return true
	if FW_GridUtils.is_in_array(slime_spaces, place):
		return true
	if FW_GridUtils.is_in_array(pink_slime_spaces, place):
		return true
	return false

func restricted_move(place: Vector2) -> bool:
	if FW_GridUtils.is_in_array(locked_spaces, place):
		return true
	if FW_GridUtils.is_in_array(grid.empty_spaces, place):
		return true
	return false

func generate_slime() -> void:
	generate_slime_generic(slime_spaces as Array, "make_slime")

func generate_pink_slime() -> void:
	generate_slime_generic(pink_slime_spaces as Array, "make_pink_slime")

func generate_slime_generic(spaces: Array, signal_name: String) -> void:
	const MAX_SLIME_ATTEMPTS := 100
	if spaces.size() > 0:
		var slime_made := false
		var tracker := 0
		while !slime_made and tracker < MAX_SLIME_ATTEMPTS:
			var random_number:int = floor(randf_range(0, spaces.size()))
			var curr_x:int = spaces[random_number].x
			var curr_y:int = spaces[random_number].y
			var neighbor := find_normal_neighbor(curr_x, curr_y, spaces)
			if neighbor != Vector2(-1, -1):
				grid.main_array[neighbor.x][neighbor.y].queue_free()
				grid.main_array[neighbor.x][neighbor.y] = null
				spaces.append(Vector2(neighbor.x, neighbor.y))
				slime_made = true
				grid.emit_signal(signal_name, Vector2(neighbor.x, neighbor.y))
				return
			tracker += 1

func find_normal_neighbor(col: int, row: int, slime_array: Array) -> Vector2:
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	for dir in directions:
		var new_pos = Vector2(col, row) + dir
		if (
			GDM.grid.is_in_grid(new_pos)
			and not grid.is_piece_null(new_pos.x, new_pos.y)
			and not grid.is_piece_sinker(new_pos.x, new_pos.y)
			and not (slime_array as Array).has(new_pos)
		):
			return new_pos
	return Vector2(-1, -1)  # Indicate no neighbor found

func remove_ice(location: Vector2):
	var index = ice_spaces.find(location)
	if index > -1:
		ice_spaces.remove_at(index)

func remove_lock(location: Vector2):
	var index = locked_spaces.find(location)
	if index > -1:
		locked_spaces.remove_at(index)

func remove_concrete(location: Vector2):
	var index = concrete_spaces.find(location)
	if index > -1:
		concrete_spaces.remove_at(index)

func remove_heavy_concrete(location: Vector2):
	var index = heavy_concrete_spaces.find(location)
	if index > -1:
		heavy_concrete_spaces.remove_at(index)

func remove_slime(location: Vector2):
	damaged_slime = true
	var index = slime_spaces.find(location)
	if index > -1:
		slime_spaces.remove_at(index)

func remove_pink_slime(location: Vector2):
	damaged_pink_slime = true
	var index = pink_slime_spaces.find(location)
	if index > -1:
		pink_slime_spaces.remove_at(index)

func _on_ice_holder_break_ice(_value: String, location: Vector2) -> void:
	FW_GridUtils.remove_from_array(ice_spaces, location)

func _on_lock_holder_remove_lock(_value: String, location: Vector2) -> void:
	FW_GridUtils.remove_from_array(locked_spaces, location)

func _on_concrete_holder_remove_concrete(_value: String, location: Vector2) -> void:
	FW_GridUtils.remove_from_array(concrete_spaces, location)

func _on_slime_holder_remove_slime(_value: String, location: Vector2) -> void:
	damaged_slime = true
	FW_GridUtils.remove_from_array(slime_spaces, location)

func _on_heavy_concrete_holder_remove_heavy_concrete(_value: String, location: Vector2) -> void:
	FW_GridUtils.remove_from_array(heavy_concrete_spaces, location)

func _on_pink_slime_holder_remove_pink_slime(_value: String, location: Vector2) -> void:
	damaged_pink_slime = true
	FW_GridUtils.remove_from_array(pink_slime_spaces, location)
