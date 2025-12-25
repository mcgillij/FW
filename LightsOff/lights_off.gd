extends CanvasLayer

const RESULT_TYPE_EQUIPMENT := "equipment"
const RESULT_TYPE_CONSUMABLE := "consumable"
const RESULT_TYPE_GOLD := "gold"
const RESULT_TYPE_DEBUFF := "debuff"
const DEFAULT_GOLD_ICON: Texture2D = preload("res://Item/Junk/Images/gold_coins.png")

class LightsOffCell:
	extends Button

	signal cell_activated(cell_index: int)

	var cell_index := -1
	var is_on := false
	var on_color := Color(1.0, 0.92, 0.35, 1.0)
	var off_color := Color(0.1, 0.1, 0.15, 1.0)
	var solved_color := Color(0.45, 1.0, 0.65, 1.0)
	var hover_scale := 1.03
	var _style_normal := StyleBoxFlat.new()
	var _style_hover := StyleBoxFlat.new()
	var _style_pressed := StyleBoxFlat.new()
	var _style_disabled := StyleBoxFlat.new()

	func _init() -> void:
		flat = false
		toggle_mode = false
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		clip_text = true
		text = ""
		custom_minimum_size = Vector2.ONE * 96
		_setup_styles()
		_update_visual(false)
		pressed.connect(_on_pressed)
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

	func configure(index: int, button_size: Vector2, on_col: Color, off_col: Color, solved_col: Color) -> void:
		cell_index = index
		on_color = on_col
		off_color = off_col
		solved_color = solved_col
		custom_minimum_size = button_size
		pivot_offset = button_size * 0.5
		_update_corner_radius(button_size)
		_update_visual(false)

	func set_state(active: bool, solved: bool) -> void:
		is_on = active
		_update_visual(solved)

	func _on_pressed() -> void:
		cell_activated.emit(cell_index)
		# Toggle SFX
		if SoundManager:
			SoundManager._play_random_sound()

	func _on_mouse_entered() -> void:
		scale = Vector2.ONE * hover_scale

	func _on_mouse_exited() -> void:
		scale = Vector2.ONE

	func _update_visual(solved: bool) -> void:
		var color := solved_color if solved else (on_color if is_on else off_color)
		_style_normal.bg_color = color
		_style_hover.bg_color = color.lightened(0.08)
		_style_pressed.bg_color = color.darkened(0.1)
		_style_disabled.bg_color = color.darkened(0.2)
		_style_normal.shadow_color = Color(color.r, color.g, color.b, 0.35)
		_style_hover.shadow_color = Color(color.r, color.g, color.b, 0.4)
		_style_pressed.shadow_color = Color(color.r, color.g, color.b, 0.45)
		_style_disabled.shadow_color = Color(0, 0, 0, 0.2)

	func _setup_styles() -> void:
		var style_list := [_style_normal, _style_hover, _style_pressed, _style_disabled]
		for style in style_list:
			style.corner_radius_top_left = 12
			style.corner_radius_top_right = 12
			style.corner_radius_bottom_left = 12
			style.corner_radius_bottom_right = 12
			style.shadow_size = 4
			style.shadow_offset = Vector2(0, 2)
		add_theme_stylebox_override("normal", _style_normal)
		add_theme_stylebox_override("hover", _style_hover)
		add_theme_stylebox_override("pressed", _style_pressed)
		add_theme_stylebox_override("disabled", _style_disabled)
		add_theme_stylebox_override("focus", _style_normal)

	func _update_corner_radius(button_size: Vector2) -> void:
		var radius := int(minf(button_size.x, button_size.y) * 0.15)
		_style_normal.corner_radius_top_left = radius
		_style_normal.corner_radius_top_right = radius
		_style_normal.corner_radius_bottom_left = radius
		_style_normal.corner_radius_bottom_right = radius
		_style_hover.corner_radius_top_left = radius
		_style_hover.corner_radius_top_right = radius
		_style_hover.corner_radius_bottom_left = radius
		_style_hover.corner_radius_bottom_right = radius
		_style_pressed.corner_radius_top_left = radius
		_style_pressed.corner_radius_top_right = radius
		_style_pressed.corner_radius_bottom_left = radius
		_style_pressed.corner_radius_bottom_right = radius
		_style_disabled.corner_radius_top_left = radius
		_style_disabled.corner_radius_top_right = radius
		_style_disabled.corner_radius_bottom_left = radius
		_style_disabled.corner_radius_bottom_right = radius

