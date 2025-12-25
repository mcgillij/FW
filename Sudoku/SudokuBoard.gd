# Title: Sudoku Board
# Path: res://Sudoku/FW_SudokuBoard.gd
# Description: Manages Sudoku grid state, selection, input, hints, and completion checks.
# Key functions: setup_puzzle, handle_number_input, reveal_hint, undo_last_move

class_name FW_SudokuBoard
extends Control

signal puzzle_completed
signal mistake_made
signal selection_changed(index)
signal value_committed(index, value)

const GRID_SIZE := 9
const BOX_SIZE := 3
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const DIGIT_FONT_SCALE := 0.6
const NOTE_FONT_SCALE := 0.26
const OUTLINE_DIVISOR := 18.0

@export var max_grid_side: float = 700.0
@export var min_cell_side: int = 40

@export var cell_scene: PackedScene

@onready var grid: GridContainer = %Grid

var puzzle := PackedInt32Array()
var solution := PackedInt32Array()
var _locked := PackedByteArray()
var _cells: Array[FW_SudokuCell] = []
var _selected_index: int = -1
var _note_mode: bool = false
var _history: Array[Dictionary] = []

func _ready() -> void:
	_configure_grid_layout()

func setup_puzzle(puzzle_data: PackedInt32Array, solution_data: PackedInt32Array) -> void:
	puzzle = puzzle_data.duplicate()
	solution = solution_data.duplicate()
	_locked = PackedByteArray()
	_locked.resize(CELL_COUNT)
	for i in range(CELL_COUNT):
		_locked[i] = 1 if puzzle[i] != 0 else 0
	_build_cells()
	_selected_index = -1
	_history.clear()
	_update_highlights()

func set_note_mode(enabled: bool) -> void:
	_note_mode = enabled

func handle_number_input(number: int) -> void:
	if _selected_index < 0:
		return
	if number < 1 or number > 9:
		return
	var cell := _cells[_selected_index]
	if cell.is_locked:
		return
	if _note_mode:
		cell.toggle_note(number)
		return
	var expected := solution[_selected_index]
	if expected != number:
		cell.set_conflict(true)
		_emit_mistake_feedback(cell)
		emit_signal("mistake_made")
		return
	if puzzle[_selected_index] == number:
		return
	_push_history(_selected_index, puzzle[_selected_index])
	puzzle[_selected_index] = number
	cell.set_conflict(false)
	cell.set_value(number)
	_clear_notes(_selected_index)
	_update_cell_sizes()
	_update_highlights()
	emit_signal("value_committed", _selected_index, number)
	if _is_complete():
		emit_signal("puzzle_completed")

func clear_selected() -> bool:
	if _selected_index < 0:
		return false
	if _locked[_selected_index] == 1:
		return false
	var cell := _cells[_selected_index]
	var had_value := puzzle[_selected_index] != 0
	if had_value:
		_push_history(_selected_index, puzzle[_selected_index])
		puzzle[_selected_index] = 0
		cell.clear_value()
	cell.clear_notes()
	_update_cell_sizes()
	_update_highlights()
	return true

func reveal_hint() -> bool:
	for i in range(CELL_COUNT):
		if puzzle[i] == 0:
			_selected_index = i
			_apply_hint_at(i)
			_update_cell_sizes()
			_update_highlights()
			if _is_complete():
				emit_signal("puzzle_completed")
			return true
	return false

func undo_last_move() -> bool:
	if _history.is_empty():
		return false
	var entry: Dictionary = _history.pop_back()
	var index: int = entry.get("index", -1)
	var previous_value: int = entry.get("previous_value", 0)
	if index < 0:
		return false
	puzzle[index] = previous_value
	if previous_value == 0:
		_cells[index].clear_value()
	else:
		_cells[index].set_value(previous_value)
	_update_cell_sizes()
	_update_highlights()
	return true

func can_undo() -> bool:
	return not _history.is_empty()

func select_cell(index: int) -> void:
	if index < 0 or index >= CELL_COUNT:
		return
	_selected_index = index
	_update_highlights()
	emit_signal("selection_changed", index)

func set_pencil_mode(enabled: bool) -> void:
	set_note_mode(enabled)

func has_selection() -> bool:
	return _selected_index >= 0

func _build_cells() -> void:
	grid.columns = GRID_SIZE
	for child in grid.get_children():
		child.queue_free()
	grid.queue_sort()
	await get_tree().process_frame
	_cells.clear()
	for i in range(CELL_COUNT):
		var cell := _create_cell()
		var value := puzzle[i]
		var is_locked := _locked[i] == 1
		cell.configure(i, value, is_locked)
		# compute row/col and set border separators
		var row := int(i / float(GRID_SIZE))
		var col := i % GRID_SIZE
		if cell.has_method("set_grid_position"):
			cell.set_grid_position(row, col)
		cell.pressed.connect(_on_cell_pressed.bind(i))
		grid.add_child(cell)
		_cells.append(cell)

	# After building cells, size them to fit our area
	_update_cell_sizes()

func _configure_grid_layout() -> void:
	if grid == null:
		return
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.anchor_left = 0
	grid.anchor_top = 0
	grid.anchor_right = 0
	grid.anchor_bottom = 0
	grid.grow_horizontal = Control.GROW_DIRECTION_BOTH
	grid.grow_vertical = Control.GROW_DIRECTION_BOTH

