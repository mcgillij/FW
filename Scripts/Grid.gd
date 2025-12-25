extends Node2D

# signals

signal damage_ice
signal make_ice
signal make_lock
signal damage_lock
signal make_concrete
signal damage_concrete
signal damage_heavy_concrete
signal make_slime
signal damage_slime
signal damage_pink_slime
signal make_heavy_concrete
signal make_pink_slime
# score vars
signal update_score
#counter vars
signal update_counter
# goals
signal check_goal
signal update_mana
# sounds
signal play_sound
signal play_bomb_sound
signal play_sinker_sound
# camera
signal place_camera
signal camera_effect
# level editor signal
signal level_edit_input
signal change_move_state
# vs mode signals
signal end_player_turn
signal end_monster_turn
signal do_damage
# booster
signal booster_inactive

# debugging
@export var preset_spaces: PackedVector3Array
@export var empty_spaces: PackedVector2Array = PackedVector2Array()
@export var level_editor: bool
@export var hint_effect: PackedScene
@export var possible_pieces: PackedStringArray
# collectables / sinkers
@export var sinker_piece: PackedScene
@export var sinkers_in_scene: bool  # toggle to enable sinkers
@export var max_sinkers: int

# vibration
const VIBRATION_DURATION: int = 50
var current_sinkers: int = 0
var next_column_clear: int = -1

var game_manager: FW_GameManager
var can_move: bool = true
var refillable: bool = true # used when doing effects (timer based effects, like bite / claw)
var bomb_triggered : bool = false

# Coroutine AI variables
var pending_enemy_move: Dictionary = {}
var ai_move_ready: bool = false
var _enemy_ai_thread: Thread = null

# obstacle manager
var obstacle_manager = load("res://Obstacles/ObstacleManager.gd").new()

# hint system
var hint_system = load("res://HintSystem/HintSystem.gd").new()

# booster state
var active_booster: String = ""

# effects
var particle_effect = preload("res://Scenes/destroy_particle.tscn")
var animated_explosion = preload("res://Scenes/explosion.tscn")
var move_checked: bool = false
var preview_container: Node2D = null
var preview_cycle_timer: Timer = null
var preview_cycle_data: Dictionary = {}
# main grid of pieces
var main_array: Array = []
var clone_array: Array = []
var current_matches: Array = []
# touch variables
var controlling: bool = false
var first_touch: Vector2 = Vector2(0, 0)
var final_touch: Vector2 = Vector2(0, 0)
var streak: int = 1
var color_bomb_used: bool = false
var bomb_chain_count: int = 0

# Thread AI data holder
var _pending_ai_data: Dictionary = {}

# used to update mana bars
var colors_dict: Dictionary = {
	"green": 0,
	"red": 0,
	"blue": 0,
	"pink": 0,
	"orange": 0
}

var player_moves = FW_GridUtils.Moves.new()

enum BombTypes {
	ADJACENT = 0,
	COLUMN = 1,
	ROW = 2,
	COLOR = 3
}

func _init() -> void:
	obstacle_manager.set_grid(self)
	hint_system.set_grid(self)

func _ready() -> void:
	game_manager = get_node("../GameManager")
	move_camera()
	main_array = GDM.make_2d_array()
	clone_array = GDM.make_2d_array()
	#spawn_preset_pieces  # debugging to make preset levels
	if sinkers_in_scene:
		spawn_sinkers(max_sinkers)

	obstacle_manager.load_obstacle_data(GDM.level)
	spawn_pieces()
	obstacle_manager.spawn_obstacles()

	hint_system.hint_effect = hint_effect
	setup_eventbus_signals()
	preview_container = Node2D.new()
	preview_container.name = "AbilityPreviewLayer"
	preview_container.z_index = 5
	add_child(preview_container)
	preview_cycle_timer = Timer.new()
	preview_cycle_timer.one_shot = true
	preview_cycle_timer.autostart = false
	preview_cycle_timer.name = "AbilityPreviewCycleTimer"
	add_child(preview_cycle_timer)
	preview_cycle_timer.timeout.connect(_on_preview_cycle_timer_timeout)
	if !GDM.is_vs_mode():
		$hint_timer.start()

func setup_eventbus_signals() -> void:
	if GDM.is_vs_mode():
		EventBus.wrap_up_booster.connect(_booster_teardown)
		EventBus.monster_request_tile_move.connect(_start_enemy_ai_thread)
		EventBus.trigger_refill.connect(refill_columns)
		EventBus.start_of_player_turn.connect(_on_player_turn_started)
		EventBus.start_of_monster_turn.connect(_on_player_turn_ended)
	EventBus.ability_preview_requested.connect(_on_ability_preview_requested)
	EventBus.ability_preview_cleared.connect(_on_ability_preview_cleared)

func _on_player_turn_started() -> void:
	$hint_timer.start()

func _on_player_turn_ended() -> void:
	$hint_timer.stop()
	hint_system.destroy_hint()

func _process(_delta) -> void:
	if get_tree().paused:
		return
	if can_move:
		if GDM.is_vs_mode():
			if game_manager.turn_manager.is_player_turn():
				touch_input()
		else:
			touch_input()
	if level_editor:
		level_edit_click()

func _exit_tree() -> void:
	# Ensure the AI thread is cleaned up properly when the node exits the scene tree.
	if _enemy_ai_thread:
		_enemy_ai_thread.wait_to_finish()

func touch_input() -> void:
	if Input.is_action_just_pressed("ui_touch"):
		if GDM.grid.is_in_grid(GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)):
			first_touch = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
			controlling = true
			hint_system.destroy_hint()

	if Input.is_action_just_released("ui_touch"):
		var pos = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
		if controlling:
			controlling = false
			if GDM.grid.is_in_grid(pos):
				final_touch = pos
				touch_difference(first_touch, final_touch)
			else:
				# Cancel the move if released off the grid
				controlling = false
				first_touch = Vector2.ZERO
				final_touch = Vector2.ZERO

func touch_difference(grid_pos1: Vector2, grid_pos2: Vector2) -> void:
	var direction = FW_GridUtils.calculate_touch_direction(grid_pos1, grid_pos2)
	if direction != Vector2.ZERO:
		swap_pieces(grid_pos1.x, grid_pos1.y, direction)

# the main logic for processing the touch input
func swap_pieces(col, row, direction: Vector2):
	var new_col = col + int(direction.x)
	var new_row = row + int(direction.y)
	# Check if new position is within the grid
	if !GDM.grid.is_in_grid(Vector2(new_col, new_row)):
		return
	var first_piece = main_array[col][row]
	var other_piece = main_array[new_col][new_row]
	# Check if both pieces are not null
	if first_piece != null and other_piece != null:
		# Check if the move is not restricted
		if !obstacle_manager.restricted_move(Vector2(col, row)) and !obstacle_manager.restricted_move(Vector2(new_col, new_row)):
			var color_bomb = null
			var other_bomb = null

			if first_piece.is_color_bomb and (other_piece.is_adjacent_bomb or other_piece.is_row_bomb or other_piece.is_col_bomb):
				color_bomb = first_piece
				other_bomb = other_piece
			elif other_piece.is_color_bomb and (first_piece.is_adjacent_bomb or first_piece.is_row_bomb or first_piece.is_col_bomb):
				color_bomb = other_piece
				other_bomb = first_piece

			if color_bomb and other_bomb:
				# --- BOMB + BOMB COMBO LOGIC ---
				if game_manager.turn_manager.is_player_turn() or !GDM.is_vs_mode():
					EventBus.combat_notification.emit(FW_CombatNotification.message_type.BOMB_COMBO)
				color_bomb_used = true
				match_and_dim(color_bomb)
				match_and_dim(other_bomb)
				FW_GridUtils.add_to_array(Vector2(col, row), current_matches)
				FW_GridUtils.add_to_array(Vector2(new_col, new_row), current_matches)

				var target_color = other_bomb.color
				var pieces_to_upgrade = []
				for i in GDM.grid.width:
					for j in GDM.grid.height:
						var p = main_array[i][j]
						if p and p.color == target_color:
							pieces_to_upgrade.append(Vector2(i, j))

				if other_bomb.is_adjacent_bomb:
					for pos in pieces_to_upgrade:
						match_all_adjacent(pos.x, pos.y)
				# Add elif for row/col bombs here in the future
				elif other_bomb.is_col_bomb:
					for pos in pieces_to_upgrade:
						match_all_in_col(pos.x)
				elif other_bomb.is_row_bomb:
					for pos in pieces_to_upgrade:
						match_all_in_row(pos.y)

			elif first_piece.is_color_bomb and other_piece.is_color_bomb:
				if game_manager.turn_manager.is_player_turn() or !GDM.is_vs_mode():
					EventBus.combat_notification.emit(FW_CombatNotification.message_type.GIGA_CLEAR)
				clear_board()
			elif first_piece.is_color_bomb or other_piece.is_color_bomb:
				if is_piece_sinker(col, row) or is_piece_sinker(new_col, new_row):
					swap_back()
					return
				color_bomb_used = true
				if first_piece.is_color_bomb:
					match_color(other_piece.color)
					match_and_dim(first_piece)
					FW_GridUtils.add_to_array(Vector2(col, row), current_matches)
				else:
					match_color(first_piece.color)
					match_and_dim(other_piece)
					FW_GridUtils.add_to_array(Vector2(new_col, new_row), current_matches)
			# Store move info and swap pieces
			player_moves.store_move_info(first_piece, other_piece, Vector2(col, row), direction)
			can_move = false
			emit_signal("change_move_state", can_move)
			main_array[col][row] = other_piece
			main_array[new_col][new_row] = first_piece
			first_piece.move_to_front()
			first_piece.move(GDM.grid.grid_to_pixel(new_col, new_row))
			other_piece.move(GDM.grid.grid_to_pixel(col, row))
			# Check for matches if move hasn't been checked
			if !move_checked:
				find_matches()

# after this function, we go back to waiting for input
func swap_back() -> void:
	var swapped = false
	if player_moves.selected_tiles.size() > 0:
		swap_pieces(player_moves.previous_location.x, player_moves.previous_location.y, player_moves.previous_direction)
		swapped = true
	else:
		streak = 1 #trying to fix whacky combo
	# failed move, move em back
	player_moves.clear_move_info() # trying this out here
	can_move = true
	emit_signal("change_move_state", can_move)
	if !swapped:
		emit_signal("update_counter", streak)
	move_checked = false
	if !GDM.is_vs_mode() or game_manager.turn_manager.is_player_turn():
		$hint_timer.start()

# fill the initial grid with pieces
func spawn_pieces() -> void:
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if !obstacle_manager.restricted_fill(Vector2(i,j)) and main_array[i][j] == null:
				#choose a random number and store it
				var rand = floor(randf_range(0, possible_pieces.size()))
				var piece = load(possible_pieces[rand]).instantiate()
				var loops = 0
				while(FW_GridUtils.match_at(main_array, i, j, piece.color, GDM.grid.width, GDM.grid.height) && loops < 100):
					rand = floor(randf_range(0, possible_pieces.size()))
					loops += 1
					piece = load(possible_pieces[rand]).instantiate()
				add_child(piece)
				piece.position = GDM.grid.grid_to_pixel(i, j)
				main_array[i][j] = piece
	if is_deadlocked():
		shuffle_board()
	if !GDM.is_vs_mode():
		$hint_timer.start()

# use to find matches, and also gather moves for hints if you pass in the query param
func find_matches(query: bool = false, array: Array = main_array) -> bool:
	if not query:
		pass

	var all_matches = {} # Using a dictionary to store unique coordinates

	# Horizontal matches
	for j in GDM.grid.height:
		var i = 0
		while i < GDM.grid.width - 2:
			var p1 = array[i][j]
			if p1 == null or is_piece_sinker(i, j):
				i += 1
				continue

			var match_coords = [Vector2(i,j)]
			for k in range(i + 1, GDM.grid.width):
				var p_next = array[k][j]
				if p_next != null and not is_piece_sinker(k,j) and p_next.color == p1.color:
					match_coords.append(Vector2(k,j))
				else:
					break

			if match_coords.size() >= 3:
				if query: return true
				for coord in match_coords:
					all_matches[coord] = true
				i += match_coords.size()
			else:
				i += 1

	# Vertical matches
	for i in GDM.grid.width:
		var j = 0
		while j < GDM.grid.height - 2:
			var p1 = array[i][j]
			if p1 == null or is_piece_sinker(i, j):
				j += 1
				continue

			var match_coords = [Vector2(i,j)]
			for k in range(j + 1, GDM.grid.height):
				var p_next = array[i][k]
				if p_next != null and not is_piece_sinker(i,k) and p_next.color == p1.color:
					match_coords.append(Vector2(i,k))
				else:
					break

			if match_coords.size() >= 3:
				if query: return true
				for coord in match_coords:
					all_matches[coord] = true
				j += match_coords.size()
			else:
				j += 1

	if query:
		return false

	if all_matches.size() > 0:
		for pos in all_matches.keys():
			FW_GridUtils.add_to_array(pos, current_matches)
			match_and_dim(array[pos.x][pos.y])

	if GDM.is_vs_mode():
		change_booster_tile_colors()

	if current_matches.size() > 0:
		get_bombed_pieces()

	# Always start the timer. destroy_matched() will handle the no-match case.
	$destroy_timer.start()

	return false

