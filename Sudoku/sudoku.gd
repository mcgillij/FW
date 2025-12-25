extends CanvasLayer

@onready var board: FW_SudokuBoard = %Board
@onready var number_pad: VBoxContainer = %NumberPad
@onready var note_toggle: Button = %NoteToggle
@onready var hint_button: Button = %HintButton
@onready var clear_button: Button = %ClearButton
@onready var undo_button: Button = %UndoButton
@onready var difficulty_buttons: HBoxContainer = %DifficultyButtons
@onready var timer_label: Label = %TimerLabel
@onready var mistakes_label: Label = %MistakesLabel
@onready var difficulty_label: Label = %DifficultyLabel
@onready var status_label: Label = %StatusLabel

@onready var win_overlay: ColorRect = %WinOverlay
@onready var win_panel: Control = %WinVBox
@onready var win_title_label: Label = %WinTitleLabel
@onready var win_stats_label: RichTextLabel = %WinStatsLabel

var _generator := FW_SudokuGenerator.new()
var _stats: FW_SudokuStats = FW_SudokuStats.new()
var _elapsed := 0.0
var _running := false
var _mistakes := 0
var _hints_used := 0
var _hint_limit := 3
var _difficulty := "easy"
var _win_tweens: Array[Tween] = []

func _ready() -> void:
	SoundManager.wire_up_all_buttons()
	_connect_signals()
	_configure_hint_button_style()
	_start_new_game()
	set_process(true)

func _process(delta: float) -> void:
	if _running:
		_elapsed += delta
		_update_timer()

