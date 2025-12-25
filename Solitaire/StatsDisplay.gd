class_name FW_StatsDisplay
extends Control

# Summary card labels
@onready var total_games_label: Label = %TotalGamesLabel
@onready var win_rate_label: Label = %WinRateLabel
@onready var total_wins_label: Label = %TotalWinsLabel
@onready var total_losses_label: Label = %TotalLossesLabel
@onready var current_streak_label: Label = %CurrentStreakLabel
@onready var best_streak_label: Label = %BestStreakLabel
@onready var best_time_label: Label = %BestTimeLabel
@onready var best_moves_label: Label = %BestMovesLabel
@onready var highest_score_label: Label = %HighestScoreLabel
@onready var avg_moves_label: Label = %AvgMovesLabel

# Charts
@onready var win_rate_chart: FW_Chart = %WinRateChart
@onready var score_chart: FW_Chart = %ScoreChart
@onready var time_chart: FW_Chart = %TimeChart
@onready var charts_container: VBoxContainer = %ChartsContainer

var _charts_initialized: bool = false  # Track if charts have been set up

# Recent games
@onready var recent_games_container: VBoxContainer = %RecentGamesContainer

var game_stats: FW_GameStats

func _ready() -> void:
	# Hide charts immediately to prevent any drawing before setup
	if win_rate_chart:
		win_rate_chart.visible = false
	if score_chart:
		score_chart.visible = false
	if time_chart:
		time_chart.visible = false
	
	# Don't initialize charts in _ready() - defer until first display
	# Enable drag passthrough so dragging anywhere (including over child
	# Controls) will also send drag events to this Control. We exclude any
	# named controls in `drag_exclude_names` (for example, the Back button).
	# Do this deferred so the whole scene tree is ready.
	call_deferred("_enable_drag_passthrough")

# Exported list of child node names to exclude from passthrough (back button)
@export var drag_exclude_names: Array = ["BackButton"]

func _enable_drag_passthrough() -> void:
	# Walk the subtree and set mouse_filter = MOUSE_FILTER_PASS on Controls
	# so this Control's _gui_input sees drags even when they start over children.
	# Excluded names will be skipped to preserve their normal behavior.
	_apply_mouse_filter_pass(self)