@export_range(2, 8, 1) var min_rows := 4
@export_range(2, 8, 1) var max_rows := 5
@export_range(2, 8, 1) var min_columns := 4
@export_range(2, 8, 1) var max_columns := 5
@export var enforce_square_layout := true
@export_range(1, 32, 1) var minimum_random_toggles := 6
@export_range(1, 64, 1) var maximum_random_toggles := 16
@export_range(32.0, 196.0, 2.0, "suffix:px") var cell_size := 112.0
@export var cell_on_color := Color(1.0, 0.93, 0.46, 1.0)
@export var cell_off_color := Color(0.1, 0.12, 0.16, 1.0)
@export var cell_solved_color := Color(0.46, 1.0, 0.65, 1.0)
@export var allow_solver_button := false
@export_range(0.05, 0.6, 0.05, "seconds") var auto_solve_step_delay := 0.18
@export var reward_mix: Array[String] = ["equipment", "equipment", "consumable", "gold"]
@export var debuff_pool: Array[FW_Buff] = []

@onready var board_grid: GridContainer = %BoardGrid
@onready var status_label: Label = %StatusLabel
@onready var helper_label: Label = %HelperLabel
@onready var moves_label: Label = %MovesLabel
@onready var puzzle_label: Label = %PuzzleLabel
@onready var shuffle_button: Button = %ShuffleButton
@onready var auto_solve_button: Button = %AutoSolveButton
@onready var loot_screen: Node = %LootScreen

var _rng := RandomNumberGenerator.new()
var _rows := 0
var _columns := 0
var _cell_states := PackedByteArray()
var _toggle_map: Array[PackedInt32Array] = []
var _cells: Array[LightsOffCell] = []
var _move_history := PackedInt32Array()
var _solution := PackedInt32Array()
var _is_animating := false
var _round_complete := false
var _loot_manager: FW_LootManager
var _debuff_queue: Array[FW_Buff] = []
var _exit_pending := false

func _ready() -> void:
	_rng.randomize()
	SoundManager.wire_up_all_buttons()
	_connect_loot_screen()
	_connect_ui()
	_start_new_puzzle()

func _connect_ui() -> void:
	if shuffle_button and not shuffle_button.pressed.is_connected(Callable(self, "_on_shuffle_button_pressed")):
		shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	if auto_solve_button and not auto_solve_button.pressed.is_connected(Callable(self, "_on_auto_solve_button_pressed")):
		auto_solve_button.pressed.connect(_on_auto_solve_button_pressed)

func _connect_loot_screen() -> void:
	if not is_instance_valid(loot_screen):
		return
	if loot_screen.has_signal("back_button"):
		var callable := Callable(self, "_on_loot_screen_back_button")
		if loot_screen.back_button and not loot_screen.back_button.is_connected(callable):
			loot_screen.back_button.connect(callable)

func _on_shuffle_button_pressed() -> void:
	if _is_animating:
		return
	_start_new_puzzle()
	# shuffle sound
	if SoundManager:
		SoundManager._play_random_sound()

func _start_new_puzzle() -> void:
	_round_complete = false
	_exit_pending = false
	_is_animating = false
	_move_history = PackedInt32Array()
	_solution = PackedInt32Array()
	_generate_dimensions()
	_allocate_state()
	_build_toggle_map()
	if not _build_random_solvable_state():
		printerr("LightsOff: Failed to build a solvable puzzle. Using empty board.")
	_create_cells()
	_update_status_texts()
	_set_board_interactive(true)
	_update_solver_button_state()

