# Title: Sudoku Cell
# Path: res://Sudoku/FW_SudokuCell.gd
# Description: Single Sudoku cell handling value display, notes, and highlight states.
# Key functions: configure, set_value, toggle_note, set_selected

class_name FW_SudokuCell
extends Button

@export var selected_color := Color(0.7, 0.8, 0.9)
@export var related_color := Color(0.6, 0.72, 0.86)
@export var conflict_color := Color(1.0, 0.76, 0.76)
@export var locked_color := Color(0.9, 0.9, 0.9)
@export var editable_color := Color(0.96, 0.96, 0.96)

var index: int = -1
var is_locked: bool = false
var value: int = 0
var _selected: bool = false
var _related: bool = false
var _conflict: bool = false
var _notes := PackedByteArray()
var _normal_stylebox: StyleBoxFlat
var _selected_stylebox: StyleBoxFlat
var _related_stylebox: StyleBoxFlat
var _conflict_stylebox: StyleBoxFlat
var _locked_stylebox: StyleBoxFlat
var _applied_stylebox: StyleBoxFlat

func _ready() -> void:
	toggle_mode = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notes.resize(9)
	_create_styleboxes()
	_refresh_display()

func configure(cell_index: int, initial_value: int, locked: bool) -> void:
	index = cell_index
	is_locked = locked
	disabled = locked
	# Ensure styleboxes exist before refreshing display (instantiation may call configure before _ready)
	if _normal_stylebox == null:
		_create_styleboxes()
	set_value(initial_value, locked)

func set_value(new_value: int, locked: bool = false) -> void:
	value = new_value
	if locked:
		is_locked = true
		disabled = true
	_clear_notes()
	_refresh_display()

func clear_value() -> void:
	if is_locked:
		return
	value = 0
	_refresh_display()

func toggle_note(number: int) -> void:
	if number < 1 or number > 9:
		return
	if _notes.is_empty():
		_notes.resize(9)
	_notes[number - 1] = 1 if _notes[number - 1] == 0 else 0
	_refresh_display()

func clear_notes() -> void:
	_clear_notes()
	_refresh_display()

func set_selected(enabled: bool) -> void:
	_selected = enabled
	_refresh_display()

func set_related(enabled: bool) -> void:
	_related = enabled
	_refresh_display()

func set_conflict(enabled: bool) -> void:
	_conflict = enabled
	_refresh_display()

func set_locked_state(locked: bool) -> void:
	is_locked = locked
	disabled = locked
	_refresh_display()

func _clear_notes() -> void:
	if _notes.is_empty():
		_notes.resize(9)
	for i in range(9):
		_notes[i] = 0

func _create_styleboxes() -> void:
	# Normal (white) with thin black border
	_normal_stylebox = StyleBoxFlat.new()
	_normal_stylebox.bg_color = Color(1, 1, 1, 1)
	_normal_stylebox.border_width_top = 1
	_normal_stylebox.border_width_left = 1
	_normal_stylebox.border_width_right = 1
	_normal_stylebox.border_width_bottom = 1
	_normal_stylebox.border_color = Color(0, 0, 0)

	# Selected (subtle blue)
	_selected_stylebox = StyleBoxFlat.new()
	_selected_stylebox.bg_color = Color(0.88, 0.95, 1, 1)
	_selected_stylebox.border_width_top = 2
	_selected_stylebox.border_width_left = 2
	_selected_stylebox.border_width_right = 2
	_selected_stylebox.border_width_bottom = 2
	_selected_stylebox.border_color = Color(0.12, 0.45, 0.8)

	# Related (very light blue)
	_related_stylebox = StyleBoxFlat.new()
	_related_stylebox.bg_color = Color(0.96, 0.98, 1, 1)
	_related_stylebox.border_width_top = 1
	_related_stylebox.border_color = Color(0.8, 0.9, 1)

	# Conflict (light red)
	_conflict_stylebox = StyleBoxFlat.new()
	_conflict_stylebox.bg_color = Color(1, 0.94, 0.94, 1)
	_conflict_stylebox.border_width_top = 2
	_conflict_stylebox.border_width_left = 2
	_conflict_stylebox.border_width_right = 2
	_conflict_stylebox.border_width_bottom = 2
	_conflict_stylebox.border_color = Color(0.8, 0.18, 0.18)

	# Locked (slightly gray)
	_locked_stylebox = StyleBoxFlat.new()
	_locked_stylebox.bg_color = Color(0.94, 0.94, 0.94, 1)
	_locked_stylebox.border_width_top = 1
	_locked_stylebox.border_color = Color(0.78, 0.78, 0.78)