func _apply_mouse_filter_pass(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			# Skip excluded names (exact match)
			if drag_exclude_names.has(child.name):
				# Leave as-is so Back button (or others) can fully consume events
				pass
			else:
				# Allow child to still receive the event but pass it upward too
				child.mouse_filter = Control.MOUSE_FILTER_PASS
		# Recurse into children so nested controls are also set
		_apply_mouse_filter_pass(child)

func _gui_input(event: InputEvent) -> void:
	# Simple achievements-style drag-to-scroll handler.
	# If the user drags with left mouse or with touch, move the ScrollContainer.
	if (
		(event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT) or
		event is InputEventScreenDrag
	):
		var scroll = $MarginContainer/ScrollContainer
		if scroll:
			scroll.scroll_vertical -= event.relative.y

func _ensure_charts_ready() -> bool:
	if _charts_initialized:
		return true

	if win_rate_chart and score_chart and time_chart:
		_charts_initialized = true

	# Hide charts initially until first plot
	if win_rate_chart:
		win_rate_chart.visible = false
		win_rate_chart.x_domain = { lb = 0, ub = 1, has_decimals = false, fixed = false }
		win_rate_chart.y_domain = { lb = 0, ub = 1, has_decimals = false, fixed = false }
	if score_chart:
		score_chart.visible = false
		score_chart.x_domain = { lb = 0, ub = 1, has_decimals = false, fixed = false }
		score_chart.y_domain = { lb = 0, ub = 1, has_decimals = false, fixed = false }
	if time_chart:
		time_chart.visible = false
		time_chart.x_domain = { lb = 0, ub = 1, has_decimals = false, fixed = false }
		time_chart.y_domain = { lb = 0, ub = 1, has_decimals = false, fixed = false }

	if win_rate_chart == null or score_chart == null or time_chart == null:
		push_error("StatsDisplay: One or more charts are null!")
		return false

	_charts_initialized = true
	return true

func update_display(stats: FW_GameStats) -> void:
	if stats == null:
		return

	# Hide charts to prevent drawing during updates
	if win_rate_chart:
		win_rate_chart.visible = false
	if score_chart:
		score_chart.visible = false
	if time_chart:
		time_chart.visible = false

	var charts_ready := _ensure_charts_ready()

	game_stats = stats
	_update_summary_cards()
	_populate_recent_games()
	if charts_ready:
		_plot_all_charts()
	else:
		if charts_container:
			charts_container.visible = false
	_animate_entry()

func _update_summary_cards() -> void:
	var s = game_stats.current_stats

	# Basic stats
	total_games_label.text = str(s.total_games)
	total_wins_label.text = str(s.total_wins)
	total_losses_label.text = str(s.total_losses)

	# Win rate with color coding
	var win_rate = s.get_win_rate()
	win_rate_label.text = "%.1f%%" % win_rate
	if win_rate >= 50.0:
		win_rate_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))  # Green
	elif win_rate >= 30.0:
		win_rate_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))  # Yellow
	else:
		win_rate_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))  # Red

	# Streaks
	current_streak_label.text = str(s.current_streak)
	if s.current_streak > 0:
		current_streak_label.text += " 🔥"
		current_streak_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))

	best_streak_label.text = str(s.best_streak)
	if s.best_streak >= 5:
		best_streak_label.text += " 🏆"

	# Best records
	if s.best_time_seconds > 0:
		best_time_label.text = game_stats.format_time(s.best_time_seconds)
	else:
		best_time_label.text = "—"

	if s.best_moves > 0:
		best_moves_label.text = str(s.best_moves)
	else:
		best_moves_label.text = "—"

	highest_score_label.text = str(s.highest_score) if s.highest_score > 0 else "—"

	# Averages
	var avg_moves = s.get_average_moves()
	avg_moves_label.text = "%.1f" % avg_moves if avg_moves > 0 else "—"

func _plot_all_charts() -> void:
	if game_stats.current_stats.games_history.is_empty():
		charts_container.visible = false
		return

	charts_container.visible = true
	_plot_win_rate_trend()
	_plot_score_progression()
	_plot_time_trend()

func _plot_win_rate_trend() -> void:
	var history = game_stats.current_stats.games_history
	if history.is_empty():
		return

	# Calculate rolling win rate
	var x_values: Array = []
	var y_values: Array = []
	var wins: int = 0
	var sample_count := history.size()
	var multi_sample := sample_count >= 2

	for i in range(history.size()):
		var record = history[i]
		if record.won:
			wins += 1
		x_values.append(float(i + 1))
		var win_rate = (float(wins) / float(i + 1)) * 100.0
		y_values.append(win_rate)

	_clear_chart_message(win_rate_chart)

	# Show chart now that we're plotting
	win_rate_chart.visible = true

	var function_type := FW_Function.Type.LINE
	var interpolation_mode := FW_Function.Interpolation.LINEAR
	if not multi_sample:
		function_type = FW_Function.Type.SCATTER
		interpolation_mode = FW_Function.Interpolation.NONE

	var function_props := {
		color = Color("#4CAF50"),
		marker = FW_Function.Marker.CIRCLE,
		line_width = 3.0,
		type = function_type,
		interpolation = interpolation_mode
	}

	var cp = FW_ChartProperties.new()
	cp.title = "Win Rate Trend Over Time"
	cp.x_label = "Game Number"
	cp.y_label = "Win Rate %"
	cp.colors.background = Color(0.1, 0.1, 0.1, 0.5)
	cp.colors.frame = Color(0.3, 0.5, 0.8, 0.8)
	cp.colors.grid = Color(0.2, 0.2, 0.2, 0.5)
	cp.colors.text = Color.WHITE_SMOKE
	cp.show_legend = multi_sample
	cp.interactive = true
	cp.x_scale = 5
	cp.y_scale = 5
	cp.draw_bounding_box = false

	if history.size() <= 20:
		cp.max_samples = 0  # Show all
	else:
		cp.max_samples = 50  # Last 50 games
	# Downsample the data to cp.max_samples before plotting to avoid large allocations.
	var target_samples: int = int(cp.max_samples)
	var sampled_x: Array
	var sampled_y: Array
	if target_samples <= 0 or x_values.size() <= target_samples:
		sampled_x = x_values.duplicate()
		sampled_y = y_values.duplicate()
	else:
		var ds: Dictionary = _downsample_min_max(x_values, y_values, target_samples)
		sampled_x = ds.x
		sampled_y = ds.y

	if sampled_x.size() == 0:
		sampled_x = x_values.duplicate()
		sampled_y = y_values.duplicate()

	var x_min := float(sampled_x[0])
	var x_max := float(sampled_x[sampled_x.size() - 1])
	if is_equal_approx(x_min, x_max):
		x_min -= 0.5
		x_max += 0.5
	win_rate_chart.set_x_domain(x_min, x_max)
	win_rate_chart.set_y_domain(0.0, 100.0)

	var function = FW_Function.new(sampled_x, sampled_y, "Win Rate", function_props)
	win_rate_chart.plot([function], cp)