func _generate_dimensions() -> void:
	var row_min := mini(min_rows, max_rows)
	var row_max := maxi(min_rows, max_rows)
	_rows = _rng.randi_range(row_min, row_max)
	if enforce_square_layout:
		_columns = _rows
		return
	var col_min := mini(min_columns, max_columns)
	var col_max := maxi(min_columns, max_columns)
	_columns = _rng.randi_range(col_min, col_max)

func _allocate_state() -> void:
	var total := _rows * _columns
	_cell_states = PackedByteArray()
	_cell_states.resize(total)
	for i in range(total):
		_cell_states[i] = 0

func _build_toggle_map() -> void:
	_toggle_map.clear()
	var total := _rows * _columns
	for index in range(total):
		var indices := PackedInt32Array()
		indices.append(index)
		var row := floori(float(index) / float(_columns))
		var column := index - row * _columns
		if row > 0:
			indices.append(_index_for(row - 1, column))
		if row < _rows - 1:
			indices.append(_index_for(row + 1, column))
		if column > 0:
			indices.append(_index_for(row, column - 1))
		if column < _columns - 1:
			indices.append(_index_for(row, column + 1))
		_toggle_map.append(indices)

func _build_random_solvable_state() -> bool:
	var attempts := 0
	var max_attempts := 32
	while attempts < max_attempts:
		var candidate := _create_random_state()
		var result := _solve_board(candidate)
		if result.get("solvable", false):
			_cell_states = candidate
			_solution = result.get("sequence", PackedInt32Array())
			return true
		attempts += 1
	return false

func _create_random_state() -> PackedByteArray:
	var total := _rows * _columns
	var state := PackedByteArray()
	state.resize(total)
	for i in range(total):
		state[i] = 0
	var min_toggles := mini(minimum_random_toggles, maximum_random_toggles)
	var max_toggles := maxi(minimum_random_toggles, maximum_random_toggles)
	var toggle_count := _rng.randi_range(min_toggles, max_toggles)
	for _i in range(toggle_count):
		var index := _rng.randi_range(0, total - 1)
		_apply_toggle_to_state(index, state)
	return state

func _create_cells() -> void:
	if board_grid == null:
		return
	for child in board_grid.get_children():
		child.queue_free()
	_cells.clear()
	board_grid.columns = _columns
	var total := _rows * _columns
	for index in range(total):
		var cell := LightsOffCell.new()
		cell.configure(index, Vector2(cell_size, cell_size), cell_on_color, cell_off_color, cell_solved_color)
		cell.cell_activated.connect(_on_cell_activated)
		board_grid.add_child(cell)
		_cells.append(cell)
	_update_cells_visuals(false)

func _update_cells_visuals(solved: bool) -> void:
	var total := _cell_states.size()
	for index in range(total):
		if index >= _cells.size():
			continue
		var cell := _cells[index]
		var is_on := _cell_states[index] == 1
		cell.set_state(is_on, solved)

func _on_cell_activated(index: int) -> void:
	if _round_complete or _is_animating:
		return
	_toggle_cell(index, true)
	_update_status_texts()
	if _is_board_cleared():
		_complete_round()

func _toggle_cell(index: int, record_move: bool) -> void:
	_apply_toggle_to_state(index, _cell_states)
	if record_move:
		_move_history.append(index)
	_update_cells_visuals(false)

func _apply_toggle_to_state(index: int, target: PackedByteArray) -> void:
	if index < 0 or index >= _toggle_map.size():
		return
	for cell_index in _toggle_map[index]:
		if cell_index < 0 or cell_index >= target.size():
			continue
		var current := target[cell_index]
		target[cell_index] = 0 if current == 1 else 1

func _is_board_cleared() -> bool:
	for value in _cell_states:
		if value == 1:
			return false
	return true

func _update_status_texts() -> void:
	if status_label:
		var lit := _count_lit_cells()
		status_label.text = "Lights remaining: %d" % lit
	if helper_label:
		helper_label.text = "Tap lights to toggle their neighbors." if not _round_complete else "Puzzle cleared! Claim your loot."
	if moves_label:
		moves_label.text = "Moves: %d" % _move_history.size()
	if puzzle_label:
		puzzle_label.text = "%dx%d grid" % [_rows, _columns]