func get_bombed_pieces() -> void:
	var processed_bombs = {}
	var idx = 0
	while idx < current_matches.size():
		var pos = current_matches[idx]
		idx += 1

		if FW_GridUtils.is_piece_null(main_array, pos.x, pos.y):
			continue

		var piece = main_array[pos.x][pos.y]
		var key = str(pos.x) + "_" + str(pos.y)
		var is_a_bomb = piece.is_color_bomb or piece.is_adjacent_bomb or piece.is_col_bomb or piece.is_row_bomb

		if is_a_bomb and not processed_bombs.has(key):
			process_bombed_piece(pos.x, pos.y, piece, processed_bombs)

func create_bomb_pulse_effect(start_pos: Vector2, bomb_type: int) -> void:
	var pulse_color = Color(1.0, 1.0, 0.8, 0.7) # A flashy yellow
	var pulse_duration = 0.15
	var pulse_delay_per_tile = 0.04

	match bomb_type:
		BombTypes.ADJACENT:
			var pulse_groups = [
				[Vector2(0, 0)], # Center
				[Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)], # Orthogonals
				[Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]  # Diagonals
			]
			var delay_step = 0.05

			for i in range(pulse_groups.size()):
				var group = pulse_groups[i]
				var delay = i * delay_step
				for offset in group:
					var tile_pos = start_pos + offset
					if GDM.grid.is_in_grid(tile_pos):
						var highlight = ColorRect.new()
						highlight.color = pulse_color
						highlight.size = Vector2(GDM.grid.offset, GDM.grid.offset)
						highlight.position = GDM.grid.grid_to_pixel(tile_pos.x, tile_pos.y) - Vector2(GDM.grid.offset / 2.0, GDM.grid.offset / 2.0)
						highlight.z_index = -1
						highlight.modulate.a = 0.0 # Start invisible
						add_child(highlight)

						var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
						tween.tween_interval(delay)
						tween.tween_property(highlight, "modulate:a", 1.0, pulse_duration)
						tween.chain().tween_property(highlight, "modulate:a", 0.0, pulse_duration * 1.5) # Fade out a bit slower
						tween.chain().tween_callback(highlight.queue_free)

		BombTypes.COLUMN:
			for i in range(GDM.grid.height):
				var delay = i * pulse_delay_per_tile # Creates a top-to-bottom wave
				var highlight = ColorRect.new()
				highlight.color = pulse_color
				highlight.size = Vector2(GDM.grid.offset, GDM.grid.offset)
				highlight.position = GDM.grid.grid_to_pixel(start_pos.x, i) - Vector2(GDM.grid.offset / 2.0, GDM.grid.offset / 2.0)
				highlight.z_index = -1
				highlight.modulate.a = 0.0 # Start invisible
				add_child(highlight)

				var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				# Appear after a delay, then disappear
				tween.tween_interval(delay)
				tween.tween_property(highlight, "modulate:a", 1.0, pulse_duration)
				tween.chain().tween_property(highlight, "modulate:a", 0.0, pulse_duration)
				tween.chain().tween_callback(highlight.queue_free)

		BombTypes.ROW:
			for i in range(GDM.grid.width):
				var delay = i * pulse_delay_per_tile # Creates a left-to-right wave
				var highlight = ColorRect.new()
				highlight.color = pulse_color
				highlight.size = Vector2(GDM.grid.offset, GDM.grid.offset)
				highlight.position = GDM.grid.grid_to_pixel(i, start_pos.y) - Vector2(GDM.grid.offset / 2.0, GDM.grid.offset / 2.0)
				highlight.z_index = -1
				highlight.modulate.a = 0.0 # Start invisible
				add_child(highlight)

				var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				# Appear after a delay, then disappear
				tween.tween_interval(delay)
				tween.tween_property(highlight, "modulate:a", 1.0, pulse_duration)
				tween.chain().tween_property(highlight, "modulate:a", 0.0, pulse_duration)
				tween.chain().tween_callback(highlight.queue_free)


func create_spawn_highlight_effect(grid_pos: Vector2) -> void:
	var pulse_color = Color(0.9, 0.9, 1.0, 0.8) # A light blue/white
	var pulse_duration = 0.25
	var highlight = ColorRect.new()
	highlight.color = pulse_color
	highlight.size = Vector2(GDM.grid.offset, GDM.grid.offset)
	highlight.position = GDM.grid.grid_to_pixel(grid_pos.x, grid_pos.y) - Vector2(GDM.grid.offset / 2.0, GDM.grid.offset / 2.0)
	highlight.z_index = -1
	highlight.modulate.a = 0.0 # Start invisible
	add_child(highlight)

	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(highlight, "modulate:a", 1.0, pulse_duration)
	tween.chain().tween_property(highlight, "modulate:a", 0.0, pulse_duration * 2.0)
	tween.chain().tween_callback(highlight.queue_free)

func create_selection_highlight_effect(grid_pos: Vector2) -> void:
	var pulse_color = Color(1.0, 0.2, 0.2, 0.9) # A more vibrant red
	var pulse_duration = 0.15 # Faster pop
	var highlight = ColorRect.new()
	highlight.color = pulse_color
	highlight.size = Vector2(GDM.grid.offset, GDM.grid.offset)

	# Position the top-left corner of the highlight correctly.
	highlight.position = GDM.grid.grid_to_pixel(grid_pos.x, grid_pos.y) - (highlight.size / 2.0)

	# Set pivot to the center of the highlight for scaling.
	highlight.pivot_offset = highlight.size / 2.0

	highlight.z_index = 1 # Render above pieces
	highlight.modulate = Color(1, 1, 1, 0) # Start invisible
	highlight.scale = Vector2.ZERO # Start scaled down
	add_child(highlight)

	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# Pop in (parallel)
	var pop_in_tween = tween.parallel()
	pop_in_tween.tween_property(highlight, "scale", Vector2(1.2, 1.2), pulse_duration)
	pop_in_tween.tween_property(highlight, "modulate", Color(1, 1, 1, .6), pulse_duration)

	# Hold
	tween.tween_interval(0.2)

	# Pop out (parallel)
	var pop_out_tween = tween.parallel()
	pop_out_tween.tween_property(highlight, "scale", Vector2.ZERO, pulse_duration * 1.5)
	pop_out_tween.tween_property(highlight, "modulate", Color(1, 1, 1, 0), pulse_duration * 1.5)

	tween.tween_callback(highlight.queue_free)

func _on_ability_preview_requested(ability: FW_Ability) -> void:
	if ability == null:
		_clear_ability_preview()
		return
	var payload = ability.get_preview_tiles(self)
	if payload == null:
		_clear_ability_preview()
		return
	_show_ability_preview(payload)

func _on_ability_preview_cleared() -> void:
	_clear_ability_preview()

func _show_ability_preview(payload) -> void:
	_stop_preview_cycle()
	if !_ensure_preview_infrastructure():
		return
	var grid_data = GDM.grid if typeof(GDM) != TYPE_NIL and GDM and GDM.grid else null
	if grid_data == null:
		_clear_preview_nodes()
		return
	if typeof(payload) == TYPE_DICTIONARY:
		var mode = str(payload.get("mode", "static"))
		match mode:
			"random_sample":
				_prepare_random_preview(payload, grid_data)
				return
			"sinker_sequence":
				_prepare_sinker_preview(payload, grid_data)
				return
			_:
				var tiles = payload.get("tiles", [])
				_render_preview_tiles(tiles, grid_data)
				return
	if typeof(payload) == TYPE_ARRAY:
		_render_preview_tiles(payload, grid_data)
		return
	_render_preview_tiles([], grid_data)

func _prepare_random_preview(payload: Dictionary, grid_data) -> void:
	var raw_pool: Array = payload.get("pool", [])
	var pool: Array = []
	var seen := {}
	for entry in raw_pool:
		var pos := _normalize_preview_position(entry)
		if !_is_preview_position_valid(pos, grid_data.width, grid_data.height):
			continue
		var key = "%d_%d" % [pos.x, pos.y]
		if seen.has(key):
			continue
		seen[key] = true
		pool.append(pos)
	preview_cycle_data.clear()
	if pool.is_empty():
		_clear_preview_nodes()
		return
	preview_cycle_data["mode"] = "random"
	preview_cycle_data["pool"] = pool
	preview_cycle_data["sample_size"] = int(payload.get("sample_size", pool.size()))
	preview_cycle_data["interval"] = float(payload.get("interval", 0.35))
	preview_cycle_data["grid"] = grid_data
	_refresh_cycle_preview()

func _prepare_sinker_preview(payload: Dictionary, grid_data) -> void:
	preview_cycle_data.clear()
	var ability = payload.get("ability", null)
	preview_cycle_data["mode"] = "sinker"
	preview_cycle_data["ability"] = ability
	preview_cycle_data["grid"] = grid_data
	preview_cycle_data["sequence_type"] = str(payload.get("sequence_type", "blastwave"))
	preview_cycle_data["step_delay"] = float(payload.get("step_delay", 0.08))
	preview_cycle_data["step_hold"] = float(payload.get("step_hold", 0.12))
	preview_cycle_data["explosion_hold"] = float(payload.get("explosion_hold", 0.4))
	preview_cycle_data["cycle_interval"] = float(payload.get("interval", 0.75))
	preview_cycle_data["levels"] = int(payload.get("levels", 3))
	preview_cycle_data["sample_size"] = int(payload.get("sample_size", 7))
	var spawn_columns = _get_sinker_spawn_columns()
	if spawn_columns.is_empty():
		for col in GDM.grid.width:
			spawn_columns.append(col)
	preview_cycle_data["spawn_columns"] = spawn_columns
	_refresh_cycle_preview()

func _refresh_sinker_cycle() -> void:
	var grid_data = preview_cycle_data.get("grid")
	var spawn_columns: Array = preview_cycle_data.get("spawn_columns", [])
	if grid_data == null or spawn_columns.is_empty():
		_clear_preview_nodes()
		return
	var column = spawn_columns[randi() % spawn_columns.size()]
	var step_delay = float(preview_cycle_data.get("step_delay", 0.08))
	var step_hold = float(preview_cycle_data.get("step_hold", 0.12))
	var explosion_hold = float(preview_cycle_data.get("explosion_hold", 0.4))
	var sequence_type = str(preview_cycle_data.get("sequence_type", "blastwave"))
	var top_row = grid_data.height - 1
	var path_positions: Array = []
	for row in range(top_row, -1, -1):
		path_positions.append(Vector2i(column, row))
	_clear_preview_nodes()
	var total_time := 0.0
	for i in range(path_positions.size()):
		var pos: Vector2i = path_positions[i]
		var overlay = _make_preview_overlay(pos, grid_data)
		overlay.modulate.a = 0.0
		var tween = create_tween()
		var start_time = float(i) * step_delay
		total_time = max(total_time, start_time + step_hold + 0.1)
		tween.tween_interval(start_time)
		tween.tween_property(overlay, "modulate:a", 0.6, step_hold)
		tween.chain().tween_property(overlay, "modulate:a", 0.0, 0.1)
		tween.chain().tween_callback(overlay.queue_free)
	var explosion_start = float(path_positions.size()) * step_delay
	match sequence_type:
		"stormsurge":
			if grid_data.height > 0 and grid_data.width > 0:
				var target_row = randi() % grid_data.height
				var row_tiles = _get_row_tiles(target_row, grid_data.width)
				for tile in row_tiles:
					var overlay = _make_preview_overlay(tile, grid_data)
					overlay.modulate.a = 0.0
					var tween = create_tween()
					tween.tween_interval(explosion_start)
					tween.tween_property(overlay, "modulate:a", 0.7, explosion_hold)
					tween.chain().tween_property(overlay, "modulate:a", 0.0, 0.12)
					tween.chain().tween_callback(overlay.queue_free)
					total_time = max(total_time, explosion_start + explosion_hold + 0.12)
		"coralburst":
			if grid_data.height > 0 and grid_data.width > 0:
				var v_tiles = _get_coralburst_tiles(column, grid_data.width, grid_data.height)
				for tile in v_tiles:
					var overlay = _make_preview_overlay(tile, grid_data)
					overlay.modulate.a = 0.0
					var tween = create_tween()
					tween.tween_interval(explosion_start)
					tween.tween_property(overlay, "modulate:a", 0.8, explosion_hold)
					tween.chain().tween_property(overlay, "modulate:a", 0.0, 0.14)
					tween.chain().tween_callback(overlay.queue_free)
					total_time = max(total_time, explosion_start + explosion_hold + 0.14)
		"jadestrike":
			var sample_size = int(preview_cycle_data.get("sample_size", 7))
			var random_tiles = _get_jadestrike_tiles(sample_size)
			for tile in random_tiles:
				var overlay = _make_preview_overlay(tile, grid_data)
				overlay.modulate.a = 0.0
				var tween = create_tween()
				tween.tween_interval(explosion_start)
				tween.tween_property(overlay, "modulate:a", 0.75, explosion_hold)
				tween.chain().tween_property(overlay, "modulate:a", 0.0, 0.12)
				tween.chain().tween_callback(overlay.queue_free)
				total_time = max(total_time, explosion_start + explosion_hold + 0.12)
		"ragebomb":
			if grid_data.height > 0:
				var column_tiles = _get_column_tiles(column, grid_data.height)
				for tile in column_tiles:
					var overlay = _make_preview_overlay(tile, grid_data)
					overlay.modulate.a = 0.0
					var tween = create_tween()
					tween.tween_interval(explosion_start)
					tween.tween_property(overlay, "modulate:a", 0.8, explosion_hold)
					tween.chain().tween_property(overlay, "modulate:a", 0.0, 0.12)
					tween.chain().tween_callback(overlay.queue_free)
					total_time = max(total_time, explosion_start + explosion_hold + 0.12)
		_:
			var explosion_tiles = _get_blastwave_explosion_tiles(column, int(preview_cycle_data.get("levels", 3)))
			for tile in explosion_tiles:
				var overlay = _make_preview_overlay(tile, grid_data)
				overlay.modulate.a = 0.0
				var tween = create_tween()
				tween.tween_interval(explosion_start)
				tween.tween_property(overlay, "modulate:a", 0.85, explosion_hold)
				tween.chain().tween_property(overlay, "modulate:a", 0.0, 0.12)
				tween.chain().tween_callback(overlay.queue_free)
				total_time = max(total_time, explosion_start + explosion_hold + 0.12)
	if preview_cycle_timer:
		var interval_buffer = float(preview_cycle_data.get("cycle_interval", 0.75))
		var wait_time = max(total_time, interval_buffer)
		preview_cycle_timer.stop()
		preview_cycle_timer.wait_time = wait_time
		preview_cycle_timer.start()