func _plot_score_progression() -> void:
	var history = game_stats.current_stats.games_history
	if history.is_empty():
		_display_chart_message(score_chart, "No games played yet")
		return

	# Plot score progression over all games (both wins and losses)
	var x_values: Array = []
	var y_values: Array = []

	for i in range(history.size()):
		var record = history[i]
		x_values.append(float(i + 1))  # Game number
		y_values.append(float(record.score))

	var sample_count := x_values.size()

	_clear_chart_message(score_chart)
	score_chart.visible = true

	var function_type := FW_Function.Type.AREA
	var interpolation_mode := FW_Function.Interpolation.LINEAR
	if sample_count < 2:
		function_type = FW_Function.Type.SCATTER
		interpolation_mode = FW_Function.Interpolation.NONE

	var function_props := {
		color = Color(0.8, 0.6, 0.2, 0.7),
		type = function_type,
		interpolation = interpolation_mode,
		marker = FW_Function.Marker.CIRCLE if sample_count < 2 else FW_Function.Marker.NONE,
		line_width = 2.5
	}

	var cp = FW_ChartProperties.new()
	cp.title = "Score Progression Over Time"
	cp.x_label = "Game Number"
	cp.y_label = "Score"
	cp.colors.background = Color(0.1, 0.1, 0.1, 0.5)
	cp.colors.frame = Color(0.3, 0.5, 0.8, 0.8)
	cp.colors.grid = Color(0.2, 0.2, 0.2, 0.5)
	cp.colors.text = Color.WHITE_SMOKE
	cp.show_legend = sample_count >= 2
	cp.interactive = true
	cp.draw_bounding_box = false
	cp.x_scale = 5
	cp.y_scale = 5

	if history.size() <= 20:
		cp.max_samples = 0  # Show all
	else:
		cp.max_samples = 50  # Last 50 games

	# Downsample the data to cp.max_samples before plotting to avoid large allocations
	var target_samples: int = int(cp.max_samples)
	var sampled_x: Array
	var sampled_y: Array
	if target_samples <= 0 or x_values.size() <= target_samples:
		sampled_x = x_values.duplicate()
		sampled_y = y_values.duplicate()
	else:
		var downsampled = _downsample_min_max(x_values, y_values, target_samples)
		sampled_x = downsampled.x
		sampled_y = downsampled.y

	if sampled_x.size() == 0:
		_display_chart_message(score_chart, "No data to display")
		return

	var x_min := float(sampled_x[0])
	var x_max := float(sampled_x[sampled_x.size() - 1])
	if is_equal_approx(x_min, x_max):
		x_min -= 0.5
		x_max += 0.5
	score_chart.set_x_domain(x_min, x_max)

	# Set y domain based on score range
	var y_min := float(sampled_y.min()) if sampled_y.size() > 0 else 0.0
	var y_max := float(sampled_y.max()) if sampled_y.size() > 0 else 100.0
	if is_equal_approx(y_min, y_max):
		y_min = max(0.0, y_max - 50.0)
		y_max += 50.0
	else:
		# Add some padding for better visualization
		var y_range = y_max - y_min
		y_min = max(0.0, y_min - y_range * 0.1)
		y_max += y_range * 0.1
	score_chart.set_y_domain(y_min, y_max)

	var function = FW_Function.new(sampled_x, sampled_y, "Score", function_props)
	score_chart.plot([function], cp)