func _count_lit_cells() -> int:
	var lit := 0
	for value in _cell_states:
		if value == 1:
			lit += 1
	return lit

func _complete_round() -> void:
	_round_complete = true
	_set_board_interactive(false)
	_update_cells_visuals(true)
	_update_status_texts()
	var reward := _build_reward_entry()
	if reward.is_empty():
		return
	var loot_items: Array[FW_Item] = []
	var reward_type := String(reward.get("type", ""))
	if reward_type == RESULT_TYPE_EQUIPMENT or reward_type == RESULT_TYPE_CONSUMABLE or reward_type == RESULT_TYPE_GOLD:
		var item: FW_Item = reward.get("item", null)
		if item:
			loot_items.append(item)
	if loot_items.is_empty():
		return
	var manager := _ensure_loot_manager()
	manager.grant_loot_to_player(loot_items)
	var summary := "Lights are out!"
	if SoundManager:
		SoundManager._play_random_win_sound()
	_present_loot_results(loot_items, [], summary)
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	# done

func _set_board_interactive(enabled: bool) -> void:
	for cell in _cells:
		cell.disabled = not enabled

func _present_loot_results(items: Array, debuffs: Array, summary: String) -> void:
	if not is_instance_valid(loot_screen):
		return
	var trimmed := summary.strip_edges()
	if loot_screen.has_method("show_loot_collection"):
		loot_screen.call("show_loot_collection", items, trimmed, debuffs)
	elif not items.is_empty() and loot_screen.has_method("show_single_loot"):
		loot_screen.call("show_single_loot", items[0])
		if trimmed != "" and loot_screen.has_method("show_text"):
			loot_screen.call("show_text", trimmed)
	elif not debuffs.is_empty() and loot_screen.has_method("show_buffs"):
		loot_screen.call("show_buffs", debuffs)
		if trimmed != "" and loot_screen.has_method("show_text"):
			loot_screen.call("show_text", trimmed)
	if loot_screen.has_method("slide_in"):
		loot_screen.call("slide_in")

func _build_reward_entry() -> Dictionary:
	var reward_type := _pick_reward_type()
	match reward_type:
		RESULT_TYPE_EQUIPMENT:
			return _prepare_equipment_reward()
		RESULT_TYPE_CONSUMABLE:
			return _prepare_consumable_reward()
		RESULT_TYPE_GOLD:
			return _prepare_gold_reward()
	return {}

func _pick_reward_type() -> String:
	if reward_mix.is_empty():
		return RESULT_TYPE_GOLD
	var index := _rng.randi_range(0, reward_mix.size() - 1)
	return reward_mix[index]

func _ensure_loot_manager() -> FW_LootManager:
	_loot_manager = FW_MinigameRewardHelper.ensure_loot_manager(_loot_manager)
	return _loot_manager

func _prepare_equipment_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var item: FW_Item = manager.sweet_loot()
	if item == null:
		return {}
	return {
		"type": RESULT_TYPE_EQUIPMENT,
		"item": item,
		"icon": item.texture,
		"description": "Recovered %s" % item.name,
	}

func _prepare_consumable_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var item: FW_Item = manager.generate_random_consumable()
	if item == null:
		return {}
	return {
		"type": RESULT_TYPE_CONSUMABLE,
		"item": item,
		"icon": item.texture,
		"description": "Bottled %s" % item.name,
	}

func _prepare_gold_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var amount := _rng.randi_range(60, 180)
	var item: FW_Item = manager.create_gold_item(amount)
	if item == null:
		return {}
	item.name = "%d gp" % amount
	if item.texture == null:
		item.texture = DEFAULT_GOLD_ICON
	return {
		"type": RESULT_TYPE_GOLD,
		"item": item,
		"icon": item.texture,
		"description": "Banked %d gold" % amount,
	}