func _connect_signals() -> void:
	board.puzzle_completed.connect(_on_puzzle_completed)
	board.mistake_made.connect(_on_mistake_made)
	for child in number_pad.get_children():
		if child is Button:
			var label: String = child.text.strip_edges()
			var value := int(label)
			child.pressed.connect(_on_number_pressed.bind(value))
	note_toggle.toggled.connect(_on_note_toggled)
	hint_button.pressed.connect(_on_hint_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	undo_button.pressed.connect(_on_undo_pressed)
	for child in difficulty_buttons.get_children():
		if child is Button:
			child.pressed.connect(_on_difficulty_pressed.bind(child.text.strip_edges().to_lower()))
	if win_overlay:
		win_overlay.gui_input.connect(_on_win_overlay_gui_input)

func _on_difficulty_pressed(value: String) -> void:
	_set_difficulty(value)

func _configure_hint_button_style() -> void:
	var dark := Color(0, 0, 0)
	hint_button.add_theme_color_override("font_color", dark)
	hint_button.add_theme_color_override("font_color_hover", dark)
	hint_button.add_theme_color_override("font_color_pressed", dark)
	hint_button.add_theme_color_override("font_color_focus", dark)
	hint_button.add_theme_color_override("font_color_disabled", dark)
	hint_button.add_theme_color_override("font_outline_color", Color(1,1,1))

func _update_note_ui() -> void:
	note_toggle.text = "Notes: ON" if note_toggle.button_pressed else "Notes: OFF"

func _start_new_game() -> void:
	_clear_win_tweens()
	_hide_victory_modal(false)
	var data := _generator.generate_puzzle(_difficulty)
	var puzzle: PackedInt32Array = data.get("puzzle", PackedInt32Array())
	var solution: PackedInt32Array = data.get("solution", PackedInt32Array())
	board.setup_puzzle(puzzle, solution)
	_elapsed = 0.0
	_mistakes = 0
	_hints_used = 0
	_running = true
	note_toggle.button_pressed = false
	board.set_note_mode(false)
	_update_note_ui()
	_update_labels()
	status_label.text = "Pick a cell, then a number."

func _on_number_pressed(value: int) -> void:
	board.handle_number_input(value)
	status_label.text = ""
	_update_labels()

func _on_note_toggled(pressed: bool) -> void:
	board.set_note_mode(pressed)
	_update_note_ui()
	status_label.text = "Notes mode: ON" if pressed else "Notes mode: OFF"

func _set_difficulty(value: String) -> void:
	var normalized := value.strip_edges().to_lower()
	var allowed := ["easy", "medium", "hard", "expert"]
	if not allowed.has(normalized):
		normalized = "easy"
	_difficulty = normalized
	for child in difficulty_buttons.get_children():
		if child is Button:
			child.button_pressed = child.text.strip_edges().to_lower() == normalized
	_update_labels()
	_start_new_game()
	status_label.text = "New game: %s" % normalized.capitalize()

func _on_hint_pressed() -> void:
	if _hints_used >= _hint_limit:
		status_label.text = "No hints left."
		_update_labels()
		return
	if board.reveal_hint():
		_hints_used += 1
		_update_labels()
		status_label.text = "Filled a hint cell."
		if _hints_used >= _hint_limit:
			status_label.text = "No hints left."

func _on_clear_pressed() -> void:
	var cleared := board.clear_selected()
	if cleared:
		status_label.text = "Cleared cell."
	else:
		status_label.text = "Select an editable cell to clear."
	_update_labels()

func _on_undo_pressed() -> void:
	if board.undo_last_move():
		status_label.text = "Undid last move."
		_update_labels()

func _on_mistake_made() -> void:
	_mistakes += 1
	_update_labels()
	status_label.text = "That number doesn't fit."

func _on_puzzle_completed() -> void:
	_running = false
	_update_timer()
	status_label.text = "Solved! Nice work."
	var record := _stats.record_game(true, _elapsed, _mistakes, _hints_used, _hint_limit, _difficulty)
	SoundManager._play_random_win_sound()
	_show_victory_modal(record)

func _update_labels() -> void:
	_update_timer()
	mistakes_label.text = "Mistakes: %d" % _mistakes
	difficulty_label.text = "Difficulty: %s" % _difficulty.capitalize()
	hint_button.text = "Hint (%d/%d)" % [_hint_limit - _hints_used, _hint_limit]
	hint_button.disabled = _hints_used >= _hint_limit
	undo_button.disabled = not board.can_undo()

func _update_timer() -> void:
	timer_label.text = _format_time(_elapsed)

func _format_time(seconds: float) -> String:
	var total_seconds := int(seconds)
	var mins := int(total_seconds / 60.0)
	var secs := total_seconds % 60
	return "%02d:%02d" % [mins, secs]

func _show_victory_modal(record: FW_SudokuStats.GameRecord) -> void:
	if win_overlay == null or win_panel == null:
		return
	_clear_win_tweens()
	win_overlay.visible = true
	win_overlay.modulate = Color(1, 1, 1, 0)
	win_panel.modulate = Color(1, 1, 1, 0)
	win_panel.scale = Vector2(0.9, 0.9)
	win_panel.rotation = -0.2
	win_panel.pivot_offset = win_panel.size * 0.5
	if win_title_label:
		win_title_label.text = "🎉 Sudoku Victory! 🎉"
		win_title_label.self_modulate = Color.WHITE
	if win_stats_label:
		win_stats_label.text = _build_victory_summary(record)
	var tween := get_tree().create_tween()
	_track_win_tween(tween)
	tween.set_parallel(true)
	tween.tween_property(win_overlay, "modulate", Color(1, 1, 1, 0.88), 0.25)
	tween.tween_property(win_panel, "modulate", Color(1, 1, 1, 1), 0.3)
	tween.tween_property(win_panel, "scale", Vector2(1.08, 1.08), 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(win_panel, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var pulse := get_tree().create_tween()
	_track_win_tween(pulse)
	pulse.set_loops()
	pulse.tween_property(win_panel, "scale", Vector2(1.02, 1.02), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(win_panel, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if win_title_label:
		var color_tween := get_tree().create_tween()
		_track_win_tween(color_tween)
		color_tween.set_loops()
		var colors := [
			Color(1.0, 0.82, 0.32),
			Color(0.6, 0.85, 1.0),
			Color(0.8, 1.0, 0.6),
			Color(1.0, 0.65, 0.85),
		]
		for c in colors:
			color_tween.tween_property(win_title_label, "self_modulate", c, 0.6)

func _hide_victory_modal(start_new: bool) -> void:
	_clear_win_tweens()
	if win_overlay:
		win_overlay.visible = false
	if start_new:
		_start_new_game()

func _on_win_overlay_gui_input(event: InputEvent) -> void:
	if win_overlay == null or not win_overlay.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_win_continue_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		_on_win_continue_pressed()

func _on_win_continue_pressed() -> void:
	_hide_victory_modal(true)

func _build_victory_summary(record: FW_SudokuStats.GameRecord) -> String:
	var lines: Array[String] = []
	lines.append("[center]⭐ [b]Difficulty:[/b] %s[/center]" % record.difficulty.capitalize())
	lines.append("[center]⏱ [b]Time:[/b] %s[/center]" % record.formatted_time)
	lines.append("[center]❌ [b]Mistakes:[/b] %d[/center]" % record.mistakes)
	lines.append("[center]💡 [b]Hints:[/b] %d/%d[/center]" % [record.hints_used, record.hint_limit])
	var summary := _stats.get_stats()
	lines.append("")
	lines.append("[center]🏆 [b]Wins:[/b] %d / %d[/center]" % [summary.total_wins, summary.total_games])
	lines.append("[center]🥇 [b]Best %s:[/b] %s[/center]" % [record.difficulty.capitalize(), _stats.get_best_time_label(record.difficulty)])
	lines.append("[center]🌟 [b]Best Overall:[/b] %s[/center]" % _stats.get_best_time_label(""))
	lines.append("")
	lines.append("[center][color=#ffd166]Tap to celebrate and start another![/color][/center]")
	return "\n".join(lines)

func _clear_win_tweens() -> void:
	for tween in _win_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_win_tweens.clear()

func _track_win_tween(tween: Tween) -> void:
	if tween != null:
		_win_tweens.append(tween)

func _on_back_button_pressed() -> void:
	ScreenRotator.change_scene("res://Scenes/game_menu2.tscn")