func _create_cell() -> FW_SudokuCell:
	if cell_scene != null:
		var instanced := cell_scene.instantiate()
		if instanced is FW_SudokuCell:
			return instanced
		instanced.queue_free()
	var cell := FW_SudokuCell.new()
	cell.focus_mode = Control.FOCUS_NONE
	return cell

func _on_cell_pressed(index: int) -> void:
	select_cell(index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_cell_sizes()

func _update_cell_sizes() -> void:
	if _cells.is_empty():
		return
	var area: Vector2 = size
	if area.x <= 0 or area.y <= 0:
		return
	var h_sep: int = grid.get_theme_constant("h_separation", "GridContainer") if grid.has_theme_constant("h_separation", "GridContainer") else 2
	var v_sep: int = grid.get_theme_constant("v_separation", "GridContainer") if grid.has_theme_constant("v_separation", "GridContainer") else 2
	var total_h_spacing: int = (GRID_SIZE - 1) * h_sep
	var total_v_spacing: int = (GRID_SIZE - 1) * v_sep
	var target_side: float = min(area.x, area.y, max_grid_side)
	if target_side <= 0.0:
		return
	var available: float = target_side - max(total_h_spacing, total_v_spacing)
	var cell_size: int = int(floor(available / float(GRID_SIZE)))
	cell_size = clamp(cell_size, min_cell_side, int(max_grid_side))
	if cell_size <= 0:
		return
	for c in _cells:
		_apply_cell_metrics(c, cell_size)
	grid.queue_sort()
	var grid_side := GRID_SIZE * cell_size + total_h_spacing
	var target_size := Vector2(grid_side, grid_side)
	grid.custom_minimum_size = target_size

func _apply_cell_metrics(cell: FW_SudokuCell, cell_size: int) -> void:
	cell.custom_minimum_size = Vector2(cell_size, cell_size)
	var digit_font := int(cell_size * DIGIT_FONT_SCALE)
	var note_font := int(cell_size * NOTE_FONT_SCALE)
	cell.add_theme_font_size_override("font_size", digit_font if cell.value > 0 else note_font)
	cell.add_theme_constant_override("outline_size", max(1, int(cell_size / OUTLINE_DIVISOR)))

func _update_highlights() -> void:
	var conflicts := _find_conflicts()
	for i in range(_cells.size()):
		var cell := _cells[i]
		cell.set_selected(i == _selected_index)
		cell.set_related(_selected_index >= 0 and _is_related(_selected_index, i))
		cell.set_conflict(conflicts.has(i))

func _is_related(a: int, b: int) -> bool:
	if a == b:
		return true
	if a < 0 or b < 0:
		return false
	var row_a := int(a / float(GRID_SIZE))
	var col_a := a % GRID_SIZE
	var row_b := int(b / float(GRID_SIZE))
	var col_b := b % GRID_SIZE
	if row_a == row_b or col_a == col_b:
		return true
	return int(row_a / float(BOX_SIZE)) == int(row_b / float(BOX_SIZE)) and int(col_a / float(BOX_SIZE)) == int(col_b / float(BOX_SIZE))

func _find_conflicts() -> Array:
	var conflicts: Array = []
	# Track duplicates per row/col/box.
	for row in range(GRID_SIZE):
		var seen := {}
		for col in range(GRID_SIZE):
			var idx := row * GRID_SIZE + col
			var value := puzzle[idx]
			if value == 0:
				continue
			if value in seen:
				conflicts.append(idx)
				conflicts.append(seen[value])
			else:
				seen[value] = idx
	for col in range(GRID_SIZE):
		var seen_col := {}
		for row in range(GRID_SIZE):
			var idx := row * GRID_SIZE + col
			var value := puzzle[idx]
			if value == 0:
				continue
			if value in seen_col:
				conflicts.append(idx)
				conflicts.append(seen_col[value])
			else:
				seen_col[value] = idx
	for box_row in range(BOX_SIZE):
		for box_col in range(BOX_SIZE):
			var seen_box := {}
			for r in range(BOX_SIZE):
				for c in range(BOX_SIZE):
					var row := box_row * BOX_SIZE + r
					var col := box_col * BOX_SIZE + c
					var idx := row * GRID_SIZE + col
					var value := puzzle[idx]
					if value == 0:
						continue
					if value in seen_box:
						conflicts.append(idx)
						conflicts.append(seen_box[value])
					else:
						seen_box[value] = idx
	return conflicts

func _is_complete() -> bool:
	for value in puzzle:
		if value == 0:
			return false
	return puzzle == solution

func _clear_notes(index: int) -> void:
	if index < 0 or index >= _cells.size():
		return
	_cells[index].clear_notes()

func _apply_hint_at(index: int) -> void:
	if index < 0 or index >= CELL_COUNT:
		return
	if _locked[index] == 1:
		return
	_push_history(index, puzzle[index])
	var correct := solution[index]
	puzzle[index] = correct
	_cells[index].set_value(correct)

func _push_history(index: int, previous_value: int) -> void:
	_history.append({
		"index": index,
		"previous_value": previous_value,
	})

func _emit_mistake_feedback(cell: FW_SudokuCell) -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(cell, "self_modulate", Color(1, 0.7, 0.7), 0.12)
	tween.tween_property(cell, "self_modulate", Color.WHITE, 0.18)