func _draw_random_debuff() -> FW_Buff:
	if _debuff_queue.is_empty():
		_debuff_queue = FW_MinigameRewardHelper.build_debuff_queue(debuff_pool)
	return FW_MinigameRewardHelper.draw_buff_from_queue(_debuff_queue)

func _queue_debuff(buff: FW_Buff) -> void:
	FW_MinigameRewardHelper.queue_debuff_on_player(buff)

func _apply_forfeit_penalty() -> bool:
	var buff := _draw_random_debuff()
	if buff == null:
		return false
	_queue_debuff(buff)
	if helper_label and not _round_complete:
		helper_label.text = "Fleeing in the dark invites curses..."
	_present_loot_results([], [buff], "The darkness follows you.")
	return true

func _solve_board(state: PackedByteArray) -> Dictionary:
	if state.is_empty():
		return {"solvable": true, "sequence": PackedInt32Array()}
	var width := _columns
	var height := _rows
	var row_mask := (1 << width) - 1
	var board_rows := []
	for row in range(height):
		var value := 0
		for column in range(width):
			var index := _index_for(row, column)
			if state[index] == 1:
				value |= 1 << column
		board_rows.append(value)
	var best_sequence := PackedInt32Array()
	var best_move_count := 1 << 30
	var solvable := false
	var max_mask := 1 << width
	for first_row_mask in range(max_mask):
		var lamps := board_rows.duplicate()
		var presses: Array[int] = []
		var current_mask := first_row_mask
		var success := true
		for row_index in range(height):
			presses.append(current_mask)
			lamps[row_index] ^= current_mask
			lamps[row_index] ^= (current_mask << 1) & row_mask
			lamps[row_index] ^= (current_mask >> 1)
			if row_index + 1 < height:
				lamps[row_index + 1] ^= current_mask
				current_mask = lamps[row_index]
			else:
				if lamps[row_index] != 0:
					success = false
					break
		if not success:
			continue
		if lamps[height - 1] != 0:
			continue
		var move_count := 0
		for mask_value in presses:
			move_count += _bit_count(mask_value)
		if move_count < best_move_count:
			solvable = true
			best_move_count = move_count
			best_sequence = _flatten_press_rows(presses)
	if solvable:
		return {"solvable": true, "sequence": best_sequence}
	return {"solvable": false}

func _flatten_press_rows(rows: Array[int]) -> PackedInt32Array:
	var sequence := PackedInt32Array()
	for row in range(rows.size()):
		var mask := rows[row]
		for column in range(_columns):
			if (mask >> column) & 1:
				sequence.append(_index_for(row, column))
	return sequence

func _bit_count(value: int) -> int:
	var count := 0
	var temp := value
	while temp > 0:
		count += temp & 1
		temp >>= 1
	return count

func _update_solver_button_state() -> void:
	if auto_solve_button == null:
		return
	auto_solve_button.visible = allow_solver_button
	auto_solve_button.disabled = not allow_solver_button or _solution.is_empty()

func _on_auto_solve_button_pressed() -> void:
	if _round_complete or _is_animating:
		return
	if _solution.is_empty():
		return
	_is_animating = true
	_set_board_interactive(false)
	await _play_solution_sequence()
	_is_animating = false
	if _is_board_cleared():
		_complete_round()
	else:
		_set_board_interactive(true)

func _play_solution_sequence() -> void:
	for index in _solution:
		_toggle_cell(index, false)
		# play a small step sound while playing the solution sequence
		if SoundManager:
			SoundManager._play_random_sound()
		await get_tree().create_timer(auto_solve_step_delay).timeout
	_update_status_texts()

func _index_for(row: int, column: int) -> int:
	return row * _columns + column

func _on_loot_screen_back_button() -> void:
	_on_back_button_pressed()

func _on_back_button_pressed() -> void:
	if not _round_complete:
		if _exit_pending:
			_exit_pending = false
		else:
			_exit_pending = _apply_forfeit_penalty()
			if _exit_pending:
				return
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	ScreenRotator.change_scene("res://Scenes/level_select2.tscn")