func _refresh_cycle_preview() -> void:
	if preview_cycle_data.is_empty():
		return
	var mode = str(preview_cycle_data.get("mode", "random"))
	match mode:
		"random":
			_refresh_random_cycle()
		"sinker":
			_refresh_sinker_cycle()
		_:
			return

func _refresh_random_cycle() -> void:
	var pool: Array = preview_cycle_data.get("pool", [])
	var grid_data = preview_cycle_data.get("grid")
	if pool.is_empty() or grid_data == null:
		_clear_preview_nodes()
		return
	var sample_size: int = preview_cycle_data.get("sample_size", pool.size())
	var effective_size = clamp(sample_size, 1, pool.size())
	var sample: Array = []
	if effective_size >= pool.size():
		sample = pool.duplicate()
	else:
		var available: Array = pool.duplicate()
		for i in range(effective_size):
			if available.is_empty():
				break
			var index = randi_range(0, available.size() - 1)
			sample.append(available[index])
			available.remove_at(index)
	_render_preview_tiles(sample, grid_data)
	if preview_cycle_timer:
		var wait_time = preview_cycle_data.get("interval", 0.35)
		wait_time = max(float(wait_time), 0.1)
		preview_cycle_timer.stop()
		preview_cycle_timer.wait_time = wait_time
		preview_cycle_timer.start()

func _render_preview_tiles(tiles: Array, grid_data) -> void:
	_clear_preview_nodes()
	if tiles.is_empty():
		return
	var seen := {}
	for tile in tiles:
		var grid_pos := _normalize_preview_position(tile)
		if !_is_preview_position_valid(grid_pos, grid_data.width, grid_data.height):
			continue
		var key = "%d_%d" % [grid_pos.x, grid_pos.y]
		if seen.has(key):
			continue
		seen[key] = true
		_make_preview_overlay(grid_pos, grid_data)

func _make_preview_overlay(grid_pos: Vector2i, grid_data) -> ColorRect:
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.45)
	overlay.size = Vector2(grid_data.offset, grid_data.offset)
	overlay.position = grid_data.grid_to_pixel(grid_pos.x, grid_pos.y) - Vector2(grid_data.offset / 2.0, grid_data.offset / 2.0)
	overlay.z_index = 6
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_container.add_child(overlay)
	return overlay

func _get_sinker_spawn_columns() -> Array:
	var columns: Array = []
	if GDM.grid == null:
		return columns
	var top_row = GDM.grid.height - 1
	for col in GDM.grid.width:
		var pos = Vector2(col, top_row)
		if is_piece_null(col, top_row) and !obstacle_manager.restricted_fill(pos):
			columns.append(col)
	return columns

func _get_blastwave_explosion_tiles(center_column: int, levels: int) -> Array:
	var tiles: Array = []
	if GDM.grid == null:
		return tiles
	var clamped_levels = max(levels, 1)
	for col in range(center_column - 1, center_column + 2):
		if col < 0 or col >= GDM.grid.width:
			continue
		for level in clamped_levels:
			if level >= GDM.grid.height:
				break
			tiles.append(Vector2i(col, level))
	return tiles

func _get_row_tiles(row: int, width: int) -> Array:
	var tiles: Array = []
	if row < 0:
		return tiles
	for col in range(0, width):
		tiles.append(Vector2i(col, row))
	return tiles

func _get_coralburst_tiles(center_column: int, width: int, height: int) -> Array:
	var tiles: Array = []
	if width <= 0 or height <= 0:
		return tiles
	for level in range(height):
		var row = level
		if row >= height:
			break
		var left_col = center_column - level
		var right_col = center_column + level
		if left_col == center_column and right_col == center_column and !_is_preview_position_valid(Vector2i(center_column, row), width, height):
			continue
		if level == 0 and _is_preview_position_valid(Vector2i(center_column, row), width, height):
			tiles.append(Vector2i(center_column, row))
		if left_col != center_column and _is_preview_position_valid(Vector2i(left_col, row), width, height):
			tiles.append(Vector2i(left_col, row))
		if right_col != center_column and right_col != left_col and _is_preview_position_valid(Vector2i(right_col, row), width, height):
			tiles.append(Vector2i(right_col, row))
	return tiles

func _get_jadestrike_tiles(sample_size: int) -> Array:
	var tiles: Array = []
	if !GDM or !GDM.grid:
		return tiles
	var pool: Array = []
	for col in GDM.grid.width:
		for row in GDM.grid.height:
			if !_is_preview_position_valid(Vector2i(col, row), GDM.grid.width, GDM.grid.height):
				continue
			if is_piece_null(col, row):
				continue
			if is_piece_sinker(col, row):
				continue
			pool.append(Vector2i(col, row))
	if pool.is_empty():
		return tiles
	var count = clamp(sample_size, 1, pool.size())
	var available: Array = pool.duplicate()
	for i in count:
		if available.is_empty():
			break
		var idx = randi_range(0, available.size() - 1)
		tiles.append(available[idx])
		available.remove_at(idx)
	return tiles

func _get_column_tiles(column: int, height: int) -> Array:
	var tiles: Array = []
	if height <= 0:
		return tiles
	for row in range(0, height):
		if _is_preview_position_valid(Vector2i(column, row), GDM.grid.width, height):
			tiles.append(Vector2i(column, row))
	return tiles

func _clear_ability_preview() -> void:
	_stop_preview_cycle()
	_clear_preview_nodes()

func _clear_preview_nodes() -> void:
	if preview_container == null:
		return
	for child in preview_container.get_children():
		if child:
			child.queue_free()

func _stop_preview_cycle() -> void:
	if preview_cycle_timer and !preview_cycle_timer.is_stopped():
		preview_cycle_timer.stop()
	preview_cycle_data.clear()

func _ensure_preview_infrastructure() -> bool:
	if preview_container == null:
		preview_container = Node2D.new()
		preview_container.name = "AbilityPreviewLayer"
		preview_container.z_index = 5
		add_child(preview_container)
	if preview_cycle_timer == null:
		preview_cycle_timer = Timer.new()
		preview_cycle_timer.one_shot = true
		preview_cycle_timer.autostart = false
		preview_cycle_timer.name = "AbilityPreviewCycleTimer"
		add_child(preview_cycle_timer)
		preview_cycle_timer.timeout.connect(_on_preview_cycle_timer_timeout)
	return true

func _on_preview_cycle_timer_timeout() -> void:
	_refresh_cycle_preview()

func _normalize_preview_position(value) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(int(round(value.x)), int(round(value.y)))
	return Vector2i(-1, -1)

func _is_preview_position_valid(pos: Vector2i, width: int, height: int) -> bool:
	if pos.x < 0 or pos.y < 0:
		return false
	if pos.x >= width or pos.y >= height:
		return false
	return true

func process_bombed_piece(col: int, row: int, piece, processed_pieces: Dictionary) -> void:
	var key = str(col) + "_" + str(row)
	if processed_pieces.has(key):
		return
	processed_pieces[key] = true
	if piece.is_color_bomb:
		bomb_chain_count += 1
		match_color(piece.color)
		color_bomb_used = true
		piece.matched = true
		plumb_damage()
	elif piece.is_adjacent_bomb:
		bomb_chain_count += 1
		create_bomb_pulse_effect(Vector2(col, row), BombTypes.ADJACENT)
		match_all_adjacent(col, row)
		piece.matched = true
		plumb_damage()
	elif piece.is_col_bomb:
		bomb_chain_count += 1
		create_bomb_pulse_effect(Vector2(col, row), BombTypes.COLUMN)
		match_all_in_col(col)
		piece.matched = true
		plumb_damage()
	elif piece.is_row_bomb:
		bomb_chain_count += 1
		create_bomb_pulse_effect(Vector2(col, row), BombTypes.ROW)
		match_all_in_row(row)
		piece.matched = true
		plumb_damage()

func plumb_damage() -> void:
	emit_signal("do_damage")
	camera_zoom_effect()

func is_piece_null(i: int , j: int) -> bool:
	return FW_GridUtils.is_piece_null(main_array, i, j)

func match_and_dim(item) -> void:
	if item:
		item.matched = true
		item.dim()

# Takes a single, coherent group of matched pieces and checks if a bomb should be made.
func process_match_group_for_bombs(match_group: Array) -> void:
	if match_group.is_empty():
		return

	# All pieces in a group have the same color, so we can just check the first one.
	var color = main_array[match_group[0].x][match_group[0].y].color
	if color == "sinker":
		return

	var longest_col = FW_GridUtils.get_longest_sequence_length(match_group, "rows")
	var longest_row = FW_GridUtils.get_longest_sequence_length(match_group, "cols")

	if longest_col >= 5 or longest_row >= 5:
		make_bomb(BombTypes.COLOR, color, match_group)
	elif FW_GridUtils.has_intersection(match_group):
		make_bomb(BombTypes.ADJACENT, color, match_group)
	elif longest_col >= 4:
		make_bomb(BombTypes.COLUMN, color, match_group)
	elif longest_row >= 4:
		make_bomb(BombTypes.ROW, color, match_group)

func make_bomb(bomb_type: int, color: String, match: Array) -> void:
	var bomb_created = false
	var bomb_pos = Vector2(-1, -1)

	# Add extra mana for creating a bomb
	if colors_dict.has(color):
		colors_dict[color] += 1

	# --- NEW: Prioritize Intersection for L/T shapes ---
	if bomb_type == BombTypes.ADJACENT:
		var intersection = FW_GridUtils.get_intersection_point(match)
		if intersection != Vector2(-1, -1):
			bomb_pos = intersection
			bomb_created = true

	# --- Player-Initiated Move Logic ---
	# Check if the player's move is part of this specific match group.
	if !bomb_created and player_moves.valid():
		# The position of the piece the player touched and moved.
		var moved_from_pos = player_moves.previous_location
		# The position it was moved to.
		var moved_to_pos = player_moves.previous_location + player_moves.previous_direction

		# Check if the destination of the player's swap is in the match.
		# This is the most intuitive place for the bomb.
		if match.has(moved_to_pos):
			bomb_pos = moved_to_pos
			bomb_created = true
		# Otherwise, check if the piece that was swapped out is in the match.
		# This covers cases like L-shapes where the bomb could logically be in either swapped piece's position.
		elif match.has(moved_from_pos):
			bomb_pos = moved_from_pos
			bomb_created = true

	# --- Cascading Match Logic ---
	# If the bomb wasn't created by a direct player action, find the middle of the cascade.
	if not bomb_created and match.size() > 0:
		# To find a stable middle, we sort the coordinates.
		var sorted_match = match.duplicate() # Avoid modifying the original array.

		# We need to determine if the match is primarily horizontal or vertical to sort correctly.
		var is_horizontal = false
		if sorted_match.size() > 1:
			var first_pos = sorted_match[0]
			var second_pos = sorted_match[1]
			if first_pos.y == second_pos.y:
				is_horizontal = true

		if is_horizontal:
			sorted_match.sort_custom(func(a, b): return a.x < b.x)
		else:
			sorted_match.sort_custom(func(a, b): return a.y < b.y)
		@warning_ignore("integer_division")
		var middle_index = floor(sorted_match.size() / 2)
		bomb_pos = sorted_match[middle_index]

		# --- Verification Step ---
		# The calculated middle might not be part of the actual match if it was
		# destroyed in a separate, smaller match in the same cascade.
		# e.g., a 3-match of red clears a tile where a 4-match of blue just formed.
		if not match.has(bomb_pos):
			# Fallback to the first piece in the sorted list, which is guaranteed to be valid.
			bomb_pos = sorted_match[0]

	# --- Create the Bomb at the determined position ---
	if bomb_pos != Vector2(-1, -1):
		var piece_to_bomb = main_array[bomb_pos.x][bomb_pos.y]
		if piece_to_bomb: # Ensure the piece still exists.
			damage_special(bomb_pos.x, bomb_pos.y)
			piece_to_bomb.matched = false # Un-match it so it doesn't get destroyed.
			turn_into_bomb(bomb_type, piece_to_bomb)
		else:
			# This can happen if the target piece was part of another match that
			# also created a bomb in the same step (e.g., L-shapes).
			# We'll iterate through the match to find the first available piece.
			var found_fallback = false
			for fallback_pos in match:
				var fallback_piece = main_array[fallback_pos.x][fallback_pos.y]
				if fallback_piece:
					damage_special(fallback_pos.x, fallback_pos.y)
					fallback_piece.matched = false
					turn_into_bomb(bomb_type, fallback_piece)
					found_fallback = true
					break # Exit the loop once we've made a bomb
			if not found_fallback:
				pass