func _make_stylebox_copy(src: StyleBoxFlat) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = src.bg_color
	s.border_color = src.border_color
	s.border_width_top = src.border_width_top
	s.border_width_left = src.border_width_left
	s.border_width_right = src.border_width_right
	s.border_width_bottom = src.border_width_bottom
	return s

func set_grid_position(row: int, col: int) -> void:
	# copy base styleboxes and set border widths for outer grid and 3x3 separators
	var base := _normal_stylebox
	if _conflict:
		base = _conflict_stylebox
	elif _selected:
		base = _selected_stylebox
	elif _related:
		base = _related_stylebox
	elif is_locked:
		base = _locked_stylebox
	var style := _make_stylebox_copy(base)

	# base widths
	var outer_thick := 3
	var band_thick := 2
	var thin := 1

	# left border
	if col == 0:
		style.border_width_left = outer_thick
	elif col % 3 == 0:
		style.border_width_left = band_thick
	else:
		style.border_width_left = thin
	# right border
	if col == 8:
		style.border_width_right = outer_thick
	elif col % 3 == 2:
		style.border_width_right = band_thick
	else:
		style.border_width_right = thin
	# top/bottom
	if row == 0:
		style.border_width_top = outer_thick
	elif row % 3 == 0:
		style.border_width_top = band_thick
	else:
		style.border_width_top = thin
	if row == 8:
		style.border_width_bottom = outer_thick
	elif row % 3 == 2:
		style.border_width_bottom = band_thick
	else:
		style.border_width_bottom = thin

	# Store applied style for later refreshes; refresh_display will use it
	_applied_stylebox = style
	_apply_stylebox_to_states(style)

func _apply_stylebox_to_states(style: StyleBoxFlat) -> void:
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	add_theme_stylebox_override("disabled", style)

func _update_text_style() -> void:
	# make sure locked cells look slightly subdued
	if is_locked:
		add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	else:
		add_theme_color_override("font_color", Color(0, 0, 0))

func _get_contrast_text_color(bg: Color) -> Color:
	var lum := 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
	return Color(1, 1, 1) if lum < 0.5 else Color(0, 0, 0)

func _refresh_display() -> void:
	if value > 0:
		text = str(value)
	else:
		text = _note_string()
	# Font sizing is controlled by the board to keep consistent scaling

	# Apply stylebox based on flags and pick a font color with good contrast
	var used_stylebox: StyleBoxFlat = _normal_stylebox
	if _conflict:
		used_stylebox = _conflict_stylebox
	elif _selected:
		used_stylebox = _selected_stylebox
	elif _related:
		used_stylebox = _related_stylebox
	elif is_locked:
		used_stylebox = _locked_stylebox
	# Prefer _applied_stylebox when set (to preserve per-cell border widths), otherwise fallback.
	var applied := _applied_stylebox
	if applied == null:
		applied = _make_stylebox_copy(used_stylebox)
	else:
		# copy current color/border color from used_stylebox
		applied.bg_color = used_stylebox.bg_color
		applied.border_color = used_stylebox.border_color
	_apply_stylebox_to_states(applied)

	var bg := used_stylebox.bg_color
	var chosen_text := _get_contrast_text_color(bg)
	if is_locked:
		chosen_text = Color(0.08, 0.08, 0.08)
	# Apply font color for all button states so selection/hover don't make text disappear
	add_theme_color_override("font_color", chosen_text)
	add_theme_color_override("font_color_hover", chosen_text)
	add_theme_color_override("font_color_pressed", chosen_text)
	add_theme_color_override("font_color_focus", chosen_text)
	add_theme_color_override("font_color_disabled", chosen_text)
	# Also ensure hover/pressed/focus disabled font colors are consistent
	add_theme_color_override("font_color_hover", chosen_text)
	add_theme_color_override("font_color_pressed", chosen_text)
	add_theme_color_override("font_color_focus", chosen_text)
	add_theme_color_override("font_color_disabled", chosen_text)
	# Small outline when needed for extra contrast on very light/dark backgrounds
	var outline := Color(1,1,1) if chosen_text == Color(0,0,0) else Color(0,0,0)
	add_theme_color_override("font_outline_color", outline)
	# Outline size already set by font size branch; fallback to 2 if none
	if value == 0:
		add_theme_constant_override("outline_size", 2)

func _note_string() -> String:
	var parts: Array[String] = []
	for i in range(9):
		if _notes.size() > i and _notes[i] != 0:
			parts.append(str(i + 1))
	return " ".join(parts)

func _additional_color_overrides() -> void:
	# no tinting/modulation; styleboxes handle background states.
	# Keep locked text subdued if needed.
	if is_locked:
		add_theme_color_override("font_color", Color(0.06, 0.06, 0.06))