func _plot_time_trend() -> void:
	var history = game_stats.current_stats.games_history
	if history.is_empty():
		return

	# Plot time for recent games (wins only)
	var x_values: Array = []
	var y_values: Array = []
	var game_num = 0

	for i in range(history.size()):
		var record = history[i]
		if record.won:
			game_num += 1
			x_values.append(float(game_num))
			y_values.append(record.time_seconds / 60.0)  # Convert to minutes

	var wins_count := x_values.size()
	if wins_count == 0:
		_display_chart_message(time_chart, "Win a game to track completion times.")
		return

	_clear_chart_message(time_chart)
	time_chart.visible = true

	var time_function_type := FW_Function.Type.AREA
	var time_interpolation := FW_Function.Interpolation.LINEAR
	if wins_count < 2:
		time_function_type = FW_Function.Type.SCATTER
		time_interpolation = FW_Function.Interpolation.NONE

	var cp = FW_ChartProperties.new()
	cp.title = "Win Time Trend"
	cp.x_label = "Win Number"
	cp.y_label = "Time (minutes)"
	cp.colors.background = Color(0.1, 0.1, 0.1, 0.5)
	cp.colors.frame = Color(0.3, 0.5, 0.8, 0.8)
	cp.colors.grid = Color(0.2, 0.2, 0.2, 0.5)
	cp.colors.text = Color.WHITE_SMOKE
	cp.show_legend = wins_count >= 2
	cp.interactive = true
	cp.draw_bounding_box = false
	cp.x_scale = 5
	cp.y_scale = 4

	if x_values.size() <= 20:
		cp.max_samples = 0
	else:
		cp.max_samples = 30
	# Downsample before creating Function to reduce memory pressure for larger histories
	var target_samples: int = int(cp.max_samples)
	var sampled_x: Array
	var sampled_y: Array
	if target_samples <= 0 or x_values.size() <= target_samples:
		sampled_x = x_values.duplicate()
		sampled_y = y_values.duplicate()
	else:
		var ds: Dictionary = _downsample_min_max(x_values, y_values, target_samples)
		sampled_x = ds.x
		sampled_y = ds.y

	if sampled_x.size() == 0:
		sampled_x = x_values.duplicate()
		sampled_y = y_values.duplicate()

	var time_x_min := float(sampled_x[0])
	var time_x_max := float(sampled_x[sampled_x.size() - 1])
	if is_equal_approx(time_x_min, time_x_max):
		time_x_min -= 0.5
		time_x_max += 0.5
	var time_y_max := float(sampled_y.max()) if sampled_y.size() > 0 else 0.0
	if time_y_max <= 0.0:
		time_y_max = 1.0
	else:
		time_y_max += max(0.5, time_y_max * 0.1)
	time_chart.set_x_domain(time_x_min, time_x_max)
	time_chart.set_y_domain(0.0, time_y_max)

	var function = FW_Function.new(sampled_x, sampled_y, "Completion Time", {
		color = Color("#FF9800"),
		marker = FW_Function.Marker.CIRCLE,
		type = time_function_type,
		interpolation = time_interpolation,
		line_width = 2.0
	})
	time_chart.plot([function], cp)

