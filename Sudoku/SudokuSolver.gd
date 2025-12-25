# Title: Sudoku Solver
# Path: res://Sudoku/FW_SudokuSolver.gd
# Description: Backtracking solver with validity and uniqueness checks.
# Key functions: solve, count_solutions, is_valid

class_name FW_SudokuSolver
extends RefCounted

const GRID_SIZE := 9
const BOX_SIZE := 3
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const ALL_VALUES_MASK := 0b1_1111_1111 # bits 0-8 set

var _row_masks := PackedInt32Array()
var _col_masks := PackedInt32Array()
var _box_masks := PackedInt32Array()

func solve(grid: PackedInt32Array) -> PackedInt32Array:
	var working := grid.duplicate()
	_init_masks(working)
	if _solve_with_masks(working):
		return working
	return PackedInt32Array()

func count_solutions(grid: PackedInt32Array, limit: int = 2) -> int:
	var working := grid.duplicate()
	_init_masks(working)
	return _count_with_masks(working, limit, 0)

func is_valid(row: int, col: int, value: int, _grid: PackedInt32Array) -> bool:
	var bit := _bit_for(value)
	var box := _box_index(row, col)
	return (_row_masks[row] & bit) == 0 and (_col_masks[col] & bit) == 0 and (_box_masks[box] & bit) == 0

func _init_masks(grid: PackedInt32Array) -> void:
	_row_masks.resize(GRID_SIZE)
	_col_masks.resize(GRID_SIZE)
	_box_masks.resize(GRID_SIZE)
	for i in range(GRID_SIZE):
		_row_masks[i] = 0
		_col_masks[i] = 0
		_box_masks[i] = 0
	for index in range(CELL_COUNT):
		var value := grid[index]
		if value == 0:
			continue
		var row := int(index / float(GRID_SIZE))
		var col := index % GRID_SIZE
		var bit := _bit_for(value)
		var box := _box_index(row, col)
		_row_masks[row] |= bit
		_col_masks[col] |= bit
		_box_masks[box] |= bit

func _box_index(row: int, col: int) -> int:
	return int(row / float(BOX_SIZE)) * BOX_SIZE + int(col / float(BOX_SIZE))

func _bit_for(value: int) -> int:
	return 1 << (value - 1)

func _lowest_bit(mask: int) -> int:
	return mask & -mask

func _bit_to_value(bit: int) -> int:
	# bit is power of two with positions 0-8
	var value := 1
	var temp := bit
	while temp > 1:
		temp >>= 1
		value += 1
	return value

func _find_best_empty(grid: PackedInt32Array) -> int:
	var best_index := -1
	var best_options := 10
	for i in range(CELL_COUNT):
		if grid[i] != 0:
			continue
		var row := int(i / float(GRID_SIZE))
		var col := i % GRID_SIZE
		var box := _box_index(row, col)
		var used := _row_masks[row] | _col_masks[col] | _box_masks[box]
		var options := _popcount(ALL_VALUES_MASK & ~used)
		if options < best_options:
			best_options = options
			best_index = i
			if best_options <= 1:
				break
	return best_index

func _popcount(mask: int) -> int:
	var count := 0
	var m := mask
	while m != 0:
		m &= m - 1
		count += 1
	return count

func _solve_with_masks(grid: PackedInt32Array) -> bool:
	var index := _find_best_empty(grid)
	if index == -1:
		return true
	var row := int(index / float(GRID_SIZE))
	var col := index % GRID_SIZE
	var box := _box_index(row, col)
	var used := _row_masks[row] | _col_masks[col] | _box_masks[box]
	var candidates := ALL_VALUES_MASK & ~used
	while candidates != 0:
		var bit := _lowest_bit(candidates)
		candidates &= candidates - 1
		var value := _bit_to_value(bit)
		grid[index] = value
		_row_masks[row] |= bit
		_col_masks[col] |= bit
		_box_masks[box] |= bit
		if _solve_with_masks(grid):
			return true
		_row_masks[row] &= ~bit
		_col_masks[col] &= ~bit
		_box_masks[box] &= ~bit
		grid[index] = 0
	return false

func _count_with_masks(grid: PackedInt32Array, limit: int, count: int) -> int:
	if count >= limit:
		return count
	var index := _find_best_empty(grid)
	if index == -1:
		return count + 1
	var row := int(index / float(GRID_SIZE))
	var col := index % GRID_SIZE
	var box := _box_index(row, col)
	var used := _row_masks[row] | _col_masks[col] | _box_masks[box]
	var candidates := ALL_VALUES_MASK & ~used
	while candidates != 0 and count < limit:
		var bit := _lowest_bit(candidates)
		candidates &= candidates - 1
		var value := _bit_to_value(bit)
		grid[index] = value
		_row_masks[row] |= bit
		_col_masks[col] |= bit
		_box_masks[box] |= bit
		count = _count_with_masks(grid, limit, count)
		_row_masks[row] &= ~bit
		_col_masks[col] &= ~bit
		_box_masks[box] &= ~bit
		grid[index] = 0
	return count

func _solve_from(index: int, grid: PackedInt32Array) -> bool:
	if index >= CELL_COUNT:
		return true
	if grid[index] != 0:
		return _solve_from(index + 1, grid)
	var row := int(index / float(GRID_SIZE))
	var col := index % GRID_SIZE
	for value in range(1, GRID_SIZE + 1):
		if is_valid(row, col, value, grid):
			grid[index] = value
			if _solve_from(index + 1, grid):
				return true
			grid[index] = 0
	return false

func _count_from(index: int, grid: PackedInt32Array, limit: int, count: int) -> int:
	if count >= limit:
		return count
	if index >= CELL_COUNT:
		return count + 1
	if grid[index] != 0:
		return _count_from(index + 1, grid, limit, count)
	var row := int(index / float(GRID_SIZE))
	var col := index % GRID_SIZE
	for value in range(1, GRID_SIZE + 1):
		if is_valid(row, col, value, grid):
			grid[index] = value
			count = _count_from(index + 1, grid, limit, count)
			if count >= limit:
				break
	grid[index] = 0
	return count

func _row_ok(row: int, value: int, grid: PackedInt32Array) -> bool:
	var start := row * GRID_SIZE
	for i in range(start, start + GRID_SIZE):
		if grid[i] == value:
			return false
	return true

func _col_ok(col: int, value: int, grid: PackedInt32Array) -> bool:
	for row in range(GRID_SIZE):
		if grid[row * GRID_SIZE + col] == value:
			return false
	return true

func _box_ok(row: int, col: int, value: int, grid: PackedInt32Array) -> bool:
	var box_row := int(row / float(BOX_SIZE)) * BOX_SIZE
	var box_col := int(col / float(BOX_SIZE)) * BOX_SIZE
	for r in range(box_row, box_row + BOX_SIZE):
		for c in range(box_col, box_col + BOX_SIZE):
			if grid[r * GRID_SIZE + c] == value:
				return false
	return true