func turn_into_bomb(bomb_type: int, piece: Object) -> void:
	if bomb_type == BombTypes.ADJACENT:
		piece.make_adjacent_bomb()
	elif bomb_type == BombTypes.COLUMN:
		piece.make_col_bomb()
	elif bomb_type == BombTypes.ROW:
		piece.make_row_bomb()
	elif bomb_type == BombTypes.COLOR:
		piece.make_color_bomb()

func destroy_matched() -> void:
	var move_involved_color_bomb = false
	if player_moves.valid():
		if player_moves.selected_tiles[0].is_color_bomb or player_moves.selected_tiles[1].is_color_bomb:
			move_involved_color_bomb = true

	var match_fx_tiles: Array[Dictionary] = []

	if color_bomb_used or move_involved_color_bomb:
		color_bomb_used = false
	else:
		# This is the new, correct logic
		# 1. Group all matched coordinates by color
		var matches_by_color = {}
		for pos in current_matches:
			if is_piece_null(pos.x, pos.y): continue # Piece might have been turned into a bomb already
			var color = main_array[pos.x][pos.y].color
			if not matches_by_color.has(color):
				matches_by_color[color] = []
			matches_by_color[color].append(pos)

		# 2. Process each color group separately
		for color in matches_by_color:
			var color_matches = matches_by_color[color]
			# 3. Find contiguous groups within this color
			var match_groups = FW_GridUtils.group_contiguous_matches(color_matches)
			for group in match_groups:
				# 4. Process each contiguous group for bombs
				process_match_group_for_bombs(group)

	var was_matched = current_matches.size() > 0
	var unique_matches = []
	var seen_coords = {}
	for pos in current_matches:
		if not seen_coords.has(pos):
			unique_matches.append(pos)
			seen_coords[pos] = true

	for pos in unique_matches:
		var i = int(pos.x)
		var j = int(pos.y)
		if !is_piece_null(i, j) and main_array[i][j].matched:
			var piece = main_array[i][j]
			if GDM.is_vs_mode():
				var lower_color := String(piece.color).to_lower()
				if colors_dict.has(lower_color):
					match_fx_tiles.append({
						"color": lower_color,
						"world_position": piece.global_position,
						"grid_position": Vector2(i, j)
					})
			if piece.color == "sinker":
				current_sinkers -= 1
			if piece.is_color_bomb or piece.is_adjacent_bomb or piece.is_col_bomb or piece.is_row_bomb:
				bomb_triggered = true
			emit_signal("check_goal", piece.color)
			damage_special(i,j)
			if GDM.is_vs_mode():
				tally_colors(main_array[i][j].color)
			main_array[i][j].queue_free()
			main_array[i][j] = null
			make_effect(particle_effect, i, j)
			make_effect(animated_explosion, i, j)
			emit_signal("update_score", streak)
			if bomb_triggered:
				emit_signal("play_bomb_sound", streak)
			else:
				emit_signal("play_sound", streak)
			bomb_triggered = false

	move_checked = true #global
	if was_matched:
		hint_system.destroy_hint()
		if GDM.is_vs_mode():
			if match_fx_tiles.size() > 0:
				var totals := colors_dict.duplicate()
				FW_Debug.debug_log(["FX", "emit", match_fx_tiles.size(), "tiles", totals])
				EventBus.mana_match_fx_requested.emit(match_fx_tiles, totals, game_manager.turn_manager.is_player_turn())
			emit_signal("update_mana", colors_dict)
			zero_color_dict()
		$collapse_timer.start()
		player_moves.clear_move_info() # trying this out here
	else:
		swap_back()
	current_matches.clear()
	unmatch_all_surviving_pieces()
	if bomb_chain_count > 2:
		if game_manager.turn_manager.is_player_turn() or !GDM.is_vs_mode():
			EventBus.combat_notification.emit(FW_CombatNotification.message_type.BOMB_CHAIN)
	bomb_chain_count = 0

func unmatch_all_surviving_pieces() -> void:
	"""
	Iterates through the entire board and resets the .matched flag on any
	piece that is still on the board. This prevents a lingering `true` state
	from causing invalid matches in subsequent cascades.
	"""
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if !is_piece_null(i, j) and main_array[i][j].matched:
				main_array[i][j].matched = false
				# Optional: If you have a visual "dim" effect, undim it here.
				# main_array[i][j].un_dim()

func zero_color_dict() -> void:
	FW_GridUtils.zero_color_dict(colors_dict)

func tally_colors(color: String) -> void:
	FW_GridUtils.tally_colors(colors_dict, color)

func make_effect(effect: Object, col, row) -> void:
	var current = effect.instantiate()
	current.position = GDM.grid.grid_to_pixel(col, row)
	add_child(current)

func damage_special(col, row) -> void:
	obstacle_manager.damage_obstacles_adjacent_to(Vector2(col, row))

func clear_board() -> void:
	var clearable_positions = FW_GridUtils.get_clearable_positions(main_array, GDM.grid.width, GDM.grid.height)
	for pos in clearable_positions:
		match_and_dim(main_array[pos.x][pos.y])
		FW_GridUtils.add_to_array(pos, current_matches)

func mana_surge() -> void:
	"""Triggered when board is deadlocked in VS mode. Clears board and awards mana."""
	# Mark board as unstable
	if game_manager and game_manager.turn_manager:
		game_manager.turn_manager.set_board_stable(false)

	can_move = false
	emit_signal("change_move_state", can_move)

	# Tally all clearable pieces on the board before clearing
	var clearable_positions = FW_GridUtils.get_clearable_positions(main_array, GDM.grid.width, GDM.grid.height)
	for pos in clearable_positions:
		if !is_piece_null(pos.x, pos.y):
			var piece = main_array[pos.x][pos.y]
			if piece.color != "sinker":  # Don't count sinkers for mana
				tally_colors(piece.color)

	# Get current turn owner for combat log
	var actor_name := ""
	if game_manager.turn_manager.is_player_turn():
		actor_name = GDM.player.character.name if GDM.player.character else "Player"
	else:
		actor_name = GDM.monster_to_fight.name if GDM.monster_to_fight else "Monster"

	# Emit combat notification first for dramatic effect
	EventBus.combat_notification.emit(FW_CombatNotification.message_type.MANA_SURGE)

	# Emit combat log message
	var log_message := "%s channels the deadlock into pure mana!" % actor_name
	EventBus.publish_combat_log.emit(log_message)

	# Award mana to current turn owner
	if colors_dict.values().any(func(v): return v > 0):
		emit_signal("update_mana", colors_dict)
		zero_color_dict()

	# Camera effect for impact
	camera_zoom_effect()

	# Mark all clearable pieces for destruction using existing system
	for pos in clearable_positions:
		if !is_piece_null(pos.x, pos.y):
			match_and_dim(main_array[pos.x][pos.y])
			FW_GridUtils.add_to_array(pos, current_matches)

	# Trigger the destruction sequence which will handle refill
	$destroy_timer.start()

func _perform_collapse() -> void:
	for i in GDM.grid.width:
		var write_pos = 0
		for read_pos in range(GDM.grid.height):
			# Skip over any spots that permanently block pieces
			while write_pos < GDM.grid.height and obstacle_manager.restricted_fill(Vector2(i, write_pos)):
				write_pos += 1

			if write_pos >= GDM.grid.height:
				break # No more valid places to write in this column

			var piece = main_array[i][read_pos]
			if piece != null:
				# If we're reading from a different spot than we're writing to, move the piece
				if read_pos != write_pos:
					main_array[i][read_pos] = null
					main_array[i][write_pos] = piece
					piece.move(GDM.grid.grid_to_pixel(i, write_pos))
				write_pos += 1

func collapse_columns() -> void:
	var sinkers_matched = true
	while sinkers_matched:
		_perform_collapse()
		sinkers_matched = find_and_match_sinkers_at_bottom()

	if current_matches.size() > 0:
		$destroy_timer.start()
	else:
		$refill_timer.start()

func _on_destroy_timer_timeout() -> void:
	destroy_matched()

func _on_collapse_timer_timeout() -> void:
	collapse_columns()

func refill_columns() -> void:
	if not refillable:
		return
	# spawn more sinkers if they were removed
	if current_sinkers < max_sinkers:
		spawn_sinkers(max_sinkers - current_sinkers)
	streak += 1
	if streak > 3:
		if game_manager.turn_manager.is_player_turn() or !GDM.is_vs_mode():
			EventBus.combat_notification.emit(FW_CombatNotification.message_type.COMBO)
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if main_array[i][j] == null && !obstacle_manager.restricted_fill(Vector2(i,j)):
				# pick a random number and store it
				var random_number = floor(randf_range(0, possible_pieces.size()))
				var loops = 0
				var piece = load(possible_pieces[random_number]).instantiate()
				while(FW_GridUtils.match_at(main_array, i, j, piece.color, GDM.grid.width, GDM.grid.height) && loops < 100):
					random_number = floor(randf_range(0, possible_pieces.size()))
					loops +=1
					piece = load(possible_pieces[random_number]).instantiate()
				add_child(piece)
				piece.position = GDM.grid.grid_to_pixel(i,j - GDM.grid.y_offset)
				piece.move(GDM.grid.grid_to_pixel(i,j))
				main_array[i][j] = piece
	# previously after_refill
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if !is_piece_null(i, j):
				var piece = main_array[i][j]
				if FW_GridUtils.match_at(main_array, i, j, piece.color, GDM.grid.width, GDM.grid.height) or piece.matched:
					find_matches()
					$destroy_timer.start()
					return
	if !obstacle_manager.damaged_slime:
		obstacle_manager.generate_slime()
	if !obstacle_manager.damaged_pink_slime:
		obstacle_manager.generate_pink_slime()

	move_checked = false
	obstacle_manager.damaged_slime = false
	obstacle_manager.damaged_pink_slime = false
	color_bomb_used = false
	if is_deadlocked():
		shuffle_board()
		$shuffle_timer.start()
	can_move = true
	streak = 1
	emit_signal("change_move_state", can_move)
	# have to find out why we don't get here sometimes, i assume it's cause of the return above
	emit_signal("update_counter", streak)
	end_turn_shenans()
	if !GDM.is_vs_mode() or game_manager.turn_manager.is_player_turn():
		$hint_timer.start()

func end_turn_shenans() -> void:
	# Should be around here to do the enemy turn order
	if GDM.is_vs_mode():
		if game_manager.turn_manager.is_player_turn():
			emit_signal("end_player_turn")
		else:
			emit_signal("end_monster_turn")

# Thread-based AI calculation
# Thread variable should be at the top with other vars
func _start_enemy_ai_thread() -> void:
	# If a thread is already running, don't start a new one.
	if _enemy_ai_thread and _enemy_ai_thread.is_alive():
		return

	# If a thread object exists, it means it has finished.
	# We must call wait_to_finish() to properly dispose of it.
	if _enemy_ai_thread:
		_enemy_ai_thread.wait_to_finish()

	# Reset the flag before starting
	ai_move_ready = false

	# Prepare a lightweight board state for the thread
	var board_state = []
	for i in GDM.grid.width:
		var row = []
		for j in GDM.grid.height:
			var piece = main_array[i][j]
			if piece == null:
				row.append(null)
			else:
				var bomb_type = ""
				if piece.is_color_bomb:
					bomb_type = ":color_bomb"
				elif piece.is_adjacent_bomb:
					bomb_type = ":adjacent_bomb"
				elif piece.is_row_bomb:
					bomb_type = ":row_bomb"
				elif piece.is_col_bomb:
					bomb_type = ":col_bomb"
				row.append(piece.color + bomb_type)
		board_state.append(row)
	# Also pass available moves
	var available_moves = find_all_monster_moves()
	self._pending_ai_data = {
		"board_state": board_state,
		"available_moves": available_moves,
		"affinity_colors": FW_MonsterAI.affinity_to_colors(GDM.monster_to_fight.affinities)
	}
	_enemy_ai_thread = Thread.new()
	_enemy_ai_thread.start(Callable(self, "_enemy_ai_thread_func"))
	$enemy_move_timer.start()

# This runs in a separate thread
func _enemy_ai_thread_func():
	var ai_data = self._pending_ai_data
	var board_state = ai_data["board_state"]
	var available_moves = ai_data["available_moves"]
	var move_result = {}
	if available_moves.size() == 0:
		move_result = {}
	else:
		# Call AI with board_state instead of grid Node
		move_result = GDM.monster_to_fight.ai.pick_move(available_moves, board_state, ai_data)
	# Thread-safe: schedule result on main thread
	call_deferred("_on_enemy_ai_thread_done", move_result)

# Called on main thread when thread finishes
func _on_enemy_ai_thread_done(move_result):
	pending_enemy_move = move_result
	ai_move_ready = true