func _downsample_min_max(x_values: Array, y_values: Array, max_samples: int) -> Dictionary:
	# Min/max per-bucket downsampler. Returns a Dictionary { x: Array, y: Array }
	var n: int = x_values.size()
	if n == 0:
		return {"x": [], "y": []}
	if max_samples <= 0 or n <= max_samples:
		return {"x": x_values.duplicate(), "y": y_values.duplicate()}

	var out_x: Array = []
	var out_y: Array = []
	var bucket_size: float = float(n) / float(max_samples)

	for b in range(max_samples):
		var start: int = int(floor(b * bucket_size))
		var end: int = int(floor((b + 1) * bucket_size))
		if b == max_samples - 1:
			end = n
		end = min(end, n)
		if start >= end:
			continue

		var min_v: float = INF
		var max_v: float = -INF
		var min_idx: int = start
		var max_idx: int = start

		for i in range(start, end):
			var v = float(y_values[i])
			if v < min_v:
				min_v = v
				min_idx = i
			if v > max_v:
				max_v = v
				max_idx = i

		# Append points preserving order
		if min_idx <= max_idx:
			out_x.append(x_values[min_idx]); out_y.append(y_values[min_idx])
			if max_idx != min_idx:
				out_x.append(x_values[max_idx]); out_y.append(y_values[max_idx])
		else:
			out_x.append(x_values[max_idx]); out_y.append(y_values[max_idx])
			if max_idx != min_idx:
				out_x.append(x_values[min_idx]); out_y.append(y_values[min_idx])

	return {"x": out_x, "y": out_y}

func _display_chart_message(chart: FW_Chart, message: String) -> void:
	if chart == null:
		return
	var canvas := chart.get_node_or_null("Canvas") as Control
	if canvas:
		canvas.hide()
	var label := chart.get_node_or_null("NoDataLabel") as Label
	if label == null:
		label = Label.new()
		label.name = "NoDataLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chart.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = message
	label.show()
	chart.visible = true
	chart.modulate = Color(1, 1, 1, 1)
	chart.scale = Vector2.ONE

func _clear_chart_message(chart: FW_Chart) -> void:
	if chart == null:
		return
	var label := chart.get_node_or_null("NoDataLabel") as Label
	if label:
		label.hide()
	var canvas := chart.get_node_or_null("Canvas") as Control
	if canvas:
		canvas.show()

func _populate_recent_games() -> void:
	# Clear existing items
	for child in recent_games_container.get_children():
		child.queue_free()

	var history = game_stats.current_stats.games_history
	if history.is_empty():
		var no_data = Label.new()
		no_data.text = "No games played yet"
		no_data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_data.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		recent_games_container.add_child(no_data)
		return

	# Show last 15 games
	var start_idx = maxi(0, history.size() - 15)
	for i in range(history.size() - 1, start_idx - 1, -1):
		var record = history[i]
		var item = _create_game_history_item(record, i + 1)
		recent_games_container.add_child(item)

		# Animate items sliding in from right
		_animate_history_item(item, (history.size() - 1 - i) * 0.05)

