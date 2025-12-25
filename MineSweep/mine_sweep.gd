extends CanvasLayer

const RESULT_TYPE_EQUIPMENT := "equipment"
const RESULT_TYPE_CONSUMABLE := "consumable"
const RESULT_TYPE_GOLD := "gold"
const RESULT_TYPE_DEBUFF := "debuff"

# Assets
const TEXTURE_COVER := preload("res://tile_images/pom.png")
const TEXTURE_MINE := preload("res://tile_images/ball.png")
const TEXTURE_FLAG := preload("res://tile_images/orange_bone.png")

var tutorial_out := false

class MinesweeperCell:
	extends TextureButton

	signal cell_revealed(cell: MinesweeperCell)
	signal cell_flagged(cell: MinesweeperCell)
	signal cell_chorded(cell: MinesweeperCell)

	var grid_x: int
	var grid_y: int
	var is_mine: bool = false
	var is_revealed: bool = false
	var is_flagged: bool = false
	var neighbor_mine_count: int = 0
	var owner_board: Node = null
	var _press_timer: Timer
	var _long_press_detected: bool = false
	var _ignore_next_click: bool = false
	var _press_source_is_touch: bool = false
	var _is_mouse_pressed: bool = false

	var _cover_rect: TextureRect
	var _flag_rect: TextureRect
	var _mine_rect: TextureRect
	var _label: Label

	func _init(x: int, y: int, cell_size_vec: Vector2) -> void:
		grid_x = x
		grid_y = y
		custom_minimum_size = cell_size_vec
		ignore_texture_size = true
		stretch_mode = TextureButton.STRETCH_SCALE

		# Mine Icon (Hidden by default)
		_mine_rect = TextureRect.new()
		_mine_rect.texture = TEXTURE_MINE
		_mine_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_mine_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_mine_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_mine_rect.visible = false
		_mine_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_mine_rect)

		# Number Label (Hidden by default)
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.visible = false
		_label.label_settings = LabelSettings.new()
		# Use the passed-in cell_size_vec so font is sized consistently at init
		_label.label_settings.font_size = int(cell_size_vec.y * 0.6)
		_label.label_settings.outline_size = 4
		_label.label_settings.outline_color = Color.BLACK
		add_child(_label)

		# Cover (The unclicked tile)
		_cover_rect = TextureRect.new()
		_cover_rect.texture = TEXTURE_COVER
		_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cover_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_cover_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_cover_rect)

		# Flag (Overlay on cover)
		_flag_rect = TextureRect.new()
		_flag_rect.texture = TEXTURE_FLAG
		_flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_flag_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flag_rect.visible = false
		_flag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_flag_rect)

		# Input handling
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT

		# Long press timer for touch interactions
		_press_timer = Timer.new()
		_press_timer.one_shot = true
		_press_timer.wait_time = 0.35
		_press_timer.autostart = false
		_press_timer.timeout.connect(Callable(self, "_on_long_press_timeout"))
		# No toggle cooldown (allows quick unflagging). We still rely on
		# _ignore_next_click to prevent synthetic mouse events after touch-long-press.
		add_child(_press_timer)

	func _on_long_press_timeout() -> void:
		_long_press_detected = true
		toggle_flag(_press_source_is_touch)
		# Suppress any subsequent synthetic mouse events that might be emitted
		# as a result of this touch (e.g., on some platforms a touch generates
		# synthetic mouse events). This prevents the tile from being revealed
		# immediately after toggling the flag.
		_ignore_next_click = true

	func _gui_input(event: InputEvent) -> void:
		if is_revealed:
			# Allow chording on revealed cells
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
					# Check if both are pressed or just double click?
					# Standard minesweeper chording is Left+Right or Middle click.
					# Let's support Middle click for chording.
					if event.button_index == MOUSE_BUTTON_MIDDLE:
						cell_chorded.emit(self)
			return

		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				toggle_flag(false)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				# Optionally support mouse long-press to toggle flags like on mobile
				if owner_board != null and owner_board.enable_mouse_long_press:
					_is_mouse_pressed = true
					_press_source_is_touch = false
					_press_timer.start()
					return
				# If we've been told to ignore the next click because of a touch/long-press,
				# swallow this event and clear the flag. This prevents a long-press from
				# immediately triggering a reveal on certain platforms that emit both
				# touch and mouse events.
				if _ignore_next_click:
					_ignore_next_click = false
					return
				# Left click: reveal on release (flagging uses right-click or long-press)
				else:
					if not is_flagged:
						reveal()

		# Handle mouse button releases if we enabled mouse long-press support
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _is_mouse_pressed:
			_is_mouse_pressed = false
			# If long-press was detected, we already handled the flag toggle. Don't reveal.
			if _long_press_detected:
				_long_press_detected = false
				# Prevent any synthetic touch/mouse events from acting on this release
				_ignore_next_click = true
				return
			_press_timer.stop()
			# Treat as regular click: left click reveal if not flagged
			if not is_flagged:
				reveal()

		# Touch input: handle long-press toggles (for mobile)
		if event is InputEventScreenTouch:
			if event.pressed:
				_long_press_detected = false
				_ignore_next_click = false
				_press_source_is_touch = true
				_press_timer.start()
			else:
				# Release: if timer is still running, it was a tap
				if _press_timer.is_stopped() and _long_press_detected:
					# Already processed by long-press timeout
					# Stop propagation to prevent double reveal from mouse/mapped events
					_ignore_next_click = true
					_long_press_detected = false
					return
				_press_timer.stop()
				# Treat as regular tap: reveal if not flagged
				if not is_flagged:
					reveal()

		# Cancel long press if dragging
		if event is InputEventScreenDrag:
			_press_timer.stop()
			_ignore_next_click = false

	func toggle_flag(from_touch: bool = false) -> void:
		if is_revealed: return
		# If a touch-based action triggered the flag toggle, mark the cell to
		# ignore the next mouse click (synthetic) to avoid accidental reveal.
		if from_touch:
			_ignore_next_click = true
		is_flagged = not is_flagged
		_flag_rect.visible = is_flagged
		# Pop animation feedback for flagging
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.06).from(Vector2(1,1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2(1,1), 0.12).set_trans(Tween.TRANS_BOUNCE)
		cell_flagged.emit(self)
		# Play a small toggle sound for feedback
		if SoundManager:
			SoundManager._play_random_sound()



	func reveal(play_sound: bool = true) -> void:
		if is_revealed or is_flagged: return
		is_revealed = true
		# Pop/reveal animation for visual feedback
		var rt = create_tween()
		rt.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08).from(Vector2(1,1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rt.tween_property(self, "scale", Vector2(1,1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_cover_rect.visible = false
		_flag_rect.visible = false # Should be hidden if revealed, though logic prevents revealing flagged

		if is_mine:
			_mine_rect.visible = true
			modulate = Color(1, 0.5, 0.5) # Red tint for explosion
			if play_sound and SoundManager:
				SoundManager._play_random_explosion_sound(1)
		else:
			# Show number if > 0
			if neighbor_mine_count > 0:
				_label.text = str(neighbor_mine_count)
				_label.visible = true
				_label.label_settings.font_color = _get_number_color(neighbor_mine_count)
			else:
				# Empty cell, maybe darken slightly
				modulate = Color(0.8, 0.8, 0.8)
			# Play positive/reveal sound
			if play_sound and SoundManager:
				SoundManager._play_random_positive_sound()

		cell_revealed.emit(self)

	func set_mine(value: bool) -> void:
		is_mine = value

	func set_neighbor_count(count: int) -> void:
		neighbor_mine_count = count

	func _get_number_color(count: int) -> Color:
		match count:
			1: return Color(0.2, 0.2, 1.0) # Blue
			2: return Color(0.2, 0.8, 0.2) # Green
			3: return Color(1.0, 0.2, 0.2) # Red
			4: return Color(0.0, 0.0, 0.5) # Dark Blue
			5: return Color(0.5, 0.0, 0.0) # Dark Red
			6: return Color(0.0, 0.5, 0.5) # Cyan
			7: return Color(0.0, 0.0, 0.0) # Black
			8: return Color(0.5, 0.5, 0.5) # Gray
			_: return Color.WHITE

@export_range(4, 20, 1) var grid_width := 10
@export_range(4, 20, 1) var grid_height := 10
@export_range(1, 100, 1) var mine_count := 15
@export_range(32.0, 128.0, 4.0) var cell_size := 64.0
@export var enable_mouse_long_press := true
@export var reward_mix: Array[String] = ["equipment", "consumable", "gold"]
@export var debuff_pool: Array[FW_Buff] = []

@onready var board_grid: GridContainer = %BoardGrid
@onready var board_panel: PanelContainer = %BoardPanel
@onready var status_label: Label = %StatusLabel
@onready var mine_count_label: Label = %MineCountLabel
@onready var new_game_button: Button = %NewGameButton
@onready var loot_screen: Node = %LootScreen
@onready var tutorial_panel: PanelContainer = %TutorialPanel
@onready var tutorial_button: Button = %TutorialButton

var _cells: Array[MinesweeperCell] = []
var _rng := RandomNumberGenerator.new()
var _game_active := false
var _first_click := true
var _flags_placed := 0
var _loot_manager: FW_LootManager
var _debuff_queue: Array[FW_Buff] = []

func _ready() -> void:
	_rng.randomize()
	SoundManager.wire_up_all_buttons()
	_connect_ui()
	_start_new_game()

	# Ensure the board is ready for visual effects
	if board_panel:
		board_panel.set_process(true)

func _connect_ui() -> void:
	if new_game_button and not new_game_button.pressed.is_connected(Callable(self, "_start_new_game")):
		new_game_button.pressed.connect(_start_new_game)
	# Connect the loot screen back button similar to LightsOff, with proper
	# instance validation and duplicate connection protection.
	_connect_loot_screen()
	# Connect tutorial close if present
	if tutorial_button and not tutorial_button.pressed.is_connected(Callable(self, "_on_tutorial_button_pressed")):
		tutorial_button.pressed.connect(_on_tutorial_button_pressed)


func _connect_loot_screen() -> void:
	if not is_instance_valid(loot_screen):
		return
	var callable := Callable(self, "_on_loot_screen_back_button")
	# Prefer connecting to the LootScreen's own 'back_button' signal (if exposed)
	if loot_screen.has_signal("back_button") and not loot_screen.is_connected("back_button", callable):
		loot_screen.connect("back_button", callable)

	# As a fallback and for backward compatibility, also connect the child button
	# if it exists and is not connected to our callable already (mirrors LightsOff)
	if loot_screen.back_button and not loot_screen.back_button.is_connected(callable):
		loot_screen.back_button.connect(callable)

func _start_new_game() -> void:
	_game_active = true
	_first_click = true
	_flags_placed = 0
	_clear_board()
	_create_grid()
	_update_status()

func _clear_board() -> void:
	for child in board_grid.get_children():
		child.queue_free()
	_cells.clear()

func _create_grid() -> void:
	board_grid.columns = grid_width
	var size_vec = Vector2(cell_size, cell_size)

	for y in range(grid_height):
		for x in range(grid_width):
			var cell = MinesweeperCell.new(x, y, size_vec)
			board_grid.add_child(cell)
			_cells.append(cell)
			cell.cell_revealed.connect(_on_cell_revealed)
			cell.cell_flagged.connect(_on_cell_flagged)
			cell.cell_chorded.connect(_on_cell_chorded)
			cell.owner_board = self

func _place_mines(safe_cell: MinesweeperCell) -> void:
	var mines_placed = 0
	var safe_zone = _get_neighbors(safe_cell)
	safe_zone.append(safe_cell)

	# Ensure we don't place more mines than cells (minus safe zone)
	var max_mines = min(mine_count, _cells.size() - safe_zone.size())

	while mines_placed < max_mines:
		var idx = _rng.randi() % _cells.size()
		var cell = _cells[idx]

		if not cell.is_mine and not cell in safe_zone:
			cell.set_mine(true)
			mines_placed += 1

	# Calculate numbers
	for cell in _cells:
		if not cell.is_mine:
			var count = 0
			for neighbor in _get_neighbors(cell):
				if neighbor.is_mine:
					count += 1
			cell.set_neighbor_count(count)

func _get_neighbors(cell: MinesweeperCell) -> Array[MinesweeperCell]:
	var neighbors: Array[MinesweeperCell] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0: continue

			var nx = cell.grid_x + dx
			var ny = cell.grid_y + dy

			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				var idx = ny * grid_width + nx
				if idx >= 0 and idx < _cells.size():
					neighbors.append(_cells[idx])
	return neighbors

func _on_cell_revealed(cell: MinesweeperCell) -> void:
	if not _game_active: return

	if _first_click:
		_place_mines(cell)
		_first_click = false
		if cell.neighbor_mine_count > 0:
			cell._label.text = str(cell.neighbor_mine_count)
			cell._label.visible = true
			cell._label.label_settings.font_color = cell._get_number_color(cell.neighbor_mine_count)

		# If it's 0, we need to flood fill
		if cell.neighbor_mine_count == 0:
			_flood_fill(cell)

	if cell.is_mine:
		_game_over(false, cell)
	else:
		if cell.neighbor_mine_count == 0:
			_flood_fill(cell)
		_check_win()

func _flood_fill(start_cell: MinesweeperCell) -> void:
	var queue = [start_cell]
	var visited = {start_cell: true}
	var reveals := 0

	while not queue.is_empty():
		var current = queue.pop_front()
		var neighbors = _get_neighbors(current)

		for neighbor in neighbors:
			if not neighbor.is_revealed and not neighbor.is_flagged:
				neighbor.reveal(false)
				reveals += 1
				if neighbor.neighbor_mine_count == 0 and not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)

 	# Play a mass reveal sound if we uncovered multiple
	if reveals > 3 and SoundManager:
		SoundManager._play_random_positive_sound()
func _on_cell_flagged(cell: MinesweeperCell) -> void:
	if not _game_active: return
	_flags_placed += (1 if cell.is_flagged else -1)
	_update_status()

func _on_cell_chorded(cell: MinesweeperCell) -> void:
	if not _game_active: return
	if not cell.is_revealed: return

	var neighbors = _get_neighbors(cell)
	var flag_count = 0
	for n in neighbors:
		if n.is_flagged:
			flag_count += 1

	if flag_count == cell.neighbor_mine_count:
		for n in neighbors:
			if not n.is_flagged and not n.is_revealed:
				n.reveal(false)
				# _on_cell_revealed will be called by the signal
		# Play a chord sound
		if SoundManager:
			SoundManager._play_random_sound()

func _update_status() -> void:
	if mine_count_label:
		mine_count_label.text = "Mines: %d" % (mine_count - _flags_placed)
	if status_label:
		status_label.text = "Find all mines!"

func _check_win() -> void:
	var revealed_count = 0
	for cell in _cells:
		if cell.is_revealed:
			revealed_count += 1

	if revealed_count == (_cells.size() - mine_count):
		_game_over(true)

func _game_over(win: bool, source_cell: MinesweeperCell = null) -> void:
	_game_active = false
	if win:
		status_label.text = "VICTORY!"
		_present_loot()
		FW_MinigameRewardHelper.mark_minigame_completed(true)
	else:
		status_label.text = "BOOM!"
		_reveal_all_mines()
		_apply_penalty(source_cell)
		FW_MinigameRewardHelper.mark_minigame_completed(true)

func _reveal_all_mines() -> void:
	for cell in _cells:
		if cell.is_mine and not cell.is_revealed:
			cell.reveal(false)
			_emit_mine_particles_at_cell(cell)

func _emit_mine_particles_at_cell(cell: MinesweeperCell) -> void:
	if not is_instance_valid(cell):
		return
	var label_global_rect = cell.get_global_rect()
	var pos: Vector2 = label_global_rect.position + label_global_rect.size * 0.5
	_emit_particles(pos, Color(1, 0.6, 0.2, 1), 8)

func _emit_mine_particles_for_all_mines() -> void:
	for cell in _cells:
		if cell.is_mine:
			_emit_mine_particles_at_cell(cell)

func _emit_confetti(global_pos: Vector2) -> void:
	# Create a set of colorful particles for celebration
	var colors = [Color(1, 0.4, 0.6), Color(0.95, 0.8, 0.35), Color(0.4, 0.85, 0.95), Color(0.58, 0.68, 0.95), Color(0.55, 0.95, 0.6)]
	for i in range(28):
		var c = colors[randi() % colors.size()]
		_emit_particles(global_pos + Vector2(randf() * 80 - 40, randf() * 12 - 6), c, 1)

func _emit_particles(global_pos: Vector2, color: Color, spawn_count: int = 12) -> void:
	var texture = null
	var use_texture = false
	if ResourceLoader.exists("res://Icons/rune.png"):
		texture = load("res://Icons/rune.png")
		use_texture = true
	for i in spawn_count:
		var node: Control
		if use_texture:
			var tex = TextureRect.new()
			tex.texture = texture
			tex.expand = true
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			node = tex
			node.modulate = color
		else:
			var cr := ColorRect.new()
			cr.color = color
			node = cr
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s = 6 + randi() % 8
		node.custom_minimum_size = Vector2(s, s)
		node.scale = Vector2(1, 1)
		node.position = global_pos
		add_child(node)
		var rise = -30 - randf() * 40
		var horizontal = randf() * 80 - 40
		var life = 0.6 + randf() * 0.6
		var target_pos = node.position + Vector2(horizontal, rise)
		var tw = create_tween()
		tw.tween_property(node, "position", target_pos, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", Vector2(0.2, 0.2), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(node, "modulate:a", 0.0, life).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			if is_instance_valid(node):
				node.queue_free()
		)

func _shake_board(amplitude: int = 8, duration: float = 0.6) -> void:
	if not is_instance_valid(board_panel):
		return
	var original_pos: Vector2 = board_panel.rect_position
	var steps := int(duration / 0.06)
	var tw := create_tween()
	for i in range(steps):
		var shake_offset: Vector2 = Vector2((randf() - 0.5) * amplitude, (randf() - 0.5) * amplitude)
		tw.tween_callback(Callable(self, "_set_board_panel_pos").bind(original_pos + shake_offset)).set_delay(0.06 * i)
	tw.tween_callback(func(): board_panel.rect_position = original_pos)

func _set_board_panel_pos(p: Vector2) -> void:
	board_panel.rect_position = p

func _spawn_floating_text(global_pos: Vector2, text: String, color: Color, duration: float = 1.0) -> void:
	var label := Label.new()
	label.text = str(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.label_settings = LabelSettings.new()
	label.label_settings.font_size = 26
	label.set("theme_override_colors/font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = global_pos
	add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "position", label.position + Vector2(0, -48), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, duration)
	tw.tween_callback(func(): label.queue_free())

func _present_loot() -> void:
	_loot_manager = FW_MinigameRewardHelper.ensure_loot_manager(_loot_manager)

	var rewards := []
	var reward_type := _pick_reward_type()

	match reward_type:
		RESULT_TYPE_EQUIPMENT:
			var equipment_item: FW_Item = _loot_manager.sweet_loot()
			if equipment_item:
				rewards.append(equipment_item)
		RESULT_TYPE_CONSUMABLE:
			var consumable_item: FW_Item = _loot_manager.generate_random_consumable()
			if consumable_item:
				rewards.append(consumable_item)
		RESULT_TYPE_GOLD:
			var amount := _rng.randi_range(50, 150)
			var gold_item: FW_Item = _loot_manager.create_gold_item(amount)
			if gold_item:
				gold_item.name = "%d gp" % amount
				rewards.append(gold_item)

	if is_instance_valid(loot_screen) and loot_screen.has_method("show_loot_collection"):
		loot_screen.show_loot_collection(rewards, "Victory!", [])
	if is_instance_valid(loot_screen) and loot_screen.has_method("slide_in"):
		loot_screen.slide_in()
	# Play victory sound
	if SoundManager:
		SoundManager._play_random_win_sound()
	# Confetti and victory particles
	_emit_confetti(board_grid.get_global_rect().position + board_grid.get_global_rect().size * 0.5)
	# Floating text for gold reward
	if reward_type == RESULT_TYPE_GOLD and rewards.size() > 0:
		var gold_item: FW_Item = rewards[0]
		if gold_item and gold_item.item_type == FW_Item.ITEM_TYPE.MONEY:
			_spawn_floating_text(board_grid.get_global_rect().position + board_grid.get_global_rect().size * 0.5, "+%d gp" % gold_item.gold_value, Color(1.0, 0.8, 0.25))

func _apply_penalty(source_cell: MinesweeperCell = null) -> void:
	_debuff_queue = FW_MinigameRewardHelper.build_debuff_queue(debuff_pool)
	var debuff = FW_MinigameRewardHelper.draw_buff_from_queue(_debuff_queue)
	if debuff:
		FW_MinigameRewardHelper.queue_debuff_on_player(debuff)
		if is_instance_valid(loot_screen) and loot_screen.has_method("show_buffs"):
			loot_screen.show_buffs([debuff])
		if is_instance_valid(loot_screen) and loot_screen.has_method("show_text"):
			loot_screen.show_text("Ouch!")
	else:
		if is_instance_valid(loot_screen) and loot_screen.has_method("show_text"):
			loot_screen.show_text("Better luck next time!")

	if is_instance_valid(loot_screen) and loot_screen.has_method("slide_in"):
		loot_screen.slide_in()
	# Play mine/explosion negative sound
	if SoundManager:
		SoundManager._play_random_explosion_sound(1)
	# Spawn floating Boom text at source cell if available
	if is_instance_valid(source_cell):
		var label_global_rect = source_cell.get_global_rect()
		var pos: Vector2 = label_global_rect.position + label_global_rect.size * 0.5
		_spawn_floating_text(pos, "BOOM!", Color(1, 0.3, 0.3))
	# Board shake and explosion particles
	_shake_board()
	_emit_mine_particles_for_all_mines()

func _on_tutorial_close_pressed() -> void:
	if is_instance_valid(tutorial_panel):
		tutorial_panel.visible = false

func _on_tutorial_button_pressed() -> void:
	if tutorial_out:
		tutorial_panel.hide()
		tutorial_out = false
	else:
		tutorial_panel.show()
		tutorial_out = true

func _on_loot_screen_back_button() -> void:
	_on_back_button_pressed()

func _on_back_button_pressed() -> void:
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	# Use ScreenRotator for consistent navigation across minigames
	ScreenRotator.change_scene("res://Scenes/level_select2.tscn")

func _pick_reward_type() -> String:
	if reward_mix.is_empty():
		return RESULT_TYPE_GOLD
	var index := _rng.randi_range(0, reward_mix.size() - 1)
	return reward_mix[index]