func _on_enemy_move_timer_timeout() -> void:
	if not can_move or (game_manager and game_manager.turn_manager and not game_manager.turn_manager.can_perform_action()):
		var can_perform_str = "no_game_manager"
		if game_manager and game_manager.turn_manager:
			can_perform_str = str(game_manager.turn_manager.can_perform_action())
		FW_Debug.debug_log(["MONSTER MOVE: Cannot execute - can_move=" + str(can_move) + ", can_perform_action=" + can_perform_str])
		return

	# If the AI calculation is still running, wait for it to complete.
	# The 'finished' signal is emitted by the thread when its main function returns.
	if _enemy_ai_thread and _enemy_ai_thread.is_alive():
		FW_Debug.debug_log(["MONSTER MOVE: AI thread still running, waiting..."])
		await _enemy_ai_thread.finished

	# Now that we're sure the thread is done, and the timer has timed out,
	# we can safely execute the move.
	if ai_move_ready and pending_enemy_move.size() > 0:
		var move = pending_enemy_move
		var start_pos = Vector2(move.x, move.y)
		var end_pos = Vector2(move.x + move.direction.x, move.y + move.direction.y)

		FW_Debug.debug_log(["MONSTER MOVE: Attempting move from " + str(start_pos) + " to " + str(end_pos)])

		# VALIDATE MOVE BEFORE EXECUTION
		if _is_move_still_valid(start_pos, end_pos):
			FW_Debug.debug_log(["MONSTER MOVE: Move validated, executing"])
			create_selection_highlight_effect(start_pos)
			create_selection_highlight_effect(end_pos)

			var perform_monster_move := func():
				if can_move and game_manager and game_manager.turn_manager and game_manager.turn_manager.can_perform_action() and not (game_manager.turn_manager.game_won or game_manager.turn_manager.game_lost):
					swap_pieces(move.x, move.y, move.direction)
				else:
					FW_Debug.debug_log(["MONSTER MOVE: State changed during delay, aborting move"])
					emit_signal("end_monster_turn")

			if game_manager and game_manager.turn_manager:
				game_manager.turn_manager.request_monster_action(perform_monster_move)
			else:
				await get_tree().create_timer(0.7).timeout
				perform_monster_move.call()
		else:
			FW_Debug.debug_log(["MONSTER MOVE: Move no longer valid, attempting fallback"])
			# Move is no longer valid, try to find a new move or end turn
			_attempt_fallback_monster_move()
	else:
		FW_Debug.debug_log(["MONSTER MOVE: No move available from AI, checking for valid moves"])
		# This case handles if the AI found no moves or something went wrong.
		# We still need to end the monster's turn to continue the game.
		_attempt_fallback_monster_move()

func match_color(color: String) -> void:
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if !is_piece_null(i,j) and !is_piece_sinker(i, j):
				var matched_piece = main_array[i][j]
				if matched_piece.color == color and !matched_piece.matched: # Add check for already matched pieces
					match_and_dim(matched_piece)
					FW_GridUtils.add_to_array(Vector2(i, j), current_matches)

func match_all_in_col(col: int) -> void:
	for i in GDM.grid.height:
		if !is_piece_null(col, i) and !is_piece_sinker(col, i):
			var piece = main_array[col][i]
			match_and_dim(piece)
			FW_GridUtils.add_to_array(Vector2(col, i), current_matches)

func match_all_in_row(row: int) -> void:
	for i in GDM.grid.width:
		if !is_piece_null(i, row) and !is_piece_sinker(i, row):
			var piece = main_array[i][row]
			match_and_dim(piece)
			FW_GridUtils.add_to_array(Vector2(i, row), current_matches)

func match_all_adjacent(col: int, row: int) -> void:
	var piece = main_array[col][row]
	match_and_dim(piece)
	FW_GridUtils.add_to_array(Vector2(col, row), current_matches)
	var directions = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)
	]
	for dir in directions:
		var new_col = col + dir.x
		var new_row = row + dir.y
		if GDM.grid.is_in_grid(Vector2(new_col, new_row)):
			var neighbor = main_array[new_col][new_row]
			if neighbor != null and not is_piece_sinker(new_col, new_row):
				match_and_dim(neighbor)
				FW_GridUtils.add_to_array(Vector2(new_col, new_row), current_matches)

# destroy the sinkers and pop them at the top again
func find_and_match_sinkers_at_bottom() -> bool:
	var matched_one = false
	for i in GDM.grid.width:
		if !is_piece_null(i, 0) and is_piece_sinker(i, 0): # 0 bottom of the board
			var piece = main_array[i][0]
			if piece.color == "sinker" and not piece.matched:
				if GDM.is_vs_mode():
					EventBus.sinker_destroyed.emit(piece.sinker_owner, piece.sinker_type)

				# Apply sinker effects if available, otherwise use fallback damage
				if piece.sinker_type and piece.sinker_type.sinker_effects and not piece.sinker_type.sinker_effects.is_empty():
					_apply_sinker_effects(piece, Vector2(i, 0))
				else:
					# Fallback to basic damage for abilities without sinker_effects
					if GDM.is_vs_mode():
						_apply_fallback_sinker_damage(piece)

				match_and_dim(piece)
				FW_GridUtils.add_to_array(Vector2(i, 0), current_matches)
				matched_one = true
	return matched_one

func _apply_sinker_effects(piece: FW_Piece, grid_position: Vector2) -> void:
	"""Apply sinker effects using the EffectResource system"""
	var ability = piece.sinker_type
	var sinker_effects = ability.sinker_effects

	# Apply sinker effects using the EffectResource system for ability: %s
	# (Debug prints removed for normal gameplay)

	# Create an EffectResource instance from the sinker_effects data
	var effect = FW_EffectResource.new()
	effect.name = ability.name + " Sinker Effect"
	effect.effect_type = sinker_effects.get("type", "sinker_damage")
	effect.amount = sinker_effects.get("damage", 0)
	effect.effects = sinker_effects.duplicate()  # Pass all sinker effect parameters
	effect.texture = ability.texture
	effect.log_message = ability.log_message

	# For column clear effects, specify the column to clear
	if effect.effect_type == "sinker_column_clear":
		effect.effects["column"] = grid_position.x
		next_column_clear = int(grid_position.x)

	# Prepare context for effect execution
	var context = {
		"grid": self,
		"position": grid_position,
		"is_player_turn": piece.sinker_owner == FW_Piece.OWNER.PLAYER,
		"sinker_ability": ability,
		"sinker_owner": piece.sinker_owner
	}

	# Add column information for column-based effects
	# Add column information and canonical grid cell so the VFX manager
	# can perform a consistent, camera-aware projection for shader overlays.
	context["column_x"] = grid_position.x / float(GDM.grid.width)
	# Provide the precise grid cell (float) for manager-side projection
	context["grid_cell"] = Vector2(float(grid_position.x), float(grid_position.y))
	# Also provide the new PhaseWeb-style list of grid_cells (float coords)
	# so scene-based effects can accept multiple targets and keep a single
	# canonical entry for convenience. This mirrors how PhaseWeb passes
	# grid_cells and keeps backward compatibility with "grid_cell".
	context["grid_cells"] = [Vector2(float(grid_position.x), float(grid_position.y))]

	# Compute a normalized target_position (0..1) using this Grid's viewport
	# so shader-based overlays can receive an already-normalized position
	# instead of recalculating it. Keep this optional — managers still
	# accept raw grid_cell as a fallback.
	var _vp = get_viewport()
	if _vp:
		context["target_position"] = GDM.grid.grid_cell_to_normalized_target(int(grid_position.x), float(grid_position.y), _vp)

	# Execute the effect
	effect.execute(context)

	# Debug: log the context passed into FW_EffectResource.execute
	var dbg_ctx = {
		"ability": ability.name if ability else "<none>",
		"grid_position": grid_position,
		"sinker_effects": sinker_effects,
		"context_keys": context.keys()
	}
	if EventBus.has_signal("debug_log"):
		FW_Debug.debug_log(["APPLY_SINKER_EFFECTS: %s" % str(dbg_ctx)])
	else:
		FW_Debug.debug_log(["APPLY_SINKER_EFFECTS: %s" % str(dbg_ctx)])

	# Note: FW_EffectResource implementations now populate `grid_cells` directly.

	# Trigger visual effects for sinker reaching bottom (if supported)
	if ability.has_method("trigger_visual_effects"):
		# Debug: capture what ability will emit for visual effects
		var resolved = ability.resolve_visual_effect_for_phase("on_sinker_bottom") if ability.has_method("resolve_visual_effect_for_phase") else {"effect_name":"<unknown>", "params":{}}
		if EventBus.has_signal("debug_log"):
			FW_Debug.debug_log(["ABILITY_WILL_TRIGGER_VFX: ability=%s resolved=%s context_keys=%s" % [ability.name, str(resolved), str(context.keys())]])
		else:
			FW_Debug.debug_log(["ABILITY_WILL_TRIGGER_VFX: ability=%s resolved=%s context_keys=%s" % [ability.name, str(resolved), str(context.keys())]])
		ability.trigger_visual_effects("on_sinker_bottom", context)
	else:
		push_warning("Grid: sinker ability %s missing trigger_visual_effects method" % str(ability))

	# Handle logging (EffectResource populates last_log_message)
	if effect.last_log_message and effect.last_log_message.strip_edges() != "":
		EventBus.publish_combat_log.emit(effect.last_log_message)
		if effect.last_log_icon:
			EventBus.publish_combat_log_with_icon.emit(effect.last_log_message, effect.last_log_icon)

func _apply_fallback_sinker_damage(piece: FW_Piece) -> void:
	"""Apply basic damage for sinkers without specific effects (backward compatibility)"""
	var ability = piece.sinker_type
	var damage = 0

	# Try to get damage from various sources for backward compatibility
	if ability and ability.effects.has("sinker_damage"):
		damage = ability.effects["sinker_damage"]
	elif ability and ability.damage > 0:
		damage = ability.damage
	else:
		damage = 50  # Default fallback damage

	if damage > 0:
		var is_player_turn = game_manager.turn_manager.is_player_turn()
		CombatManager.apply_damage_with_checks(damage, "", is_player_turn, false, false, false)

		# Simple log message for fallback
		var attacker_name = GDM.player.character.name if is_player_turn else GDM.monster_to_fight.name
		var message = "{attacker}'s {ability} sinker explodes for {damage} damage!".format({
			"attacker": attacker_name,
			"ability": ability.name if ability else "unknown",
			"damage": damage
		})
		EventBus.publish_combat_log.emit(message)

func _on_refill_timer_timeout() -> void:
	refill_columns()

func load_obstacle_data() -> void:
	obstacle_manager.level_obstacle_data = load_obstacle_data_from_file(GDM.level)
	obstacle_manager.concrete_spaces = PackedVector2Array(obstacle_manager.level_obstacle_data["concrete"])
	if obstacle_manager.level_obstacle_data.has("heavy_concrete"):
		obstacle_manager.heavy_concrete_spaces = PackedVector2Array(obstacle_manager.level_obstacle_data["heavy_concrete"])
	obstacle_manager.ice_spaces = PackedVector2Array(obstacle_manager.level_obstacle_data["ice"])
	obstacle_manager.locked_spaces = PackedVector2Array(obstacle_manager.level_obstacle_data["locked"])
	obstacle_manager.slime_spaces = PackedVector2Array(obstacle_manager.level_obstacle_data["slime"])
	if obstacle_manager.level_obstacle_data.has("pink_slime"):
		obstacle_manager.pink_slime_spaces = PackedVector2Array(obstacle_manager.level_obstacle_data["pink_slime"])

func spawn_ice() -> void:
	for i in obstacle_manager.ice_spaces.size():
		emit_signal("make_ice", obstacle_manager.ice_spaces[i])

func spawn_locks() -> void:
	for i in obstacle_manager.locked_spaces.size():
		emit_signal("make_lock", obstacle_manager.locked_spaces[i])

func spawn_concrete() -> void:
	for i in obstacle_manager.concrete_spaces.size():
		emit_signal("make_concrete", obstacle_manager.concrete_spaces[i])
	for j in obstacle_manager.heavy_concrete_spaces.size():
		emit_signal("make_heavy_concrete", obstacle_manager.heavy_concrete_spaces[j])

func spawn_slime() -> void:
	for i in obstacle_manager.slime_spaces.size():
		emit_signal("make_slime", obstacle_manager.slime_spaces[i])
	for j in obstacle_manager.pink_slime_spaces.size():
		emit_signal("make_pink_slime", obstacle_manager.pink_slime_spaces[j])

# This really should be an attribute on a piece aka piece.destructible == false
func is_piece_sinker(col: int, row: int) -> bool:
	return FW_GridUtils.is_piece_sinker(main_array, col, row)

