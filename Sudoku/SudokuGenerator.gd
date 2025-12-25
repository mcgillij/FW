# Title: Sudoku Generator
# Path: res://Sudoku/FW_SudokuGenerator.gd
# Description: Builds solved grids and carves puzzles with uniqueness per difficulty.
# Key functions: generate_puzzle, carve_clues, build_base_solution

class_name FW_SudokuGenerator
extends RefCounted

const GRID_SIZE := 9
const BOX_SIZE := 3
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const DIFFICULTY_CLUE_COUNTS := {
	"easy": 40,
	"medium": 34,
	"hard": 28,
	"expert": 24,
}

var _rng := RandomNumberGenerator.new()
var _solver := FW_SudokuSolver.new()

func generate_puzzle(difficulty: String = "easy") -> Dictionary:
	_rng.randomize()
	var solution := _build_solved_grid()
	var puzzle := solution.duplicate()
	var target_clues: int = int(DIFFICULTY_CLUE_COUNTS.get(difficulty, DIFFICULTY_CLUE_COUNTS["easy"]))
	_carve_clues(puzzle, target_clues)
	return {
		"puzzle": puzzle,
		"solution": solution,
		"difficulty": difficulty,
	}

func _build_solved_grid() -> PackedInt32Array:
	# Standard Latin square pattern (r * 3 + r / 3 + c) mod 9 + 1, then shuffled.
	var grid := PackedInt32Array()
	grid.resize(CELL_COUNT)
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var index := row * GRID_SIZE + col
			grid[index] = ((row * BOX_SIZE + int(row / float(BOX_SIZE)) + col) % GRID_SIZE) + 1
	_shuffle_symbols(grid)
	_shuffle_rows_and_cols(grid)
	return grid

func _shuffle_symbols(grid: PackedInt32Array) -> void:
	var symbols := []
	for i in range(1, GRID_SIZE + 1):
		symbols.append(i)
	symbols.shuffle()
	for i in range(CELL_COUNT):
		grid[i] = symbols[grid[i] - 1]

func _shuffle_rows_and_cols(grid: PackedInt32Array) -> void:
	_shuffle_row_bands(grid)
	_shuffle_col_stacks(grid)
	_shuffle_rows_in_bands(grid)
	_shuffle_cols_in_stacks(grid)

func _shuffle_row_bands(grid: PackedInt32Array) -> void:
	var bands: Array = [0, 1, 2]
	symbols_shuffle(bands)
	var copy := grid.duplicate()
	for band_index in range(bands.size()):
		var source_band: int = int(bands[band_index])
		for row_in_band in range(BOX_SIZE):
			var target_row := band_index * BOX_SIZE + row_in_band
			var source_row := source_band * BOX_SIZE + row_in_band
			for col in range(GRID_SIZE):
				grid[target_row * GRID_SIZE + col] = copy[source_row * GRID_SIZE + col]

func _shuffle_col_stacks(grid: PackedInt32Array) -> void:
	var stacks: Array = [0, 1, 2]
	symbols_shuffle(stacks)
	var copy := grid.duplicate()
	for stack_index in range(stacks.size()):
		var source_stack: int = int(stacks[stack_index])
		for col_in_stack in range(BOX_SIZE):
			var target_col := stack_index * BOX_SIZE + col_in_stack
			var source_col := source_stack * BOX_SIZE + col_in_stack
			for row in range(GRID_SIZE):
				grid[row * GRID_SIZE + target_col] = copy[row * GRID_SIZE + source_col]

func _shuffle_rows_in_bands(grid: PackedInt32Array) -> void:
	for band in range(BOX_SIZE):
		var rows: Array = [band * BOX_SIZE, band * BOX_SIZE + 1, band * BOX_SIZE + 2]
		symbols_shuffle(rows)
		var copy := grid.duplicate()
		for i in range(rows.size()):
			var source_row: int = int(rows[i])
			var target_row := band * BOX_SIZE + i
			for col in range(GRID_SIZE):
				grid[target_row * GRID_SIZE + col] = copy[source_row * GRID_SIZE + col]

func _shuffle_cols_in_stacks(grid: PackedInt32Array) -> void:
	for stack in range(BOX_SIZE):
		var cols: Array = [stack * BOX_SIZE, stack * BOX_SIZE + 1, stack * BOX_SIZE + 2]
		symbols_shuffle(cols)
		var copy := grid.duplicate()
		for i in range(cols.size()):
			var source_col: int = int(cols[i])
			var target_col := stack * BOX_SIZE + i
			for row in range(GRID_SIZE):
				grid[row * GRID_SIZE + target_col] = copy[row * GRID_SIZE + source_col]

func _carve_clues(puzzle: PackedInt32Array, target_clues: int) -> void:
	var clues := CELL_COUNT
	var attempt := 0
	var max_passes := 8
	while clues > target_clues and attempt < max_passes:
		var positions: Array = []
		for i in range(CELL_COUNT):
			if puzzle[i] != 0:
				positions.append(i)
		symbols_shuffle(positions)
		var removed_this_pass := 0
		for index in positions:
			if clues <= target_clues:
				break
			var backup := puzzle[index]
			puzzle[index] = 0
			var count := _solver.count_solutions(puzzle, 2)
			if count != 1:
				puzzle[index] = backup
			else:
				clues -= 1
				removed_this_pass += 1
		attempt += 1
		if removed_this_pass == 0:
			break

func symbols_shuffle(list: Array) -> void:
	var n := list.size()
	for i in range(n - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp: int = int(list[i])
		list[i] = list[j]
		list[j] = temp