func _animate_history_item(item: PanelContainer, delay: float) -> void:
	item.modulate = Color(1, 1, 1, 0)
	item.position.x = 50

	await get_tree().create_timer(delay).timeout

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(item, "modulate", Color(1, 1, 1, 1), 0.3)
	tween.tween_property(item, "position:x", 0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _create_game_history_item(record: FW_GameStats.GameRecord, game_number: int) -> PanelContainer:
	var panel = PanelContainer.new()

	# Style based on win/loss
	var style_box = StyleBoxFlat.new()
	if record.won:
		style_box.bg_color = Color(0.2, 0.4, 0.2, 0.3)  # Green tint
		style_box.border_color = Color(0.3, 0.8, 0.3, 0.8)
	else:
		style_box.bg_color = Color(0.4, 0.2, 0.2, 0.3)  # Red tint
		style_box.border_color = Color(0.8, 0.3, 0.3, 0.8)

	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style_box)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	# Game number
	var num_label = Label.new()
	num_label.text = "#%d" % game_number
	num_label.custom_minimum_size = Vector2(60, 0)
	num_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(num_label)

	# Result icon
	var result_label = Label.new()
	result_label.text = "✓" if record.won else "✗"
	result_label.custom_minimum_size = Vector2(40, 0)
	result_label.add_theme_font_size_override("font_size", 24)
	if record.won:
		result_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		result_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	hbox.add_child(result_label)

	# Stats
	var stats_vbox = VBoxContainer.new()
	stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(stats_vbox)

	var info_line1 = Label.new()
	info_line1.text = "Moves: %d | Time: %s | Score: %d" % [record.moves, record.game_duration_string, record.score]
	info_line1.add_theme_font_size_override("font_size", 14)
	stats_vbox.add_child(info_line1)

	var info_line2 = Label.new()
	var mode_text = "3-Card" if record.draw_mode else "1-Card"
	var extras: Array = []
	if record.undo_count > 0:
		extras.append("%d undos" % record.undo_count)
	if record.stock_cycles > 0:
		extras.append("%d cycles" % record.stock_cycles)
	if record.auto_completed:
		extras.append("auto-complete")

	var extra_text = " | ".join(extras) if not extras.is_empty() else "no undos"
	info_line2.text = "%s | %s" % [mode_text, extra_text]
	info_line2.add_theme_font_size_override("font_size", 12)
	info_line2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_vbox.add_child(info_line2)

	return panel

func _animate_entry() -> void:
	# Start invisible
	modulate = Color(1, 1, 1, 0)

	# Fade in the whole display
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.4)

	# Animate summary cards with counting
	await fade_tween.finished
	_animate_summary_cards()

	# Stagger chart animations
	if charts_container.visible:
		await get_tree().create_timer(0.3).timeout
		_animate_charts()

func _animate_summary_cards() -> void:
	# Animate numbers counting up
	var s = game_stats.current_stats

	# Total games count up
	_count_up_label(total_games_label, 0, s.total_games, 0.5)
	await get_tree().create_timer(0.1).timeout

	# Wins and losses
	_count_up_label(total_wins_label, 0, s.total_wins, 0.5)
	_count_up_label(total_losses_label, 0, s.total_losses, 0.5)
	await get_tree().create_timer(0.1).timeout

	# Win rate with pulse
	var win_rate = s.get_win_rate()
	_count_up_label_float(win_rate_label, 0.0, win_rate, 0.6, "%.1f%%")
	_pulse_label(win_rate_label)

func _count_up_label(label: Label, from: int, to: int, duration: float) -> void:
	if label == null:
		return

	var tween = create_tween()
	tween.tween_method(func(value: int):
		label.text = str(value)
	, from, to, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _count_up_label_float(label: Label, from: float, to: float, duration: float, format: String) -> void:
	if label == null:
		return

	var tween = create_tween()
	tween.tween_method(func(value: float):
		label.text = format % value
	, from, to, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _pulse_label(label: Label) -> void:
	if label == null:
		return

	var original_scale = label.scale
	var tween = create_tween()
	tween.tween_property(label, "scale", original_scale * 1.2, 0.2)
	tween.tween_property(label, "scale", original_scale, 0.2)

func _animate_charts() -> void:
	# Fade in each chart with stagger
	var charts = [win_rate_chart, score_chart, time_chart]

	for i in range(charts.size()):
		var chart = charts[i]
		if chart == null or not chart.visible:
			continue
		var canvas := chart.get_node_or_null("Canvas") as Control
		if canvas and not canvas.visible:
			continue

		chart.modulate = Color(1, 1, 1, 0)
		chart.scale = Vector2(0.9, 0.9)

		await get_tree().create_timer(0.15).timeout

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(chart, "modulate", Color(1, 1, 1, 1), 0.4)
		tween.tween_property(chart, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