func spawn_sinkers(number_to_spawn: int, force_overwrite: bool = false, sinker_ability:FW_Ability = null) -> void:
	var top_row = GDM.grid.height - 1
	var valid_cols = []
	for col in GDM.grid.width:
		var pos = Vector2(col, top_row)
		if is_piece_null(col, top_row) and not obstacle_manager.restricted_fill(pos):
			valid_cols.append(col)
	if valid_cols.size() == 0 and force_overwrite: #this means we are in _vs mode
		# All top row slots are filled, so forcibly overwrite a random one
		var overwrite_cols = []
		for col in GDM.grid.width:
			var pos = Vector2(col, top_row)
			if not obstacle_manager.restricted_fill(pos):
				overwrite_cols.append(col)
		if overwrite_cols.size() == 0:
			printerr("No valid columns to overwrite for sinker.")
			return
		for i in number_to_spawn:
			if overwrite_cols.size() == 0:
				break
			var col = overwrite_cols.pick_random()
			overwrite_cols.erase(col)
			# Remove the existing piece
			if main_array[col][top_row]:
				main_array[col][top_row].queue_free()
			var current = sinker_piece.instantiate()
			# will need to make this conditional for the different type of sinkers
			# but for now to test this should be ok
			add_child(current)
			current.make_into_sinker(sinker_ability)
			current.position = GDM.grid.grid_to_pixel(col, top_row)
			main_array[col][top_row] = current
			current_sinkers += 1
			create_spawn_highlight_effect(Vector2(col, top_row))
			SoundManager._play_sinker_spawn_sound()
			if sinker_ability and sinker_ability.has_method("trigger_visual_effects"):
				var overwrite_ctx = _build_sinker_cast_vfx_context(col, top_row, current.position)
				sinker_ability.trigger_visual_effects("on_cast", overwrite_ctx)
		return
	elif valid_cols.size() == 0:
		printerr("No valid columns to spawn sinker.")
		return
	for i in number_to_spawn:
		if valid_cols.size() == 0:
			break
		var col = valid_cols.pick_random()
		valid_cols.erase(col)
		var current = sinker_piece.instantiate()
		add_child(current)
		current.position = GDM.grid.grid_to_pixel(col, top_row)
		main_array[col][top_row] = current
		current_sinkers += 1
		create_spawn_highlight_effect(Vector2(col, top_row))
		emit_signal("play_sinker_sound")
		if sinker_ability and sinker_ability.has_method("trigger_visual_effects"):
			var spawn_ctx = _build_sinker_cast_vfx_context(col, top_row, current.position)
			sinker_ability.trigger_visual_effects("on_cast", spawn_ctx)

func _build_sinker_cast_vfx_context(col: int, row: int, pixel_pos: Vector2) -> Dictionary:
	var context: Dictionary = {}
	context["grid_cell"] = Vector2(float(col), float(row))
	context["grid_cells"] = [context["grid_cell"]]
	if GDM and GDM.grid and GDM.grid.width > 0:
		context["column_x"] = float(col) / float(GDM.grid.width)
	context["pixel_position"] = pixel_pos
	var vp = get_viewport()
	if vp and GDM and GDM.grid:
		context["target_position"] = GDM.grid.grid_cell_to_normalized_target(col, float(row), vp)
	return context

func spawn_preset_pieces() -> void:
	if preset_spaces.size() > 0:
		for i in preset_spaces.size():
			var piece = load(possible_pieces[preset_spaces[i].z]).instantiate()
			add_child(piece)
			piece.position = GDM.grid.grid_to_pixel(preset_spaces[i].x, preset_spaces[i].y)
			main_array[preset_spaces[i].x][preset_spaces[i].y] = piece

func move_camera() -> void:
	@warning_ignore("integer_division")
	var camera_position = GDM.grid.grid_to_pixel(float(GDM.grid.width/2-0.5), float(GDM.grid.height/2-0.5))
	emit_signal("place_camera", camera_position)

func camera_zoom_effect() -> void:
	emit_signal("camera_effect")
	Input.vibrate_handheld(VIBRATION_DURATION * streak)

func find_all_monster_moves() -> Array:
	var monster_moves = []
	var directions = [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
	clone_array = copy_array(main_array)
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if clone_array[i][j] != null and !obstacle_manager.restricted_move(Vector2(i, j)):
				for dir in directions:
					var new_x = i + int(dir.x)
					var new_y = j + int(dir.y)
					if GDM.grid.is_in_grid(Vector2(new_x, new_y)) and !obstacle_manager.restricted_move(Vector2(new_x, new_y)):
						if hint_system.switch_and_check(Vector2(i, j), dir, clone_array):
							var potential_move: Dictionary = {}
							potential_move["x"] = i
							potential_move["y"] = j
							potential_move["direction"] = dir
							monster_moves.append(potential_move)
	return monster_moves

func change_booster_tile_colors():
	# this will need to be split into other functions when more effects are needed/different boosters added
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if !is_piece_null(i, j) and !is_piece_sinker(i, j):
				var piece = main_array[i][j]
				if piece.matched:
					match active_booster:
						"bite":
							piece.do_bitten()
						"claw":
							piece.do_clawed()
						"bork":
							piece.do_clawed() # Assuming bork has the same visual effect as claw
						"chew":
							piece.do_chewed()
						"dash":
							piece.do_dashed()
						"thrash", "slam":
							piece.do_thrashed()

# used while in the level editor
func level_edit_click() -> void:
		if Input.is_action_just_pressed("ui_touch"):
			var temp = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
			if GDM.grid.is_in_grid(temp):
				emit_signal("level_edit_input", true)
			else:
				emit_signal("level_edit_input", false)

func _on_ice_holder_break_ice(_value: String, location: Vector2) -> void:
	obstacle_manager.remove_ice(location)

func _on_lock_holder_remove_lock(_value: String, location: Vector2) -> void:
	obstacle_manager.remove_lock(location)

func _on_concrete_holder_remove_concrete(_value: String, location: Vector2) -> void:
	obstacle_manager.remove_concrete(location)

func _on_slime_holder_remove_slime(_value: String, location: Vector2) -> void:
	obstacle_manager.remove_slime(location)

func _on_heavy_concrete_holder_remove_heavy_concrete(_value: String, location: Vector2) -> void:
	obstacle_manager.remove_heavy_concrete(location)

func _on_pink_slime_holder_remove_pink_slime(_value: String, location: Vector2) -> void:
	obstacle_manager.remove_pink_slime(location)

func copy_array(array: Array) -> Array:
	var new_array = GDM.make_2d_array()
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			new_array[i][j] = array[i][j]
	return new_array

func is_deadlocked() -> bool:
	clone_array = copy_array(main_array)
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			# check each piece
			if hint_system.switch_and_check(Vector2(i, j), Vector2(1, 0), clone_array): # to the right
				return false
			if hint_system.switch_and_check(Vector2(i, j), Vector2(0, 1), clone_array): # up
				return false
	return true

func clear_and_store_board() -> Array:
	var holder = []
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if !is_piece_null(i, j):
				holder.append(main_array[i][j])
				main_array[i][j] = null
	return holder

func clear_all_pieces() -> void:
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if main_array[i][j] != null:
				main_array[i][j].queue_free()
				main_array[i][j] = null
	current_sinkers = 0 # Reset sinker count


func shuffle_board() -> void:
	# In VS mode, deadlocks trigger mana surge instead of shuffle
	if GDM.is_vs_mode():
		mana_surge()
		return

	# Normal mode: existing shuffle logic
	# Mark board as unstable before shuffling
	if game_manager and game_manager.turn_manager:
		game_manager.turn_manager.set_board_stable(false)

	var holder = clear_and_store_board()
	for i in GDM.grid.width:
		for j in GDM.grid.height:
			if !obstacle_manager.restricted_fill(Vector2(i,j)) and is_piece_null(i, j):
				#choose a random number and store it
				var rand = randi() % holder.size()
				var piece = holder[rand]
				var loops = 0
				while(FW_GridUtils.match_at(main_array, i, j, piece.color, GDM.grid.width, GDM.grid.height) && loops < 100):
					rand = randi() % holder.size()
					loops += 1
					piece = holder[rand]
				piece.move(GDM.grid.grid_to_pixel(i, j))
				main_array[i][j] = piece
				holder.remove_at(rand)
	if is_deadlocked():
		shuffle_board()
		return # Don't mark stable until all shuffles are done

	can_move = true
	emit_signal("change_move_state", can_move)

	# Mark board as stable after shuffling is complete
	if game_manager and game_manager.turn_manager:
		game_manager.turn_manager.set_board_stable(true)

func _on_shuffle_timer_timeout() -> void:
	shuffle_board()

func _on_hint_timer_timeout() -> void:
	if can_move:
		if GDM.is_vs_mode():
			if game_manager.turn_manager.is_player_turn():
				hint_system.generate_hint()
		else:
			hint_system.generate_hint()

func _on_game_manager_game_won(_you_win, _yay) -> void:
	can_move = false

func _on_game_manager_game_won_vs() -> void:
	can_move = false

func _on_game_manager_game_lost() -> void:
	can_move = false

func _on_game_manager_grid_change_move() -> void:
	can_move = !can_move

func refresh_obstacles() -> void:
	load_obstacle_data()
	spawn_concrete()

func load_obstacle_data_from_file(level: int) -> Dictionary:
	var path = "res://Levels/level" + str(level) + ".dat"
	var file = FileAccess.open(path, FileAccess.READ)
	if file != null:
		var data = file.get_var()
		if data:
			return data
		else:
			return obstacle_manager.level_obstacle_data
	else:
		return obstacle_manager.level_obstacle_data

func _is_move_still_valid(start_pos: Vector2, end_pos: Vector2) -> bool:
	"""Validate that a monster move is still valid with current board state"""
	# Check if positions are still in grid
	if not GDM.grid.is_in_grid(start_pos) or not GDM.grid.is_in_grid(end_pos):
		FW_Debug.debug_log(["MONSTER MOVE VALIDATION: Position out of grid - start=" + str(start_pos) + ", end=" + str(end_pos)])
		return false

	# Check if pieces still exist and are movable
	var start_x = int(start_pos.x)
	var start_y = int(start_pos.y)
	var end_x = int(end_pos.x)
	var end_y = int(end_pos.y)

	if is_piece_null(start_x, start_y) or is_piece_null(end_x, end_y):
		FW_Debug.debug_log(["MONSTER MOVE VALIDATION: FW_Piece missing - start=" + str(start_pos) + ", end=" + str(end_pos)])
		return false

	# Check if pieces are restricted
	if obstacle_manager.restricted_move(start_pos) or obstacle_manager.restricted_move(end_pos):
		FW_Debug.debug_log(["MONSTER MOVE VALIDATION: Move restricted - start=" + str(start_pos) + ", end=" + str(end_pos)])
		return false

	# Check if move would create a match (basic validation)
	var temp_array = copy_array(main_array)
	# Use the existing switch_pieces function but with array parameter
	var direction = Vector2(end_pos.x - start_pos.x, end_pos.y - start_pos.y)
	switch_pieces_for_validation(start_pos, direction, temp_array)
	var has_match = find_matches(true, temp_array)
	switch_pieces_for_validation(start_pos, direction, temp_array) # undo

	if not has_match:
		FW_Debug.debug_log(["MONSTER MOVE VALIDATION: Move would not create match - start=" + str(start_pos) + ", end=" + str(end_pos)])

	return has_match

func switch_pieces_for_validation(loc: Vector2, direction: Vector2, array: Array) -> void:
	"""Helper function to switch pieces in a temporary array for validation"""
	if GDM.grid.is_in_grid(loc) and !obstacle_manager.restricted_fill(loc):
		var new_loc = loc + direction
		if GDM.grid.is_in_grid(new_loc) and !obstacle_manager.restricted_fill(new_loc):
			var holder = array[new_loc.x][new_loc.y]
			array[new_loc.x][new_loc.y] = array[loc.x][loc.y]
			array[loc.x][loc.y] = holder

func _attempt_fallback_monster_move() -> void:
	"""Attempt to find and execute a valid monster move when AI move fails"""
	FW_Debug.debug_log(["MONSTER MOVE FALLBACK: Attempting to find valid moves"])

	# Quick check for any available moves with current board state
	var available_moves = find_all_monster_moves()

	if available_moves.size() > 0:
		FW_Debug.debug_log(["MONSTER MOVE FALLBACK: Found " + str(available_moves.size()) + " valid moves, picking random"])

		# Try to execute a random valid move immediately
		var fallback_move = available_moves[randi() % available_moves.size()]
		var start_pos = Vector2(fallback_move.x, fallback_move.y)
		var end_pos = Vector2(fallback_move.x + fallback_move.direction.x, fallback_move.y + fallback_move.direction.y)

		if _is_move_still_valid(start_pos, end_pos):
			FW_Debug.debug_log(["MONSTER MOVE FALLBACK: Executing fallback move"])
			create_selection_highlight_effect(start_pos)
			create_selection_highlight_effect(end_pos)

			var execute_fallback_move := func():
				if can_move and game_manager and game_manager.turn_manager and game_manager.turn_manager.can_perform_action() and not (game_manager.turn_manager.game_won or game_manager.turn_manager.game_lost):
					swap_pieces(fallback_move.x, fallback_move.y, fallback_move.direction)
				else:
					FW_Debug.debug_log(["MONSTER MOVE FALLBACK: State changed during fallback delay, ending turn"])
					emit_signal("end_monster_turn")

			if game_manager and game_manager.turn_manager:
				game_manager.turn_manager.request_monster_action(execute_fallback_move, FW_TurnManager.MONSTER_ACTION_DELAY * 0.5)
			else:
				await get_tree().create_timer(0.35).timeout
				execute_fallback_move.call()
		else:
			FW_Debug.debug_log(["MONSTER MOVE FALLBACK: Fallback move not valid, checking if board needs shuffle"])
			_check_and_handle_deadlock()
	else:
		FW_Debug.debug_log(["MONSTER MOVE FALLBACK: No valid moves found, checking if board needs shuffle"])
		_check_and_handle_deadlock()

func _check_and_handle_deadlock() -> void:
	"""Check if board is deadlocked and handle appropriately"""
	if is_deadlocked():
		FW_Debug.debug_log(["MONSTER MOVE DEADLOCK: Board is deadlocked, shuffling"])
		shuffle_board()
		# After shuffle, the board will be in refill state, so we don't end turn here
		# The refill process will eventually call end_turn_shenans()
	else:
		FW_Debug.debug_log(["MONSTER MOVE DEADLOCK: Board not deadlocked but no moves available, ending turn"])
		emit_signal("end_monster_turn")

# Refactored booster logic
func _booster_setup(ability: FW_Ability) -> void:
	refillable = false
	active_booster = ability.name.to_lower()
	hint_system.destroy_hint()
	$hint_timer.stop()
	_clear_ability_preview()

func _booster_teardown() -> void:
	hint_system.destroy_hint()
	if !GDM.is_vs_mode() or game_manager.turn_manager.is_player_turn():
		$hint_timer.start()
	active_booster = ""
	refillable = true
	if game_manager and game_manager.turn_manager and game_manager.turn_manager.is_player_turn():
		emit_signal("booster_inactive")
		if !(game_manager.turn_manager.game_won or game_manager.turn_manager.game_lost):
			refill_columns()

func _log_booster_cast(ability: FW_Ability) -> void:
	var attacker_name := "Monster"
	if game_manager and game_manager.turn_manager and game_manager.turn_manager.is_player_turn():
		if GDM.player and GDM.player.character:
			attacker_name = GDM.player.character.name
		else:
			attacker_name = "Player"
	else:
		if GDM.monster_to_fight and GDM.monster_to_fight.name:
			attacker_name = GDM.monster_to_fight.name

	var cast_message := ability.get_formatted_log_message({
		"attacker": attacker_name,
		"ability_name": ability.name
	})

	if cast_message and cast_message.strip_edges() != "":
		EventBus.publish_combat_log_with_icon.emit(cast_message, ability.texture)
	else:
		var fallback_message := "{attacker} casts {ability_name}!".format({
			"attacker": attacker_name,
			"ability_name": ability.name
		})
		EventBus.publish_combat_log_with_icon.emit(fallback_message, ability.texture)

func _handle_sinker_booster(ability: FW_Ability) -> void:
	_booster_setup(ability)
	_log_booster_cast(ability)

	spawn_sinkers(1, true, ability)

func apply_poison_slime(ability: FW_Ability, tile_count: int = 3) -> void:
	_apply_slime_conversion(
		ability,
		tile_count,
		Callable(self, "_convert_cell_to_slime"),
		"PoisonSlime"
	)

func apply_pink_slime(ability: FW_Ability, tile_count: int = 3) -> void:
	_apply_slime_conversion(
		ability,
		tile_count,
		Callable(self, "_convert_cell_to_pink_slime"),
		"PinkSlime"
	)

func _apply_slime_conversion(
	ability: FW_Ability,
	tile_count: int,
	converter: Callable,
	debug_tag: String
) -> void:
	if ability == null:
		return
	_booster_setup(ability)
	_log_booster_cast(ability)

	var normalized_tile_count: int = max(tile_count, 0)
	if normalized_tile_count == 0:
		return

	var candidates := _get_obstacle_candidates()
	if candidates.is_empty():
		FW_Debug.debug_log(["%s: no valid tiles for slime conversion" % debug_tag])
		return

	var selections: Array = []
	var target_count: int = min(normalized_tile_count, candidates.size())
	for _i in target_count:
		var choice = candidates.pick_random()
		candidates.erase(choice)
		selections.append(choice)
		if converter.is_valid():
			converter.call(choice)

	if selections.is_empty():
		return

	_emit_slime_visuals(ability, selections)

func _get_obstacle_candidates() -> Array:
	var positions: Array = []
	for col in GDM.grid.width:
		for row in GDM.grid.height:
			var pos := Vector2(col, row)
			if !_is_obstacle_target_available(pos):
				continue
			positions.append(pos)
	return positions

func _is_obstacle_target_available(pos: Vector2) -> bool:
	if !GDM.grid.is_in_grid(pos):
		return false
	var col := int(pos.x)
	var row := int(pos.y)
	if col < 0 or col >= main_array.size():
		return false
	if row < 0 or row >= main_array[col].size():
		return false
	if obstacle_manager.restricted_fill(pos):
		return false
	if is_piece_sinker(col, row):
		return false
	return true

func _convert_cell_to_slime(grid_position: Vector2) -> void:
	var col := int(grid_position.x)
	var row := int(grid_position.y)
	if col < 0 or col >= main_array.size():
		return
	if row < 0 or row >= main_array[col].size():
		return
	var piece = main_array[col][row]
	if piece:
		piece.queue_free()
	main_array[col][row] = null
	obstacle_manager.register_slime_tile(grid_position)
	create_spawn_highlight_effect(grid_position)
	emit_signal("make_slime", grid_position)

func _convert_cell_to_ice(grid_position: Vector2) -> void:
	var col := int(grid_position.x)
	var row := int(grid_position.y)
	if col < 0 or col >= main_array.size():
		return
	if row < 0 or row >= main_array[col].size():
		return
	var piece = main_array[col][row]
	if piece == null:
		return
	if _is_tile_ice(grid_position):
		return
	obstacle_manager.register_ice_tile(grid_position)
	create_spawn_highlight_effect(grid_position)
	emit_signal("make_ice", grid_position)

func _convert_cell_to_pink_slime(grid_position: Vector2) -> void:
	var col := int(grid_position.x)
	var row := int(grid_position.y)
	if col < 0 or col >= main_array.size():
		return
	if row < 0 or row >= main_array[col].size():
		return
	var piece = main_array[col][row]
	if piece:
		piece.queue_free()
	main_array[col][row] = null
	obstacle_manager.register_pink_slime_tile(grid_position)
	create_spawn_highlight_effect(grid_position)
	emit_signal("make_pink_slime", grid_position)

func _emit_slime_visuals(ability: FW_Ability, tiles: Array) -> void:
	if ability == null or tiles.is_empty():
		return
	var payload := {
		"grid_cells": tiles.duplicate()
	}
	payload["grid_cell"] = tiles[0]
	ability.trigger_visual_effects("on_cast", payload)

func apply_chains_lock(ability: FW_Ability, lock_count: int = 5) -> void:
	_booster_setup(ability)
	_log_booster_cast(ability)

	var normalized_count: int = max(lock_count, 0)
	if normalized_count == 0:
		return

	var color_pool := ["red", "blue", "green", "orange", "pink"]
	var lockable_by_color: Dictionary = {}
	var available_colors: Array = []
	for color in color_pool:
		var candidates := _get_lockable_tiles_by_color(color)
		if candidates.size() == 0:
			continue
		lockable_by_color[color] = candidates
		available_colors.append(color)

	if available_colors.is_empty():
		FW_Debug.debug_log(["Chains: no eligible colored tiles to lock"])
		return

	var selected_color: String = available_colors.pick_random()
	var selected_tiles: Array = (lockable_by_color[selected_color] as Array).duplicate()
	selected_tiles.shuffle()
	var target_count: int = min(normalized_count, selected_tiles.size())
	var locked_tiles: Array = []
	for i in target_count:
		var pos: Vector2 = selected_tiles[i]
		_convert_cell_to_lock(pos)
		locked_tiles.append(pos)

	if locked_tiles.is_empty():
		FW_Debug.debug_log(["Chains: computed color had no tiles after filtering"])
		return

	_emit_chains_lock_visuals(ability, locked_tiles, selected_color)
	var lock_message := "%s chains %d %s tiles!" % [ability.name, locked_tiles.size(), selected_color]
	EventBus.publish_combat_log.emit(lock_message)

func apply_color_ice(ability: FW_Ability, preferred_color: String = "") -> void:
	if ability == null:
		return
	_booster_setup(ability)
	_log_booster_cast(ability)

	var color_pool := ["red", "blue", "green", "orange", "pink"]
	var ice_candidates: Dictionary = {}
	var available_colors: Array = []
	for color in color_pool:
		var candidates: Array = _get_iceable_tiles_by_color(color)
		if candidates.is_empty():
			continue
		ice_candidates[color] = candidates
		available_colors.append(color)

	if available_colors.is_empty():
		FW_Debug.debug_log(["Ice: no eligible colored tiles to freeze"])
		return

	var normalized_preference := preferred_color.strip_edges().to_lower()
	var selected_color: String = normalized_preference
	if !available_colors.has(selected_color):
		selected_color = String(available_colors.pick_random())
	var tiles: Array = (ice_candidates[selected_color] as Array).duplicate()
	if tiles.is_empty():
		FW_Debug.debug_log(["Ice: chosen color had no viable tiles", selected_color])
		return

	for pos in tiles:
		_convert_cell_to_ice(pos)

	_emit_ice_visuals(ability, tiles, selected_color)
	var ice_message := "%s freezes every %s tile!" % [ability.name, selected_color]
	EventBus.publish_combat_log.emit(ice_message)

func apply_castle_concrete(ability: FW_Ability, cluster_size: int = 2) -> void:
	_apply_clustered_obstacle(
		ability,
		cluster_size,
		Callable(self, "_convert_cell_to_concrete"),
		Callable(self, "_emit_castle_concrete_visuals"),
		"Castle"
	)

func apply_fortress_heavy_concrete(ability: FW_Ability, cluster_size: int = 2) -> void:
	_apply_clustered_obstacle(
		ability,
		cluster_size,
		Callable(self, "_convert_cell_to_heavy_concrete"),
		Callable(self, "_emit_castle_concrete_visuals"),
		"Fortress"
	)

func _apply_clustered_obstacle(
	ability: FW_Ability,
	cluster_size: int,
	converter: Callable,
	visuals_callback: Callable,
	debug_tag: String
) -> void:
	if ability == null:
		return
	_booster_setup(ability)
	_log_booster_cast(ability)

	var normalized_cluster: int = max(cluster_size, 1)
	var cluster := _find_castle_concrete_cluster(normalized_cluster)
	if cluster.is_empty():
		var fallback := _get_obstacle_candidates()
		if fallback.is_empty():
			FW_Debug.debug_log(["%s: no valid tiles for placement" % debug_tag])
			return
		var fallback_count: int = min(normalized_cluster * normalized_cluster, fallback.size())
		if fallback_count <= 0:
			FW_Debug.debug_log(["%s: fallback count resolved to 0, skipping placement" % debug_tag])
			return
		var fallback_selection: Array = []
		for _i in fallback_count:
			var choice = fallback.pick_random()
			fallback.erase(choice)
			fallback_selection.append(choice)
			if converter.is_valid():
				converter.call(choice)
		if fallback_selection.is_empty():
			return
		FW_Debug.debug_log(["%s: placed fallback tiles" % debug_tag, fallback_selection.size()])
		if visuals_callback.is_valid():
			visuals_callback.call(ability, fallback_selection)
		return

	for pos in cluster:
		if converter.is_valid():
			converter.call(pos)

	if visuals_callback.is_valid() and !cluster.is_empty():
		visuals_callback.call(ability, cluster)

func _find_castle_concrete_cluster(cluster_size: int) -> Array:
	if cluster_size <= 1:
		var singles := _get_obstacle_candidates()
		if singles.is_empty():
			return []
		return [singles.pick_random()]

	var clusters: Array = []
	var max_col: int = GDM.grid.width - cluster_size + 1
	var max_row: int = GDM.grid.height - cluster_size + 1
	if max_col <= 0 or max_row <= 0:
		return []

	for col in max_col:
		for row in max_row:
			var cluster: Array = []
			var valid := true
			for dx in cluster_size:
				for dy in cluster_size:
					var pos := Vector2(col + dx, row + dy)
					if !_is_obstacle_target_available(pos):
						valid = false
						break
					cluster.append(pos)
				if !valid:
					break
			if valid and cluster.size() == cluster_size * cluster_size:
				clusters.append(cluster)

	if clusters.is_empty():
		return []
	return clusters.pick_random()

func _convert_cell_to_concrete(grid_position: Vector2) -> void:
	var col := int(grid_position.x)
	var row := int(grid_position.y)
	if col < 0 or col >= main_array.size():
		return
	if row < 0 or row >= main_array[col].size():
		return
	var piece = main_array[col][row]
	if piece:
		piece.queue_free()
	main_array[col][row] = null
	obstacle_manager.register_concrete_tile(grid_position)
	create_spawn_highlight_effect(grid_position)
	emit_signal("make_concrete", grid_position)

func _convert_cell_to_heavy_concrete(grid_position: Vector2) -> void:
	var col := int(grid_position.x)
	var row := int(grid_position.y)
	if col < 0 or col >= main_array.size():
		return
	if row < 0 or row >= main_array[col].size():
		return
	var piece = main_array[col][row]
	if piece:
		piece.queue_free()
	main_array[col][row] = null
	obstacle_manager.register_heavy_concrete_tile(grid_position)
	create_spawn_highlight_effect(grid_position)
	emit_signal("make_heavy_concrete", grid_position)

func _emit_castle_concrete_visuals(ability: FW_Ability, tiles: Array) -> void:
	if ability == null or tiles.is_empty():
		return
	var payload := {
		"grid_cells": tiles.duplicate()
	}
	payload["grid_cell"] = tiles[0]
	ability.trigger_visual_effects("on_cast", payload)

func _emit_ice_visuals(ability: FW_Ability, tiles: Array, color: String) -> void:
	if ability == null or tiles.is_empty():
		return
	var payload := {
		"grid_cells": tiles.duplicate()
	}
	var palette := {
		"red": Color(0.93, 0.58, 0.62, 1.0),
		"blue": Color(0.65, 0.84, 1.0, 1.0),
		"green": Color(0.61, 0.9, 0.72, 1.0),
		"orange": Color(0.97, 0.72, 0.52, 1.0),
		"pink": Color(0.95, 0.72, 0.92, 1.0)
	}
	var frost_color: Color = palette.get(color, Color(0.8, 0.93, 1.0, 1.0))
	payload["frozen_color"] = frost_color
	payload["grid_cell"] = tiles[0]
	ability.trigger_visual_effects("on_cast", payload)

func _get_lockable_tiles_by_color(color: String) -> Array:
	return _get_tiles_by_color(color, true, false)

func _get_iceable_tiles_by_color(color: String) -> Array:
	return _get_tiles_by_color(color, true, true)

func _get_tiles_by_color(color: String, exclude_locked: bool, exclude_ice: bool) -> Array:
	var positions: Array = []
	for col in GDM.grid.width:
		for row in GDM.grid.height:
			var piece = main_array[col][row]
			if piece == null:
				continue
			if piece.color != color:
				continue
			var pos := Vector2(col, row)
			if exclude_locked and _is_tile_locked(pos):
				continue
			if exclude_ice and _is_tile_ice(pos):
				continue
			if !_is_obstacle_target_available(pos):
				continue
			positions.append(pos)
	return positions

func _is_tile_locked(pos: Vector2) -> bool:
	return FW_GridUtils.is_in_array(obstacle_manager.locked_spaces, pos)

func _is_tile_ice(pos: Vector2) -> bool:
	return FW_GridUtils.is_in_array(obstacle_manager.ice_spaces, pos)

func _convert_cell_to_lock(grid_position: Vector2) -> void:
	obstacle_manager.register_lock_tile(grid_position)
	create_spawn_highlight_effect(grid_position)
	emit_signal("make_lock", grid_position)

func _emit_chains_lock_visuals(ability: FW_Ability, tiles: Array, color: String) -> void:
	if ability == null:
		return
	var payload := {
		"grid_cells": tiles.duplicate(),
		"locked_color": color
	}
	var palette := {
		"red": Color(0.87, 0.22, 0.28, 1.0),
		"blue": Color(0.32, 0.5, 0.94, 1.0),
		"green": Color(0.32, 0.73, 0.36, 1.0),
		"orange": Color(0.95, 0.56, 0.24, 1.0),
		"pink": Color(0.86, 0.38, 0.74, 1.0)
	}
	var lock_tone: Color = palette.get(color, Color(0.82, 0.82, 0.82, 1.0))
	var neutral_chain := Color(0.78, 0.79, 0.84, 1.0)
	var chain_tint := neutral_chain.lerp(lock_tone, 0.35)
	var highlight_tone := lock_tone.lightened(0.35)
	var spark_tone := lock_tone.lightened(0.55)
	payload["chain_color"] = chain_tint
	payload["lock_color"] = lock_tone
	payload["highlight_color"] = highlight_tone
	payload["spark_color"] = spark_tone
	if tiles.size() > 0:
		var tile_count := float(tiles.size())
		payload["chain_frequency"] = clamp(5.4 + tile_count * 0.18, 4.8, 7.8)
		payload["spark_density"] = clamp(3.2 + tile_count * 0.12, 3.0, 5.0)
	if tiles.size() > 0:
		payload["grid_cell"] = tiles[0]
	ability.trigger_visual_effects("on_cast", payload)

func _handle_line_booster(ability: FW_Ability, lines: Array, direction: String) -> void:
	_booster_setup(ability)
	for i in lines:
		if direction == "col":
			match_all_in_col(i)
		elif direction == "row":
			match_all_in_row(i)
	if current_matches.size() > 0:
		get_bombed_pieces()
		$destroy_timer.start()

func _handle_coords_booster(coords: Array, ability: FW_Ability) -> void:
	_booster_setup(ability)
	camera_zoom_effect()
	for i in coords:
		if main_array[i.x][i.y]:
			match_and_dim(main_array[i.x][i.y])
			FW_GridUtils.add_to_array(Vector2(i.x, i.y), current_matches)
	if current_matches.size() > 0:
		get_bombed_pieces()
		$destroy_timer.start()

func _handle_color_booster(color: String, ability: FW_Ability) -> void:
	_booster_setup(ability)
	color_bomb_used = true
	match_color(color)
	if current_matches.size() > 0:
		get_bombed_pieces()
		$destroy_timer.start()

func _on_game_manager_reset_grid_vars() -> void:
	clear_all_pieces()
	can_move = true
	controlling = false
	refillable = true
	move_checked = false
	streak = 1
	current_matches.clear()
	player_moves.clear_move_info()
	hint_system.destroy_hint()
	active_booster = ""
	first_touch = Vector2.ZERO
	final_touch = Vector2.ZERO
	color_bomb_used = false
	level_editor = false
	obstacle_manager.damaged_slime = false
	obstacle_manager.damaged_pink_slime = false
	get_tree().paused = false
	Input.flush_buffered_events()
	$hint_timer.stop()
	$destroy_timer.stop()
	$collapse_timer.stop()
	$shuffle_timer.stop()
	$enemy_move_timer.stop()
	$refill_timer.stop()

func apply_sinker_explosion(center_pos: Vector2, levels: int) -> int:
	"""
	Apply a smart 3x3 explosion pattern around the sinker position.
	Returns the number of tiles destroyed.

	The explosion creates a 3x3 square that intelligently positions itself:
	- If sinker is in left corner: explosion covers [0,1,2] columns
	- If sinker is in right corner: explosion covers [width-3, width-2, width-1] columns
	- If sinker is in middle: explosion covers [center-1, center, center+1] columns
	- Explosion goes up 'levels' rows from the bottom (row 0)
	"""
	var tiles_destroyed = 0
	var center_col = int(center_pos.x)
	var center_row = int(center_pos.y)  # Should be 0 (bottom row) for sinkers

	# Calculate the 3-column range, handling corners intelligently
	var start_col: int
	var end_col: int

	if center_col == 0:
		# Left corner: explosion covers columns 0, 1, 2
		start_col = 0
		end_col = min(2, GDM.grid.width - 1)
	elif center_col >= GDM.grid.width - 1:
		# Right corner: explosion covers last 3 columns
		start_col = max(0, GDM.grid.width - 3)
		end_col = GDM.grid.width - 1
	else:
		# Middle: explosion covers center ± 1 column
		start_col = max(0, center_col - 1)
		end_col = min(GDM.grid.width - 1, center_col + 1)

	# Apply explosion pattern: 3 columns × levels rows, starting from bottom
	for col in range(start_col, end_col + 1):
		for level in range(levels):
			var target_row = center_row + level  # Go up from bottom (row 0)
			var target_pos = Vector2(col, target_row)

			# Ensure we're within grid bounds
			if GDM.grid.is_in_grid(target_pos):
				var piece = main_array[col][target_row]
				if piece != null and not piece.matched:
					# Don't destroy other sinkers or indestructible pieces
					if not is_piece_sinker(col, target_row):
						match_and_dim(piece)
						FW_GridUtils.add_to_array(target_pos, current_matches)
						tiles_destroyed += 1

	# Create visual explosion effect
	create_explosion_effect(center_pos, start_col, end_col, levels)

	return tiles_destroyed

func create_explosion_effect(center: Vector2, start_col: int, end_col: int, levels: int) -> void:
	"""Create visual explosion effects for the destroyed area"""
	# Create explosion particles/effects for each destroyed tile
	for col in range(start_col, end_col + 1):
		for level in range(levels):
			var effect_pos = Vector2(col, center.y + level)
			if GDM.grid.is_in_grid(effect_pos):
				var pixel_pos = GDM.grid.grid_to_pixel(col, center.y + level)

				# Create explosion particle effect
				var explosion = animated_explosion.instantiate()
				add_child(explosion)
				explosion.position = pixel_pos

				# Stagger the explosion timing for visual appeal
				var delay = (abs(col - center.x) + level) * 0.1
				if delay > 0:
					explosion.modulate.a = 0
					var tween = get_tree().create_tween()
					tween.tween_interval(delay)
					tween.tween_property(explosion, "modulate:a", 1.0, 0.1)

	# Play explosion sound
	emit_signal("play_bomb_sound", 1)

	# Camera shake effect
	camera_zoom_effect()

func destroy_random_tiles(exclude_position: Vector2, tile_count: int) -> Array:
	"""
	Destroy random tiles on the grid (similar to Thrash ability).
	Excludes the sinker position itself.
	Returns an array of Vector2 positions that were destroyed.
	"""
	if not GDM or not GDM.grid:
		push_warning("destroy_random_tiles: GDM.grid is null")
		return []
	var tiles_to_destroy = []
	var positions_to_destroy = FW_GridUtils.get_random_positions(main_array, GDM.grid.width, GDM.grid.height, tile_count, exclude_position)

	# Destroy the selected tiles
	for pos in positions_to_destroy:
		var piece = main_array[pos.x][pos.y]
		if piece and not piece.matched:
			match_and_dim(piece)
			FW_GridUtils.add_to_array(pos, current_matches)
			tiles_to_destroy.append(pos)

	return tiles_to_destroy

func apply_column_clear() -> int:
	"""
	Clear a random column on the grid.
	Returns the column number that was cleared.
	"""
	var column = next_column_clear if next_column_clear != -1 else randi() % GDM.grid.width
	next_column_clear = -1  # Reset
	match_all_in_col(column)
	return column

func apply_row_clear() -> int:
	"""
	Clear a random row on the grid.
	Returns the row number that was cleared.
	"""
	var random_row = randi() % GDM.grid.height
	match_all_in_row(random_row)
	return random_row

func apply_v_formation_clear(center_position: Vector2) -> int:
	"""
	Clear tiles in a V formation from the center position to the top of the grid.
	The V expands as it goes up, creating a cone-like pattern.
	Returns the number of tiles destroyed.
	"""
	var tiles_destroyed = 0
	var center_col = int(center_position.x)
	var start_row = int(center_position.y)

	# Create V pattern going upward from the sinker position
	for level in range(GDM.grid.height - start_row):
		var current_row = start_row + level
		if current_row >= GDM.grid.height:
			break

		# V expands by 1 tile on each side per level
		var left_col = center_col - level
		var right_col = center_col + level

		# Destroy center column only at the apex of the V
		if level == 0 and GDM.grid.is_in_grid(Vector2(center_col, current_row)):
			var piece = main_array[center_col][current_row]
			if piece and not piece.matched and not is_piece_sinker(center_col, current_row):
				match_and_dim(piece)
				FW_GridUtils.add_to_array(Vector2(center_col, current_row), current_matches)
				tiles_destroyed += 1

		# Destroy left side of V if different from center
		if left_col != center_col and GDM.grid.is_in_grid(Vector2(left_col, current_row)):
			var piece = main_array[left_col][current_row]
			if piece and not piece.matched and not is_piece_sinker(left_col, current_row):
				match_and_dim(piece)
				FW_GridUtils.add_to_array(Vector2(left_col, current_row), current_matches)
				tiles_destroyed += 1

		# Destroy right side of V if different from center and left
		if right_col != center_col and right_col != left_col and GDM.grid.is_in_grid(Vector2(right_col, current_row)):
			var piece = main_array[right_col][current_row]
			if piece and not piece.matched and not is_piece_sinker(right_col, current_row):
				match_and_dim(piece)
				FW_GridUtils.add_to_array(Vector2(right_col, current_row), current_matches)
				tiles_destroyed += 1

	return tiles_destroyed

# func _on_level_editor_manager_make_concrete() -> void:
#     var pos = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
#     level_obstacle_data["concrete"].append(pos)
#     write_obstacles_to_disk(GDM.level, level_obstacle_data)
#     refresh_obstacles()

# func _on_level_editor_manager_make_ice() -> void:
#     var pos = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
#     level_obstacle_data["ice"].append(pos)
#     emit_signal("make_ice", pos)
#     write_obstacles_to_disk(GDM.level, level_obstacle_data)
#     refresh_obstacles()

# func _on_level_editor_manager_make_lock() -> void:
#     var pos = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
#     level_obstacle_data["locked"].append(pos)
#     emit_signal("make_lock", pos)
#     write_obstacles_to_disk(GDM.level, level_obstacle_data)
#     refresh_obstacles()

# func _on_level_editor_manager_make_slime() -> void:
#     var pos = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
#     level_obstacle_data["slime"].append(pos)
#     emit_signal("make_slime", pos)
#     write_obstacles_to_disk(GDM.level, level_obstacle_data)
#     refresh_obstacles()

# func _on_level_editor_manager_make_heavy_concrete() -> void:
#     var pos = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
#     level_obstacle_data["heavy_concrete"].append(pos)
#     write_obstacles_to_disk(GDM.level, level_obstacle_data)
#     refresh_obstacles()

# func _on_level_editor_manager_make_pink_slime() -> void:
#     var pos = GDM.grid.pixel_to_grid(get_global_mouse_position().x, get_global_mouse_position().y)
#     level_obstacle_data["pink_slime"].append(pos)
#     emit_signal("make_pink_slime", pos)
#     write_obstacles_to_disk(GDM.level, level_obstacle_data)
#     refresh_obstacles()

# func write_obstacles_to_disk(level: int, dict: Dictionary) -> void:
#     var path = "res://Levels/level" + str(level) + ".dat"
#     var file = FileAccess.open(path, FileAccess.WRITE)
#     if file != null:
#         file.store_var(dict)
#         file.close()
#     else:
#         pass
