extends CanvasLayer

const CARD_BACK_TEXTURE: Texture2D = preload("res://Solitaire/CardBack.png")
const LayoutMetrics := preload("res://Solitaire/Resources/FW_SolitaireLayoutMetrics.gd")

const FOUNDATION_SUIT_ORDER: Array[int] = [
	FW_Card.Suit.HEARTS,
	FW_Card.Suit.DIAMONDS,
	FW_Card.Suit.CLUBS,
	FW_Card.Suit.SPADES
]

const CARD_TWEEN_META_KEY: String = "_active_card_tween"
const SETTINGS_PATH: String = "user://solitaire_settings.cfg"
const SETTINGS_SECTION_OPTIONS: String = "options"
const SETTINGS_KEY_DRAW_THREE: String = "draw_three_cards"
var WASTE_FAN_HORIZONTAL_OFFSET: float = 20.0
var WASTE_FAN_VERTICAL_OFFSET: float = 4.0

var _debug_level_storage: int = FW_Debug.Level.INFO

@export_enum("Error", "Warn", "Info", "Debug", "Verbose")
var debug_level: int:
	get:
		return _debug_level_storage
	set(value):
		var clamped: int = clamp(value, int(FW_Debug.Level.ERROR), int(FW_Debug.Level.VERBOSE))
		_debug_level_storage = clamped
		FW_Debug.set_level(clamped)

enum LayoutPreset { PORTRAIT, LANDSCAPE }

var shader_bg: ColorRect
var background: TextureRect

var slots_root: Control
var card_container: Control

var stock_panel: Panel
var waste_panel: Panel

var stock_texture: TextureRect
var stock_count_label: Label

var game_timer: Timer

var win_bg_panel: Panel
var win_label: Label

var new_game_button: Button
var undo_button: Button
var auto_complete_button: Button
var draw_mode_toggle: CheckButton
var view_stats_button: Button
var layout_toggle_button: Button
var stats_label: Label

var stats_slide_in: CanvasLayer
var back_button: TextureButton

var foundation_slots: Array[Panel] = []
var tableau_slots: Array[Panel] = []

var _layout_root: Node
var _card_pool_initialized := false
var _current_layout_preset: LayoutPreset = LayoutPreset.PORTRAIT
var _drag_controller: FW_SolitaireDragController
var _active_layout_metrics: FW_SolitaireLayoutMetrics
var _fallback_layout_metrics: FW_SolitaireLayoutMetrics = LayoutMetrics.new()

func _assign_layout_nodes(layout_root: Node, metrics_override: FW_SolitaireLayoutMetrics = null) -> void:
	if layout_root == null:
		return
	var nodes := FW_SolitaireLayoutBinder.bind(layout_root)
	var resolved_metrics := metrics_override
	if resolved_metrics == null and nodes.has("layout_metrics"):
		resolved_metrics = nodes["layout_metrics"]
	_apply_layout_metrics(resolved_metrics)
	if layout_root.has_method("apply_layout_metrics"):
		layout_root.call("apply_layout_metrics", _active_layout_metrics)
	shader_bg = nodes.get("shader_bg")
	background = nodes.get("background")
	slots_root = nodes.get("slots_root")
	card_container = nodes.get("card_container")
	stock_panel = nodes.get("stock_panel")
	waste_panel = nodes.get("waste_panel")
	stock_texture = nodes.get("stock_texture")
	stock_count_label = nodes.get("stock_count_label")
	game_timer = nodes.get("game_timer")
	win_bg_panel = nodes.get("win_bg_panel")
	win_label = nodes.get("win_label")
	new_game_button = nodes.get("new_game_button")
	undo_button = nodes.get("undo_button")
	auto_complete_button = nodes.get("auto_complete_button")
	draw_mode_toggle = nodes.get("draw_mode_toggle")
	view_stats_button = nodes.get("view_stats_button")
	layout_toggle_button = nodes.get("layout_toggle_button")
	stats_label = nodes.get("stats_label")
	stats_slide_in = nodes.get("stats_slide_in")
	back_button = nodes.get("back_button")
	foundation_slots = _extract_panel_list(nodes.get("foundation_slots", []), 4, "foundation")
	tableau_slots = _extract_panel_list(nodes.get("tableau_slots", []), 7, "tableau")
	for warning in nodes.get("warnings", []):
		_log_warn(warning)
	if card_container == null:
		_log_warn("[LayoutBind] Card container missing on layout %s" % layout_root.name)
	if stats_slide_in == null:
		_log_warn("[LayoutBind] StatsSlideIn missing on layout %s" % layout_root.name)
	if layout_toggle_button == null:
		_log_warn("[LayoutBind] LayoutToggleButton missing on layout %s" % layout_root.name)
	_update_slot_metrics()

func _extract_panel_list(value: Variant, expected_count: int, label: String) -> Array[Panel]:
	var result: Array[Panel] = []
	if value is Array:
		for element in value:
			if element is Panel:
				result.append(element)
			elif element != null:
				_log_warn("[LayoutBind] Ignoring %s entry that is not a Panel: %s" % [label, str(element)])
	if expected_count > 0 and result.size() < expected_count:
		_log_warn("[LayoutBind] %s slots resolved=%d expected=%d" % [label, result.size(), expected_count])
	return result

func _apply_layout_metrics(metrics: FW_SolitaireLayoutMetrics) -> void:
	var resolved := metrics
	if resolved == null:
		resolved = _fallback_layout_metrics
	if resolved == null:
		resolved = LayoutMetrics.new()
	elif resolved != _fallback_layout_metrics:
		_fallback_layout_metrics = resolved
	_active_layout_metrics = resolved
	CARD_WIDTH = resolved.card_width
	CARD_HEIGHT = resolved.card_height
	CARD_OFFSET_Y = resolved.tableau_vertical_spacing
	CARD_GAP = resolved.tableau_horizontal_gap
	WASTE_FAN_HORIZONTAL_OFFSET = resolved.waste_fan_horizontal_offset
	WASTE_FAN_VERTICAL_OFFSET = resolved.waste_fan_vertical_offset
	_apply_metrics_to_all_displays()

func _apply_metrics_to_all_displays() -> void:
	for display in card_displays:
		_apply_display_metrics(display)
	for pooled in card_display_pool:
		_apply_display_metrics(pooled)

func _apply_display_metrics(display: FW_CardDisplay) -> void:
	if display == null:
		return
	if not is_instance_valid(display):
		return
	if display.has_method("set_layout_metrics"):
		display.set_layout_metrics(_active_layout_metrics)

func _update_slot_metrics() -> void:
	if _active_layout_metrics == null:
		return
	var metrics := _active_layout_metrics
	_update_panel_metrics(stock_panel, metrics.get_stock_slot_size())
	_update_panel_metrics(waste_panel, metrics.get_waste_slot_size())
	for foundation_slot in foundation_slots:
		_update_panel_metrics(foundation_slot, metrics.get_foundation_slot_size())
	for tableau_slot in tableau_slots:
		_update_panel_metrics(tableau_slot, metrics.get_tableau_slot_size())

func _update_panel_metrics(panel: Control, size: Vector2) -> void:
	if panel == null:
		return
	panel.custom_minimum_size = size
	panel.pivot_offset = size * 0.5
	panel.set_deferred("size", size)

func bind_layout(layout_root: Node, reset_game: bool = true, preset_value: Variant = LayoutPreset.PORTRAIT, metrics_override: FW_SolitaireLayoutMetrics = null) -> void:
	if layout_root == null:
		return
	_current_layout_preset = _coerce_layout_preset(int(preset_value))
	_log_debug("[LayoutBind]", "Binding layout", layout_root.name, "preset=", _layout_preset_to_string(_current_layout_preset), "reset=", reset_game, "game_in_progress=", game_in_progress)
	_layout_root = layout_root
	var effective_metrics := metrics_override
	if effective_metrics == null and layout_root.has_method("get_layout_metrics"):
		effective_metrics = layout_root.call("get_layout_metrics")
	_assign_layout_nodes(layout_root, effective_metrics)
	_log_debug("[LayoutBind]", "card_container=", _debug_node_path(card_container))
	SoundManager.wire_up_all_buttons()
	if card_display_scene == null:
		card_display_scene = load("res://Solitaire/FW_CardDisplay.tscn")
	_configure_static_ui()
	_sync_draw_mode_toggle()
	if not _card_pool_initialized:
		if card_container == null:
			_log_warn("Card container missing; cannot initialize card pool")
		else:
			_initialize_card_pool()
			_card_pool_initialized = true
	else:
		_debug_log_layout_info("before_reparent")
		_reparent_card_displays()
	if reset_game or not game_in_progress:
		initialize_game()
	else:
		refresh_all_card_positions()
		update_stats_display()
		_resume_active_game_timer()
	_apply_orientation_to_all_displays()
	_apply_win_label_orientation()
	_debug_log_slot_alignment("post_bind_slots")
	_debug_log_layout_info("post_bind")
	call_deferred("_debug_log_layout_info", "post_bind_deferred")
	call_deferred("_debug_log_slot_alignment", "post_bind_slots_deferred")

func rebind_layout(layout_root: Node, reset_game: bool = false, preset_value: Variant = null) -> void:
	var target_preset := _current_layout_preset
	if preset_value != null:
		target_preset = _coerce_layout_preset(int(preset_value))
	bind_layout(layout_root, reset_game, target_preset)

func _has_embedded_layout() -> bool:
	return has_node("BoardRoot")

func _get_card_display_parent() -> Node:
	if card_container != null:
		return card_container
	return self

func _reparent_card_displays() -> void:
	if card_container == null:
		_log_warn("[LayoutBind] Reparent requested but card_container is null")
		return
	var active_reparented := 0
	for display in card_displays:
		if not is_instance_valid(display):
			continue
		if display.get_parent() != card_container:
			var previous_parent := display.get_parent()
			display.reparent(card_container)
			if display.get_parent() != card_container:
				_log_error("[LayoutBind] Failed to reparent active display %s from %s" % [display.name, _debug_node_path(previous_parent)])
			else:
				active_reparented += 1
				_log_debug("[LayoutBind]", "Reparented active display", display.name, "->", _debug_node_path(card_container))
				_apply_orientation_to_display(display)
	var pooled_reparented := 0
	for pooled in card_display_pool:
		if not is_instance_valid(pooled):
			continue
		if pooled.get_parent() != card_container:
			var pooled_prev := pooled.get_parent()
			pooled.reparent(card_container)
			if pooled.get_parent() != card_container:
				_log_error("[LayoutBind] Failed to reparent pooled display %s from %s" % [pooled.name, _debug_node_path(pooled_prev)])
			else:
				pooled_reparented += 1
				_log_debug("[LayoutBind]", "Reparented pooled display", pooled.name, "->", _debug_node_path(card_container))
				_apply_orientation_to_display(pooled)
	_log_debug("[LayoutBind]", "Reparent summary", "active=", active_reparented, "pooled=", pooled_reparented)

func _apply_orientation_to_all_displays() -> void:
	for display in card_displays:
		_apply_orientation_to_display(display)
	for pooled in card_display_pool:
		_apply_orientation_to_display(pooled)

func _apply_orientation_to_display(display: FW_CardDisplay) -> void:
	if display == null:
		return
	if not is_instance_valid(display):
		return
	_apply_display_metrics(display)
	if display.has_method("set_layout_preset"):
		display.set_layout_preset(int(_current_layout_preset))

func _apply_win_label_orientation() -> void:
	if win_label == null:
		return
	match _current_layout_preset:
		LayoutPreset.PORTRAIT:
			win_label.rotation = 0.0
		LayoutPreset.LANDSCAPE:
			win_label.rotation = deg_to_rad(90.0)

func _coerce_layout_preset(value: int) -> LayoutPreset:
	var presets := LayoutPreset.values()
	if presets.is_empty():
		return LayoutPreset.PORTRAIT
	var clamped_index: int = max(0, min(value, presets.size() - 1))
	return presets[clamped_index] as LayoutPreset

func _layout_preset_to_string(preset: LayoutPreset) -> String:
	match preset:
		LayoutPreset.PORTRAIT:
			return "PORTRAIT"
		LayoutPreset.LANDSCAPE:
			return "LANDSCAPE"
		_:
			return str(int(preset))

func _resume_active_game_timer() -> void:
	if game_timer == null:
		_log_warn("[LayoutBind] Cannot resume timer; node missing")
		return
	if not game_in_progress:
		return
	if game_timer.is_stopped():
		game_timer.paused = false
		game_timer.start()
		_log_debug("[LayoutBind] Restarted game timer after layout swap")
	else:
		game_timer.paused = false
		_log_debug("[LayoutBind] Game timer already running after layout swap")

func get_layout_root() -> Node:
	return _layout_root

enum PileType {TABLEAU, FOUNDATION, STOCK, WASTE}

# Game state
var deck: FW_Deck
var tableau: Array[Array]  # 7 columns of cards
var foundations: Array[Array]  # 4 piles, one per suit
var stock: Array[FW_Card]
var waste: Array[FW_Card]
var card_locations: Dictionary = {}
var game_state: FW_GameState
var game_stats: FW_GameStats

# Performance caches
var foundation_suit_cache: Array[int] = []  # Pre-computed foundation suit mappings
var suit_to_foundation_cache: Dictionary = {}  # Reverse lookup: suit -> foundation index

# Object pooling for CardDisplay nodes
var card_display_pool: Array[FW_CardDisplay] = []  # Pool of reusable CardDisplay nodes
const CARD_POOL_SIZE: int = 52  # Standard deck size

# UI elements
var card_displays: Array[FW_CardDisplay] = []
var card_display_scene: PackedScene
var selected_cards: Array = []
var draw_three_cards: bool = false

# Game statistics
var move_count: int = 0
var start_time: float = 0.0
var elapsed_time: float = 0.0
var game_in_progress: bool = false
var game_completed: bool = false
var stock_cycles: int = 0  # Track how many times stock was recycled
var undo_count: int = 0  # Track number of undos
var used_auto_complete: bool = false  # Track if auto-complete was used
var waiting_for_win_dismiss: bool = false  # Track if we're waiting for user to dismiss win screen
var _stats_opened_from_victory: bool = false  # True if stats panel was opened as a result of a victory
var active_win_tweens: Array[Tween] = []  # Track active win animation tweens
var auto_complete_in_progress: bool = false  # Track if auto-complete animation is running
var victory_animation_playing: bool = false  # Track if victory celebration is playing
var auto_complete_card_count: int = 0  # Count cards moved during auto-complete for sound escalation
@export var AUTO_COMPLETE_DURATION_SCALE: float = 0.5
# Clamp the multiplier used to scale all auto-complete animation durations (0.0..1.0);
# smaller values speed up the sequence. 0.5 = ~50% faster.

# Layout constants
@export var CARD_WIDTH: float = 80
@export var CARD_HEIGHT: float = 120
@export var CARD_OFFSET_Y: float = 30  # Vertical offset for stacked cards
@export var CARD_GAP: float = 15

func _pile_type_name(pile_type: int) -> String:
	match pile_type:
		PileType.TABLEAU: return "TABLEAU"
		PileType.FOUNDATION: return "FOUNDATION"
		PileType.STOCK: return "STOCK"
		PileType.WASTE: return "WASTE"
		_: return "UNKNOWN"

func _log_debug(...args) -> void:
	FW_Debug.debug_log(args, FW_Debug.Level.VERBOSE)

func print(...args) -> void:
	FW_Debug.debug_log(args, FW_Debug.Level.INFO)

func _log_warn(message: String) -> void:
	FW_Debug.warn(message)

func _log_error(message: String) -> void:
	FW_Debug.error(message)

func _debug_node_path(node: Node) -> String:
	if node == null:
		return "<null>"
	if not is_instance_valid(node):
		return "<freed>"
	return node.get_path()

func _disable_all_interactions() -> void:
	"""Disable all UI interactions during animations (auto-complete, victory)"""
	_log_debug("[UI] Disabling all interactions")
	if new_game_button:
		new_game_button.disabled = true
	if undo_button:
		undo_button.disabled = true
	if auto_complete_button:
		auto_complete_button.disabled = true
	if draw_mode_toggle:
		draw_mode_toggle.disabled = true
	if layout_toggle_button:
		layout_toggle_button.disabled = true
	if view_stats_button:
		view_stats_button.disabled = true
	if stock_panel:
		stock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Disable card dragging
	if _drag_controller:
		_drag_controller.set_enabled(false)

func _enable_all_interactions() -> void:
	"""Re-enable all UI interactions for normal gameplay"""
	_log_debug("[UI] Enabling all interactions")
	if new_game_button:
		new_game_button.disabled = false
	if undo_button:
		undo_button.disabled = false
	if auto_complete_button:
		auto_complete_button.disabled = false
	if draw_mode_toggle:
		draw_mode_toggle.disabled = false
	if layout_toggle_button:
		layout_toggle_button.disabled = false
	if view_stats_button:
		view_stats_button.disabled = false
	if stock_panel:
		stock_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	if _drag_controller:
		_drag_controller.set_enabled(true)

func _enable_victory_interactions() -> void:
	"""Enable only safe interactions after victory (new game, view stats)"""
	_log_debug("[UI] Enabling victory interactions only")
	if new_game_button:
		new_game_button.disabled = false
	if view_stats_button:
		view_stats_button.disabled = false
	# Keep game-related interactions disabled
	if undo_button:
		undo_button.disabled = true
	if auto_complete_button:
		auto_complete_button.disabled = true
	if draw_mode_toggle:
		draw_mode_toggle.disabled = true
	if layout_toggle_button:
		layout_toggle_button.disabled = true
	if stock_panel:
		stock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _drag_controller:
		_drag_controller.set_enabled(false)

func _debug_log_layout_info(context: String) -> void:
	var active_total := 0
	var active_orphaned := 0
	var sample_index := 0
	for display in card_displays:
		if not is_instance_valid(display):
			continue
		active_total += 1
		var parent := display.get_parent()
		if sample_index < 5:
			var parent_path := "<null>" if parent == null else _debug_node_path(parent)
			_log_debug("[LayoutDiag]", "sample_active", sample_index, display.name, "parent=", parent_path)
			sample_index += 1
		if parent != card_container:
			active_orphaned += 1
	var pooled_total := 0
	var pooled_orphaned := 0
	for pooled in card_display_pool:
		if not is_instance_valid(pooled):
			continue
		pooled_total += 1
		var pooled_parent := pooled.get_parent()
		if pooled_parent != card_container:
			pooled_orphaned += 1
	_log_debug("[LayoutDiag]", context)
	_log_debug("[LayoutDiag]", "layout_root=", _debug_node_path(_layout_root), "card_container=", _debug_node_path(card_container), "preset=", _layout_preset_to_string(_current_layout_preset))
	_log_debug("[LayoutDiag]", "active_displays=", active_total, "orphaned=", active_orphaned, "pooled=", pooled_total, "pooled_orphaned=", pooled_orphaned)

func _configure_static_ui() -> void:
	if card_container == null:
		_log_warn("Card container not found; falling back to root node")
		win_label.visible = false
		win_label.text = "🎉 YOU WIN! 🎉"
		win_label.z_index = 1005  # High z-index to be above the background panel
		win_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		win_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		win_label.grow_vertical = Control.GROW_DIRECTION_BOTH
		win_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to background

	# Always apply win_label styling regardless of card_container state
	if win_label != null:
		win_label.add_theme_font_size_override("font_size", 42)
		win_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 1.0))  # Bright yellow
		win_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		win_label.add_theme_constant_override("outline_size", 12)  # Thicker outline
		_log_debug("Applied win_label styling: font_size=42, bright yellow color, outline_size=12")
	if win_bg_panel != null:
		win_bg_panel.visible = false
		win_bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Make clickable to dismiss win screen
		win_bg_panel.z_index = 900  # Behind win_label but above cards
		var win_bg_style := StyleBoxFlat.new()
		win_bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.3)  # Less dim background
		win_bg_panel.add_theme_stylebox_override("panel", win_bg_style)
		# Connect click handler for dismissing win screen
		if not win_bg_panel.gui_input.is_connected(_on_win_bg_clicked):
			win_bg_panel.gui_input.connect(_on_win_bg_clicked)
	if new_game_button != null and not new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.connect(_on_new_game_pressed)
	if undo_button != null and not undo_button.pressed.is_connected(_on_undo_pressed):
		undo_button.pressed.connect(_on_undo_pressed)
	if auto_complete_button != null:
		auto_complete_button.visible = false  # Start hidden, show when available
		auto_complete_button.disabled = false  # No need to disable when hidden
		auto_complete_button.tooltip_text = "Automatically complete the game when all remaining moves are obvious"
		if not auto_complete_button.pressed.is_connected(_on_auto_complete_pressed):
			auto_complete_button.pressed.connect(_on_auto_complete_pressed)
	if draw_mode_toggle != null:
		draw_mode_toggle.tooltip_text = "Toggle between drawing 1 or 3 cards from the stock"
		if not draw_mode_toggle.toggled.is_connected(_on_draw_mode_toggled):
			draw_mode_toggle.toggled.connect(_on_draw_mode_toggled)
	if layout_toggle_button != null:
		layout_toggle_button.text = "  Swap Layout  "
		layout_toggle_button.tooltip_text = "Switch between portrait and landscape UI"
		if not layout_toggle_button.pressed.is_connected(_on_layout_toggle_pressed):
			layout_toggle_button.pressed.connect(_on_layout_toggle_pressed)
	if view_stats_button != null and not view_stats_button.pressed.is_connected(_on_view_stats_pressed):
		view_stats_button.pressed.connect(_on_view_stats_pressed)
	if stats_label != null:
		stats_label.add_theme_font_size_override("font_size", 20)
	if stock_panel != null and not stock_panel.gui_input.is_connected(_on_stock_gui_input):
		stock_panel.gui_input.connect(_on_stock_gui_input)
	if stock_texture != null:
		stock_texture.texture = CARD_BACK_TEXTURE
	_configure_slot_styles()
	if game_timer != null and not game_timer.timeout.is_connected(_on_timer_timeout):
		game_timer.timeout.connect(_on_timer_timeout)
	if game_timer != null:
		game_timer.autostart = false
	if stats_slide_in != null and stats_slide_in.has_signal("back_button"):
		var callable := Callable(self, "_on_stats_slide_in_back_button")
		var signal_ref = stats_slide_in.back_button
		if not signal_ref.is_connected(callable):
			signal_ref.connect(callable)
	if back_button != null and not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

func _configure_slot_styles() -> void:
	_configure_stock_panel()
	_configure_waste_panel()
	for f_idx in range(foundation_slots.size()):
		_configure_foundation_slot(f_idx)
	for col in range(tableau_slots.size()):
		_configure_tableau_slot(col)

func _configure_stock_panel() -> void:
	if stock_panel == null:
		return
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.3)
	style_box.border_color = Color(0.3, 0.5, 0.8, 0.8)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(8)
	stock_panel.add_theme_stylebox_override("panel", style_box)
	stock_panel.clip_contents = true
	stock_panel.tooltip_text = "Draw from the stock. When empty, click to recycle the waste."
	if stock_texture != null:
		stock_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		stock_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stock_texture.anchor_left = 0.0
		stock_texture.anchor_top = 0.0
		stock_texture.anchor_right = 1.0
		stock_texture.anchor_bottom = 1.0
		stock_texture.offset_left = 0.0
		stock_texture.offset_top = 0.0
		stock_texture.offset_right = 0.0
		stock_texture.offset_bottom = 0.0

func _configure_waste_panel() -> void:
	if waste_panel == null:
		return
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.3)
	style_box.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(8)
	waste_panel.add_theme_stylebox_override("panel", style_box)
	waste_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waste_panel.tooltip_text = "Waste pile. Drag or double-click the top card to play it."

func _configure_foundation_slot(index: int) -> void:
	if index < 0 or index >= foundation_slots.size():
		return
	var slot := foundation_slots[index]
	if slot == null:
		return
	slot.z_index = -1
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.3)
	style_box.border_color = Color(0.7, 0.6, 0.2, 0.8)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", style_box)
	slot.set_meta("suit", _get_foundation_suit(index))
	slot.tooltip_text = "Foundation: build up " + _get_foundation_suit_name(_get_foundation_suit(index)).capitalize()
	var emoji_label := slot.get_node_or_null("EmojiLabel") as Label
	if emoji_label == null:
		emoji_label = Label.new()
		emoji_label.name = "EmojiLabel"
		emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(emoji_label)
	emoji_label.position = Vector2(0, 0)
	emoji_label.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.add_theme_font_size_override("font_size", 36)
	emoji_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.2, 0.6))
	emoji_label.text = _get_foundation_emoji(_get_foundation_suit(index))

func _configure_tableau_slot(index: int) -> void:
	if index < 0 or index >= tableau_slots.size():
		return
	var slot := tableau_slots[index]
	if slot == null:
		return
	slot.z_index = -1
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.3)
	style_box.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", style_box)
	var label := slot.get_node_or_null("PlaceholderLabel") as Label
	if label == null:
		label = Label.new()
		label.name = "PlaceholderLabel"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
	label.position = Vector2(0, 0)
	label.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
	label.text = "K"


func _board_offset() -> Vector2:
	return Vector2.ZERO


func _slot_local_position(slot: Control) -> Vector2:
	if slot == null:
		return Vector2.ZERO

	# Get the slot's global center position
	var slot_global_center := slot.get_global_transform_with_canvas() * (slot.size * 0.5)

	# Transform to card_container's local space
	var container_inv := card_container.get_global_transform_with_canvas().affine_inverse()
	var center_local := container_inv * slot_global_center

	# Cards are placed at top-left corner, so subtract half card size
	# Use the actual card visual dimensions (which swap in landscape mode due to rotation)
	var card_half := Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)
	return center_local - card_half

func _slot_local_axes(slot: Control) -> Dictionary:
	var default_axes := {
		"origin": Vector2.ZERO,
		"x_axis": Vector2.RIGHT,
		"y_axis": Vector2.DOWN
	}
	if slot == null:
		return default_axes
	var slot_transform := slot.get_global_transform_with_canvas()
	var container_transform := card_container.get_global_transform_with_canvas() if card_container != null else Transform2D.IDENTITY
	var container_inverse := container_transform.affine_inverse()
	var origin := container_inverse * slot_transform.origin
	var x_axis_point := container_inverse * (slot_transform.origin + slot_transform.x)
	var y_axis_point := container_inverse * (slot_transform.origin + slot_transform.y)
	default_axes["origin"] = origin
	default_axes["x_axis"] = x_axis_point - origin
	default_axes["y_axis"] = y_axis_point - origin
	return default_axes

func _format_vec(vec: Vector2) -> String:
	return "(%.2f, %.2f)" % [vec.x, vec.y]

func _debug_dump_slot_axes(label: String, slot: Control) -> void:
	if slot == null:
		_log_debug("[SlotDiag]", label, "slot=<null>")
		return
	var axes := _slot_local_axes(slot)
	var origin: Vector2 = axes.get("origin", Vector2.ZERO)
	var x_axis: Vector2 = axes.get("x_axis", Vector2.RIGHT)
	var y_axis: Vector2 = axes.get("y_axis", Vector2.DOWN)
	var aligned_top_left := _slot_local_position(slot)
	var aligned_center := aligned_top_left + Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)
	_log_debug("[SlotDiag]", label,
		"name=" + slot.name,
		"rotation=%.2f" % rad_to_deg(slot.rotation),
		"rect=" + str(slot.get_rect()),
		"origin=" + _format_vec(origin),
		"x_axis=" + _format_vec(x_axis),
		"y_axis=" + _format_vec(y_axis),
		"card_top_left=" + _format_vec(aligned_top_left),
		"card_center=" + _format_vec(aligned_center)
	)

func _debug_log_slot_alignment(context: String) -> void:
	_log_debug("[SlotDiag]", context, "preset=" + _layout_preset_to_string(_current_layout_preset))
	_debug_dump_slot_axes("stock_panel", stock_panel)
	_debug_dump_slot_axes("waste_panel", waste_panel)
	for idx in range(foundation_slots.size()):
		_debug_dump_slot_axes("foundation_%d" % idx, foundation_slots[idx])
	for col in range(tableau_slots.size()):
		_debug_dump_slot_axes("tableau_%d" % col, tableau_slots[col])

func _axis_step(axis: Vector2, distance: float) -> Vector2:
	if axis.length_squared() < 0.0001:
		return Vector2.ZERO
	return axis.normalized() * distance


func _tableau_position(col: int, row: int) -> Vector2:
	var slot := tableau_slots[col]
	var axes := _slot_local_axes(slot)
	var base := _slot_local_position(slot)
	var stack_axis: Vector2 = axes.get("y_axis", Vector2.DOWN)
	return base + _axis_step(stack_axis, row * CARD_OFFSET_Y)


func _foundation_position(f_idx: int) -> Vector2:
	var slot := foundation_slots[f_idx]
	return _slot_local_position(slot)


func _stock_position() -> Vector2:
	return _slot_local_position(stock_panel)


func _waste_position() -> Vector2:
	return _slot_local_position(waste_panel)

func _cancel_active_card_tween(card_display: FW_CardDisplay) -> void:
	if not is_instance_valid(card_display):
		return
	if not card_display.has_meta(CARD_TWEEN_META_KEY):
		return
	var tween: Tween = card_display.get_meta(CARD_TWEEN_META_KEY)
	if is_instance_valid(tween):
		tween.kill()
	card_display.remove_meta(CARD_TWEEN_META_KEY)

func _create_card_tween(card_display: FW_CardDisplay) -> Tween:
	_cancel_active_card_tween(card_display)
	var tween := create_tween()
	if tween == null:
		return null
	card_display.set_meta(CARD_TWEEN_META_KEY, tween)
	tween.finished.connect(func():
		if not is_instance_valid(card_display):
			return
		if not card_display.has_meta(CARD_TWEEN_META_KEY):
			return
		if card_display.get_meta(CARD_TWEEN_META_KEY) != tween:
			return
		card_display.remove_meta(CARD_TWEEN_META_KEY)
	)
	return tween

func _ready() -> void:
	FW_Debug.set_level(_debug_level_storage)
	FW_Debug.enabled = false
	game_state = FW_GameState.new()
	game_stats = FW_GameStats.new()
	_drag_controller = FW_SolitaireDragController.new(self)
	_initialize_foundation_caches()  # Pre-compute foundation lookups
	_load_solitaire_settings()
	if _layout_root == null and _has_embedded_layout():
		bind_layout(self, true)

func _load_solitaire_settings() -> void:
	_log_debug("Loading solitaire settings from", SETTINGS_PATH)
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		_log_debug("Settings file not found, using defaults")
		draw_three_cards = false
		_sync_draw_mode_toggle()
		return
	var stored_value = config.get_value(SETTINGS_SECTION_OPTIONS, SETTINGS_KEY_DRAW_THREE, draw_three_cards)
	if typeof(stored_value) == TYPE_BOOL:
		draw_three_cards = stored_value
	else:
		draw_three_cards = bool(stored_value)
	_log_debug("Loaded draw_three_cards", draw_three_cards)
	_sync_draw_mode_toggle()

func _save_solitaire_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		_log_debug("Creating new solitaire settings file at", SETTINGS_PATH)
		config = ConfigFile.new()
	config.set_value(SETTINGS_SECTION_OPTIONS, SETTINGS_KEY_DRAW_THREE, draw_three_cards)
	var save_err := config.save(SETTINGS_PATH)
	if save_err != OK:
		_log_error("Failed to save solitaire settings: %s" % save_err)
	else:
		_log_debug("Saved draw_three_cards setting", draw_three_cards)
	_sync_draw_mode_toggle()

func _sync_draw_mode_toggle() -> void:
	if not draw_mode_toggle:
		return
	var label = "3-Card Deal" if draw_three_cards else "1-Card Deal"
	if draw_mode_toggle.text != label:
		draw_mode_toggle.text = label
	if draw_mode_toggle.button_pressed != draw_three_cards:
		draw_mode_toggle.button_pressed = draw_three_cards

func _on_draw_mode_toggled(pressed: bool) -> void:
	# Prevent draw mode change during animations
	if auto_complete_in_progress or victory_animation_playing:
		_log_debug("Draw mode toggle blocked - animation in progress")
		# Reset toggle to previous state
		if draw_mode_toggle:
			draw_mode_toggle.button_pressed = draw_three_cards
		return

	_log_debug("Draw mode toggled", pressed)
	draw_three_cards = pressed
	_save_solitaire_settings()
	update_waste_display()

func _on_view_stats_pressed() -> void:
	# Allow viewing stats unless actively animating
	if auto_complete_in_progress or victory_animation_playing:
		_log_debug("View stats blocked - animation in progress")
		return

	_log_debug("=== View stats button pressed ===")
	# Player explicitly opened stats from UI (not from a win dismissal)
	_stats_opened_from_victory = false
	show_stats_panel()

func _on_layout_toggle_pressed() -> void:
	# Prevent layout toggle during animations
	if auto_complete_in_progress or victory_animation_playing:
		_log_debug("Layout toggle blocked - animation in progress")
		return

	_log_debug("Layout toggle button pressed")
	_debug_log_layout_info("pre_toggle_button")
	var root := get_parent()
	if root != null and root.has_method("toggle_layout"):
		root.toggle_layout()
		call_deferred("_debug_log_layout_info", "post_toggle_button_deferred")
		return
	var manager := get_tree().root.get_node_or_null("LayoutManager")
	if manager != null and manager.has_method("toggle_layout"):
		manager.toggle_layout()
		call_deferred("_debug_log_layout_info", "post_toggle_manager_deferred")
		return
	_log_warn("Layout toggle requested but layout manager not found")

#func _notification(what: int) -> void:
	#if what == NOTIFICATION_RESIZED:
		#if tableau == null or tableau.size() == 0:
			#return
		#refresh_all_card_positions()

func initialize_game() -> void:
	var start_time_ms := Time.get_ticks_msec()
	_log_debug("=== initialize_game() START ===")

	# Clear previous game
	clear_board()
	if win_label != null:
		win_label.visible = false
	if win_bg_panel != null:
		win_bg_panel.visible = false
	card_locations.clear()
	if game_state:
		game_state.clear()

	# Re-enable undo button
	if undo_button:
		undo_button.disabled = false

	# Hide auto-complete until it becomes available
	if auto_complete_button:
		auto_complete_button.visible = false

	# Reset statistics
	move_count = 0
	start_time = Time.get_ticks_msec() / 1000.0
	elapsed_time = 0.0
	game_in_progress = true
	game_completed = false
	stock_cycles = 0
	undo_count = 0
	used_auto_complete = false
	waiting_for_win_dismiss = false  # Reset win dismissal flag
	auto_complete_in_progress = false  # Reset auto-complete flag
	victory_animation_playing = false  # Reset victory animation flag
	auto_complete_card_count = 0  # Reset card count

	# Re-enable all interactions for new game
	_enable_all_interactions()

	if game_timer:
		game_timer.start()
	update_stats_display()

	# Create new deck
	deck = FW_Deck.new()

	# Initialize piles
	tableau.resize(7)
	for i in range(7):
		tableau[i] = []
	foundations.resize(FOUNDATION_SUIT_ORDER.size())
	for i in range(FOUNDATION_SUIT_ORDER.size()):
		foundations[i] = []
	stock = []
	waste = []

	# Deal cards to tableau
	for col in range(tableau.size()):
		for row in range(col + 1):
			var card = deck.draw()
			if card:
				tableau[col].append(card)
				set_card_location(card, PileType.TABLEAU, col)
				# All cards start face-down, we'll flip them during animation
				card.face_up = false

	# Remaining cards to stock
	while not deck.is_empty():
		var stock_card: FW_Card = deck.draw()
		if stock_card:
			stock.append(stock_card)
			set_card_location(stock_card, PileType.STOCK, 0)

	# Create UI with animated dealing
	create_board_ui()
	# Start dealing animation after UI is created
	animate_initial_deal()

	var elapsed_ms := Time.get_ticks_msec() - start_time_ms
	_log_debug("=== initialize_game() END - took %d ms ===" % elapsed_ms)

func clear_board() -> void:
	# Return all card displays to the pool instead of destroying them
	for display in card_displays:
		if is_instance_valid(display):
			_return_card_display_to_pool(display)
	card_displays.clear()
	selected_cards.clear()

	# Clean up any card displays not in our tracking (shouldn't happen, but be safe)
	var parent: Node = self
	if card_container != null:
		parent = card_container
	for child in parent.get_children():
		if child is FW_CardDisplay and not card_displays.has(child):
			_return_card_display_to_pool(child)

func create_board_ui() -> void:
	var start_time_ms := Time.get_ticks_msec()
	_log_debug("Creating board UI")

	for col in range(tableau.size()):
		for row in range(tableau[col].size()):
			var card = tableau[col][row]

			# Get display from pool instead of instantiating
			var display = _get_card_display_from_pool()
			if display == null:
				continue

			display.card = card
			display.position = _tableau_position(col, row)
			display.z_index = 10 + (col * 20) + row

			# Set clickable height based on whether this card has cards above it
			var is_top_card = (row == tableau[col].size() - 1)
			if is_top_card:
				# Top card is fully clickable
				display.set_clickable_height(0)
			else:
				# Cards with cards above them are only clickable in visible area
				display.set_clickable_height(CARD_OFFSET_Y)

			card_displays.append(display)
			_log_debug("Col %d Row %d: %s at pos %s z=%d face_up=%s" % [col, row, card._to_string(), display.position, display.z_index, card.face_up])

	update_stock_count()
	update_waste_display()
	_update_static_slot_positions()

	# Sort card displays by z-index to ensure proper input order
	# Cards with higher z-index should be later in tree (processed first for input)
	_sort_displays_by_z_index()

	var elapsed_ms := Time.get_ticks_msec() - start_time_ms
	_log_debug("Board UI created - %d displays in %d ms" % [card_displays.size(), elapsed_ms])

func _sort_displays_by_z_index() -> void:
	"""Sort card displays in the scene tree by z-index for correct input order"""
	var parent: Node = _get_card_display_parent()
	if not parent:
		return

	# Create a sorted list of displays by z-index
	var sorted_displays = card_displays.duplicate()
	sorted_displays.sort_custom(func(a, b): return a.z_index < b.z_index)

	# Reorder children in the scene tree
	for display in sorted_displays:
		if display.get_parent() == parent:
			parent.move_child(display, -1)  # Move to end (highest z-index processed first)


func _update_static_slot_positions() -> void:
	if tableau == null or tableau.size() == 0:
		return
	if stock_panel != null:
		stock_panel.pivot_offset = stock_panel.size * 0.5

func get_movable_sequence(card_display: FW_CardDisplay) -> Array:
	"""Get valid sequence starting from the given card - original behavior"""
	var card = card_display.card
	if not card or not card.face_up:
		return []
	var location = get_card_location(card)
	if location.is_empty() or location.get("pile") != PileType.TABLEAU:
		return [card_display]
	var col = location.get("index")
	var column_cards = tableau[col]
	var start_idx = column_cards.find(card)
	if start_idx == -1:
		return [card_display]

	# Validate the sequence is properly alternating colors and descending ranks
	var sequence = [card_display]
	for i in range(start_idx + 1, column_cards.size()):
		var c = column_cards[i]
		var prev_card = column_cards[i-1]

		# Must be face up
		if not c.face_up:
			break

		# Must properly stack (alternating colors, one rank lower)
		if not c.can_stack_on_tableau(prev_card):
			break

		var display = get_display_for_card(c)
		if display:
			sequence.append(display)
		else:
			# If we can't find the display, stop the sequence here
			break

	return sequence

func get_smart_movable_sequence(card_display: FW_CardDisplay) -> Array:
	"""Get movable sequence - just delegates to original implementation

	The "smart" behavior for mobile is handled by making hit detection more forgiving,
	not by changing which cards get selected. This ensures correct game logic."""
	return get_movable_sequence(card_display)

func _on_card_drag_started(card_display: FW_CardDisplay) -> void:
	if _drag_controller == null:
		card_display.is_dragging = false
		return
	_drag_controller.on_drag_started(card_display)

func _on_card_drag_ended(card_display: FW_CardDisplay, _dropped_on: Control) -> void:
	if _drag_controller == null:
		return
	_drag_controller.on_drag_ended(card_display)
func move_card_to_tableau(displays: Array, col: int) -> void:
	if displays.is_empty():
		return
	var cards = []
	for d in displays:
		if d.card:
			cards.append(d.card)
	if cards.is_empty():
		return
	var first_card = cards[0]

	_log_debug("=== move_card_to_tableau() ===")
	_log_debug("Moving", cards.size(), "card(s) to tableau column", col)
	_log_debug("First card", first_card._to_string())

	# Store the previous location before removing
	var previous_location = get_card_location(first_card)
	_log_debug("Previous location", previous_location)

	# Track revealed card - ONLY if a card gets flipped from face-down to face-up
	var revealed_card: FW_Card = null

	# Remove all cards from their source piles manually (don't use remove_card_from_current_pile)
	# This prevents update_waste_display from being called prematurely
	var was_from_waste = false
	for card in cards:
		var loc = get_card_location(card)
		if loc.is_empty():
			continue

		match loc.get("pile", -1):
			PileType.TABLEAU:
				var src_col: int = loc.get("index", -1)
				if src_col != -1:
					tableau[src_col].erase(card)
					if not tableau[src_col].is_empty():
						var top_card: FW_Card = tableau[src_col].back()
						if not top_card.face_up:
							top_card.face_up = true
							revealed_card = top_card
							var top_display: FW_CardDisplay = get_display_for_card(top_card)
							if top_display != null:
								flip_card_animation(top_display)
			PileType.FOUNDATION:
				# Moving from foundation to tableau
				var src_f_idx: int = loc.get("index", -1)
				if src_f_idx != -1:
					_log_debug("Removing card from foundation", src_f_idx)
					foundations[src_f_idx].erase(card)
					# Show the card that was beneath this one in the foundation
					if not foundations[src_f_idx].is_empty():
						var revealed = foundations[src_f_idx].back()
						var revealed_display = get_display_for_card(revealed)
						if revealed_display:
							_log_debug("Revealing foundation card beneath", revealed._to_string())
							revealed_display.visible = true
							revealed_display.position = _foundation_position(src_f_idx)
							revealed_display.z_index = 200 + src_f_idx
							revealed_display.refresh()
			PileType.WASTE:
				waste.erase(card)
				was_from_waste = true
				# Don't call update_waste_display yet!
			PileType.STOCK:
				stock.erase(card)
				update_stock_count()

		card_locations.erase(card)

	# Add all cards to the destination tableau
	for c in cards:
		tableau[col].append(c)
		set_card_location(c, PileType.TABLEAU, col)

	# Refresh waste immediately so the next card becomes interactive
	if was_from_waste:
		update_waste_display()

	# Record move in history
	if game_state and not previous_location.is_empty():
		var move = FW_GameState.Move.new(first_card)
		var typed_cards: Array[FW_Card] = []
		typed_cards.assign(cards)
		move.cards_moved = typed_cards
		move.source_pile = previous_location.get("pile", -1)
		move.source_index = previous_location.get("index", -1)
		move.dest_pile = PileType.TABLEAU
		move.dest_index = col
		move.revealed_card = revealed_card
		game_state.add_move(move)
		move_count += 1
		update_stats_display()

	# Animate cards to new positions - pass the was_from_waste flag
	animate_tableau_cards(displays, col, was_from_waste)

	# Update the source pile if it was tableau - do this IMMEDIATELY to fix z-indices
	if not previous_location.is_empty() and previous_location.get("pile", -1) == PileType.TABLEAU:
		var prev_col: int = previous_location.get("index", -1)
		if prev_col != -1 and prev_col != col:
			update_tableau_positions(prev_col)

	check_win()
	check_auto_complete_available()

func animate_tableau_cards(displays: Array, col: int, was_from_waste: bool = false) -> void:
	for i in range(displays.size()):
		var d = displays[i]
		var row_index = tableau[col].size() - displays.size() + i
		var target_pos = _tableau_position(col, row_index)
		var target_z_index = 10 + (col * 20) + row_index

		# CRITICAL: Set z-index immediately to prevent visual artifacts
		# This ensures the card is above all others during animation
		d.z_index = 1000 + i  # Use very high temporary z-index during animation
		d.move_to_front()  # Ensure node is at top of render tree

		var tween = _create_card_tween(d)
		if tween == null:
			continue
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)

		# Play a card move sound for each animated card
		SoundManager._play_random_card_sound()
		tween.tween_property(d, "position", target_pos, 0.2)
		tween.parallel().tween_property(d, "z_index", target_z_index, 0.2)

		# Ensure card is visible and properly rendered
		# Capture d as a local variable to avoid reference issues
		var display_ref = d
		var is_last = (i == displays.size() - 1)
		var captured_row = row_index
		var captured_col = col
		tween.finished.connect(func():
			if is_instance_valid(display_ref):
				display_ref.modulate = Color(1.0, 1.0, 1.0, 1.0)
				display_ref.refresh()

				# Update clickable height after animation
				var is_top_card = (captured_row == tableau[captured_col].size() - 1)
				if is_top_card:
					display_ref.set_clickable_height(0)
				else:
					display_ref.set_clickable_height(CARD_OFFSET_Y)
			# Only update waste display once, after the last card animation finishes
			if was_from_waste and is_last:
				update_waste_display()
		)


func move_card_to_foundation(card_display: FW_CardDisplay, f_idx: int) -> void:
	var card: FW_Card = card_display.card
	if not card:
		return

	_log_debug("Moving", card._to_string(), "to foundation", f_idx)

	# Store reference before removing from pile
	var previous_location = get_card_location(card)

	# Check if coming from waste - we'll need this later
	var was_from_waste = previous_location.get("pile", -1) == PileType.WASTE

	# Hide any previous top card in the foundation (it should be beneath the new card)
	if not foundations[f_idx].is_empty():
		var prev_top = foundations[f_idx].back()
		var prev_display = get_display_for_card(prev_top)
		if prev_display:
			prev_display.visible = false  # Hide the card beneath
			_log_debug("Hiding", prev_top._to_string(), "beneath new card")

	# Remove from source pile AFTER getting the display
	# This is important: we need to update the data structures but NOT free the display yet
	match previous_location.get("pile", -1):
		PileType.TABLEAU:
			var col: int = previous_location.get("index", -1)
			if col != -1:
				tableau[col].erase(card)
				if not tableau[col].is_empty():
					var top_card: FW_Card = tableau[col].back()
					if not top_card.face_up:
						top_card.face_up = true
						var top_display: FW_CardDisplay = get_display_for_card(top_card)
						if top_display != null:
							flip_card_animation(top_display)
				update_tableau_positions(col)
		PileType.FOUNDATION:
			# Moving from one foundation to another (shouldn't happen in solitaire, but handle it)
			var source_f_idx: int = previous_location.get("index", -1)
			if source_f_idx != -1:
				foundations[source_f_idx].erase(card)
				# Show the card that was beneath this one
				if not foundations[source_f_idx].is_empty():
					var revealed = foundations[source_f_idx].back()
					var revealed_display = get_display_for_card(revealed)
					if revealed_display:
						revealed_display.visible = true
						revealed_display.refresh()
		PileType.WASTE:
			waste.erase(card)
			# Don't call update_waste_display yet - it would free our card_display!
		PileType.STOCK:
			stock.erase(card)
			update_stock_count()

	# Add to foundation
	foundations[f_idx].append(card)
	set_card_location(card, PileType.FOUNDATION, f_idx)

	# Ensure card is visible and set high z-index during animation
	card_display.visible = true
	card_display.z_index = 1000  # Very high during move to stay on top

	# CRITICAL: If moving from waste, update waste display NOW before animation
	# This ensures the next waste card (if any) becomes visible immediately
	# The high z-index ensures our animating card stays on top
	if was_from_waste:
		update_waste_display()

	# Record move in history
	if game_state and not previous_location.is_empty():
		var move = FW_GameState.Move.new(card)
		move.cards_moved.append(card)
		move.source_pile = previous_location.get("pile", -1)
		move.source_index = previous_location.get("index", -1)
		move.dest_pile = PileType.FOUNDATION
		move.dest_index = f_idx
		game_state.add_move(move)
		move_count += 1
		update_stats_display()

	# Position at foundation with animation
	var target_pos = _foundation_position(f_idx)

	_cancel_active_card_tween(card_display)
	var tween = _create_card_tween(card_display)
	if tween == null:
		return

	# Play a card-move sound for moves into foundation
	SoundManager._play_random_card_sound()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(card_display, "position", target_pos, 0.2)
	tween.parallel().tween_property(card_display, "z_index", 200 + f_idx, 0.2)

	# Add a success "pop"
	tween.parallel().tween_property(card_display, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(card_display, "scale", Vector2(1.0, 1.0), 0.1)

	# Ensure card is visible and properly rendered
	# Capture card_display as a local variable to avoid reference issues
	var display_ref = card_display
	tween.finished.connect(func():
		if is_instance_valid(display_ref):
			display_ref.modulate = Color(1.0, 1.0, 1.0, 1.0)
			display_ref.refresh()
		# Note: We already called update_waste_display() before animation, no need to call again
		check_win()
		check_auto_complete_available()
	)


func check_win() -> void:
	if is_winner():
		win_label.visible = true
		game_timer.stop()

		# Disable undo button
		if undo_button:
			undo_button.disabled = true

		# Hide auto-complete button on win
		if auto_complete_button:
			auto_complete_button.visible = false

		# Record the win
		record_game_completion(true)

		celebrate_victory()

func update_tableau_positions(col: int) -> void:
	for row in range(tableau[col].size()):
		var display = get_display_for_card(tableau[col][row])
		if display:
			display.position = _tableau_position(col, row)
			# Update z_index for proper stacking - base of 10 plus column offset
			display.z_index = 10 + (col * 20) + row

			# Update clickable height based on card position
			var is_top_card = (row == tableau[col].size() - 1)
			if is_top_card:
				display.set_clickable_height(0)  # Full height
			else:
				display.set_clickable_height(CARD_OFFSET_Y)  # Only visible portion

func get_display_for_card(card: FW_Card) -> FW_CardDisplay:
	for display in card_displays:
		if display.card == card:
			return display
	return null

func _ensure_card_display(card: FW_Card) -> FW_CardDisplay:
	var existing := get_display_for_card(card)
	if existing:
		return existing

	# Get display from pool instead of instantiating
	var display = _get_card_display_from_pool()
	if display == null:
		return null

	display.card = card
	display.position = _waste_position()
	display.z_index = 100
	_apply_orientation_to_display(display)
	card_displays.append(display)
	return display

func reset_card_position(card_display: FW_CardDisplay) -> void:
	var card: FW_Card = card_display.card
	if not card:
		return
	var location: Dictionary = get_card_location(card)
	if location.is_empty():
		return
	var pile_type = int(location.get("pile", -1))
	match pile_type:
		PileType.TABLEAU:
			var col: int = location.get("index", -1)
			if col == -1:
				return
			var row := tableau[col].find(card)
			if row == -1:
				if tableau[col].is_empty():
					return
				row = tableau[col].size() - 1
			card_display.position = _tableau_position(col, row)
		PileType.FOUNDATION:
			var f_idx: int = location.get("index", -1)
			if f_idx == -1:
				return
			card_display.position = _foundation_position(f_idx)
		PileType.WASTE:
			var layout = _calculate_waste_layout()
			var info: Dictionary = {}
			if layout.has(card):
				info = layout[card]
			card_display.position = info.get("position", _waste_position())
			card_display.z_index = info.get("z_index", 100)
			var waste_rotation: float = float(info.get("rotation", card_display.get_extra_rotation()))
			card_display.set_extra_rotation(waste_rotation)
			var is_top = info.get("is_top", false)
			card_display.mouse_filter = Control.MOUSE_FILTER_STOP if is_top else Control.MOUSE_FILTER_IGNORE
			card_display.visible = info.get("visible", card_display.visible)
		PileType.STOCK:
			card_display.position = _stock_position()
		_:
			return

func get_card_location(card: FW_Card) -> Dictionary:
	if not card_locations.has(card):
		return {}
	return card_locations[card]

func set_card_location(card: FW_Card, pile_type: PileType, index: int) -> void:
	card_locations[card] = {"pile": pile_type, "index": index}

func remove_card_from_current_pile(card: FW_Card) -> Dictionary:
	var location: Dictionary = get_card_location(card)
	if location.is_empty():
		return location
	var pile_type: int = location.get("pile", -1)
	match pile_type:
		PileType.TABLEAU:
			var col: int = location.get("index", -1)
			if col != -1:
				var column_cards: Array = tableau[col]
				var idx := column_cards.find(card)
				if idx != -1:
					column_cards.remove_at(idx)
					tableau[col] = column_cards
					if not column_cards.is_empty():
						var top_card: FW_Card = column_cards.back()
						if not top_card.face_up:
							top_card.face_up = true
							var top_display: FW_CardDisplay = get_display_for_card(top_card)
							if top_display != null:
								flip_card_animation(top_display)
					update_tableau_positions(col)
		PileType.FOUNDATION:
			var foundation_idx: int = location.get("index", -1)
			if foundation_idx != -1:
				foundations[foundation_idx].erase(card)
		PileType.STOCK:
			stock.erase(card)
			update_stock_count()
		PileType.WASTE:
			waste.erase(card)
			# Important: update waste display to show next card or hide if empty
			update_waste_display()
	card_locations.erase(card)
	return location

func can_drag_card(card: FW_Card) -> bool:
	# Do not allow dragging if the game has been completed (win/loss)
	if game_completed:
		return false
	if not card or not card.face_up:
		return false
	var location: Dictionary = get_card_location(card)
	if location.is_empty():
		return false
	var pile_type: int = location.get("pile", -1)
	match pile_type:
		PileType.TABLEAU:
			var col: int = location.get("index", -1)
			if col == -1 or tableau[col].is_empty():
				return false
			# For tableau, the card must be face-up
			# We allow dragging sequences from tableau
			var card_idx = tableau[col].find(card)
			if card_idx == -1:
				return false
			# Verify all cards below this one form a valid sequence
			for i in range(card_idx + 1, tableau[col].size()):
				var c = tableau[col][i]
				var prev = tableau[col][i - 1]
				if not c.face_up or not c.can_stack_on_tableau(prev):
					return false
			return true
		PileType.FOUNDATION:
			var foundation_idx: int = location.get("index", -1)
			if foundation_idx == -1 or foundations[foundation_idx].is_empty():
				return false
			return foundations[foundation_idx].back() == card
		PileType.WASTE:
			return not waste.is_empty() and waste.back() == card
		_:
			return false

func can_move_to_tableau(card: FW_Card, tableau_col: int) -> bool:
	if tableau[tableau_col].is_empty():
		var is_king = card.rank == FW_Card.Rank.KING
		_log_debug("  can_move_to_tableau: empty column, card is king:", is_king)
		return is_king  # Only kings can start empty columns
	var top_card = tableau[tableau_col].back()
	var can_stack = card.can_stack_on_tableau(top_card)
	_log_debug("  can_move_to_tableau:", card._to_string(), "on", top_card._to_string(), "result:", can_stack)
	_log_debug("    card rank:", card.rank, "top rank:", top_card.rank, "rank check:", card.rank == top_card.rank - 1)
	_log_debug("    card color:", card.get_color(), "top color:", top_card.get_color(), "opposite:", card.is_opposite_color(top_card))
	return can_stack

func can_move_to_foundation(card: FW_Card, foundation_idx: int) -> bool:
	var suit := _get_foundation_suit(foundation_idx)
	if suit == -1:
		return false
	if card.suit != suit:
		_log_debug("Card suit", card.get_suit_name(), "doesn't match foundation suit", _get_foundation_suit_name(suit))
		return false
	if foundations[foundation_idx].is_empty():
		var can_place = card.rank == FW_Card.Rank.ACE
		if not can_place:
			_log_debug("Foundation", foundation_idx, "is empty but card", card._to_string(), "is not an ACE")
		return can_place
	var top_card = foundations[foundation_idx].back()
	var can_stack = card.can_stack_on_foundation(top_card)
	if not can_stack:
		_log_debug("Card", card._to_string(), "(rank", card.rank, ") cannot stack on", top_card._to_string(), "(rank", top_card.rank, ") in foundation")
	return can_stack

func draw_from_stock() -> void:
	_log_debug("=== draw_from_stock() called ===")
	# Prevent drawing after game completion
	if game_completed:
		_log_debug("draw_from_stock ignored: game already completed")
		return
	_log_debug("Current stock size", stock.size())
	_log_debug("Current waste size", waste.size())

	if stock.is_empty():
		_log_debug("Stock is empty, recycling waste")
		stock_cycles += 1  # Track stock recycling
		# Reset stock from waste - need to properly clean up all waste displays first
		# Remove ALL waste card displays before recycling
		var waste_displays_to_remove: Array[FW_CardDisplay] = []
		for display in card_displays:
			if not is_instance_valid(display):
				continue
			var card := display.card
			if not card:
				continue
			var location := get_card_location(card)
			if not location.is_empty() and location.get("pile") == PileType.WASTE:
				waste_displays_to_remove.append(display)

		for display in waste_displays_to_remove:
			card_displays.erase(display)
			display.queue_free()

		# Now recycle the cards
		while not waste.is_empty():
			var card: FW_Card = waste.pop_back()
			card.face_up = false
			stock.append(card)
			set_card_location(card, PileType.STOCK, 0)

		update_stock_count()
		animate_stock_recycle()
	else:
		var draw_count = 3 if draw_three_cards else 1
		var actual_drawn = min(draw_count, stock.size())
		var mode_label = "3-card" if draw_three_cards else "1-card"
		_log_debug("Draw mode", mode_label, "requested", draw_count, "actual drawn", actual_drawn)
		if actual_drawn <= 0:
			_log_debug("No cards drawn from stock (stock empty?)")
			return
		var drawn_cards: Array[FW_Card] = []
		for i in range(actual_drawn):
			var drawn_card: FW_Card = stock.pop_back()
			drawn_card.face_up = true
			waste.append(drawn_card)
			set_card_location(drawn_card, PileType.WASTE, 0)
			drawn_cards.append(drawn_card)
			_log_debug("Drawn card", i, drawn_card._to_string())

		# Record stock draw in history
		if game_state:
			var move = FW_GameState.Move.new(drawn_cards.back())
			var typed_cards: Array[FW_Card] = []
			typed_cards.assign(drawn_cards)
			move.cards_moved = typed_cards
			move.from_stock = true
			move.source_pile = PileType.STOCK
			move.dest_pile = PileType.WASTE
			game_state.add_move(move)
			move_count += 1
			update_stats_display()

		update_stock_count()
		animate_waste_draw_cards(drawn_cards)

func _on_card_drag_moved(delta: Vector2, dragged: FW_CardDisplay) -> void:
	if _drag_controller == null:
		return
	_drag_controller.on_drag_moved(delta, dragged)

func _on_stock_gui_input(event: InputEvent) -> void:
	# Prevent stock interaction during animations
	if auto_complete_in_progress or victory_animation_playing:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		draw_from_stock()

func _on_new_game_pressed() -> void:
	# Prevent new game during animations
	if auto_complete_in_progress or victory_animation_playing:
		_log_debug("New game blocked - animation in progress")
		return

	# If there's a game in progress that hasn't been completed, record it as a loss
	if game_in_progress and not game_completed and move_count > 0:
		record_game_completion(false)
	initialize_game()

func _on_undo_pressed() -> void:
	# Undo should already be disabled, but check anyway
	if auto_complete_in_progress or victory_animation_playing:
		return
	perform_undo()

func _on_auto_complete_pressed() -> void:
	if not game_in_progress or game_completed:
		return

	if auto_complete_in_progress or victory_animation_playing:
		_log_debug("Auto-complete blocked - animation already in progress")
		return

	_log_debug("Starting auto-complete")
	_log_debug("Auto-complete speed scale:", AUTO_COMPLETE_DURATION_SCALE)
	used_auto_complete = true  # Track auto-complete usage

	# Hide and disable the button immediately after pressing
	if auto_complete_button:
		auto_complete_button.visible = false
		auto_complete_button.disabled = true

	start_auto_complete()

func _on_timer_timeout() -> void:
	elapsed_time = (Time.get_ticks_msec() / 1000.0) - start_time
	update_stats_display()

func _on_win_bg_clicked(event: InputEvent) -> void:
	# Ignore clicks if victory animation still playing
	if victory_animation_playing:
		_log_debug("Ignoring win bg click - victory animation still playing")
		return

	# Only respond to left mouse button press or touch screen press
	if not waiting_for_win_dismiss:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dismiss_win_screen()
	elif event is InputEventScreenTouch and event.pressed:
		_dismiss_win_screen()

func _dismiss_win_screen() -> void:
	_log_debug("Dismissing win screen, showing stats")
	waiting_for_win_dismiss = false

	# Stop all ongoing tweens to prevent continuous animations
	for tween in active_win_tweens:
		if is_instance_valid(tween):
			tween.kill()
	active_win_tweens.clear()

	# Hide the win screen elements
	if win_bg_panel != null:
		win_bg_panel.visible = false
	if win_label != null:
		win_label.visible = false

	# Show stats panel. Mark that stats were opened as a result of a victory so
	# we can auto-start a new game when the player returns from the stats view.
	_stats_opened_from_victory = true
	show_stats_panel()


func update_stats_display() -> void:
	if not stats_label:
		return

	var minutes = int(elapsed_time / 60.0)
	var seconds = int(elapsed_time) % 60
	var time_str = "%02d:%02d" % [minutes, seconds]

	var foundation_cards = _get_foundation_card_count()
	var score = calculate_score()

	var stats_text = "Moves: %d | Time: %s | Cards: %d/52 | Score: %d" % [move_count, time_str, foundation_cards, score]

	# Add win rate if we have game history (only access if stats are loaded)
	if game_stats and game_stats._stats_loaded and game_stats.current_stats.total_games > 0:
		var win_rate = game_stats.current_stats.get_win_rate()
		stats_text += " | W/L: %d/%d (%.0f%%)" % [
			game_stats.current_stats.total_wins,
			game_stats.current_stats.total_losses,
			win_rate
		]

		# Show current streak if any
		if game_stats.current_stats.current_streak > 0:
			stats_text += " 🔥%d" % game_stats.current_stats.current_streak

	stats_label.text = stats_text

func calculate_score() -> int:
	# Scoring system:
	# +10 per card in foundation
	# -2 per move
	# +100 for complete win
	var foundation_cards = _get_foundation_card_count()

	var base_score = foundation_cards * 10
	var move_penalty = move_count * 2
	var win_bonus = 100 if is_winner() else 0

	return max(0, base_score - move_penalty + win_bonus)

func record_game_completion(won: bool) -> void:
	if not game_stats:
		return

	# Don't record twice
	if game_completed:
		return

	game_completed = true
	game_in_progress = false

	var foundation_cards = _get_foundation_card_count()
	var score = calculate_score()

	# Record with all tracked metrics
	game_stats.record_game(
		won,
		move_count,
		elapsed_time,
		score,
		foundation_cards,
		draw_three_cards,  # Current draw mode
		stock_cycles,
		undo_count,
		used_auto_complete
	)

	# Update stats display to show updated win rate, etc.
	update_stats_display()


func _get_foundation_card_count() -> int:
	var count := 0
	for foundation in foundations:
		count += foundation.size()
	return count

func celebrate_victory() -> void:
	if win_label == null:
		_log_warn("Win label missing; cannot display victory message")
		return

	_log_debug("Starting victory celebration")
	victory_animation_playing = true

	# Ensure ALL interactions are disabled during celebration
	_disable_all_interactions()

	# Play a short victory sound
	SoundManager._play_random_win_sound()

	# Set flag to wait for user dismissal
	waiting_for_win_dismiss = true

	# Clear any previous win tweens
	active_win_tweens.clear()

	# Update win label text with stats
	var minutes = int(elapsed_time / 60.0)
	var seconds = int(elapsed_time) % 60
	var time_str = "%02d:%02d" % [minutes, seconds]
	var score = calculate_score()

	win_label.text = "🎉 YOU WIN! 🎉\n\nTime: %s \n Moves: %d \n Score: %d\n\n(tap continue)" % [time_str, move_count, score]

	# Show semi-transparent background
	if win_bg_panel != null:
		win_bg_panel.visible = true
		win_bg_panel.modulate = Color(1, 1, 1, 0)
		var bg_tween = create_tween()
		active_win_tweens.append(bg_tween)
		bg_tween.tween_property(win_bg_panel, "modulate", Color(1, 1, 1, 1), 0.5)

	# Animate win label with juicy effects
	win_label.modulate = Color(1, 1, 1, 0)
	win_label.scale = Vector2(0.3, 0.3)
	win_label.rotation = -0.3
	win_label.pivot_offset = win_label.size * 0.5

	var tween = create_tween()
	active_win_tweens.append(tween)
	tween.set_parallel(true)

	# Fade in
	tween.tween_property(win_label, "modulate", Color(1, 1, 1, 1), 0.6)

	# Elastic scale up with overshoot
	tween.tween_property(win_label, "scale", Vector2(1.3, 1.3), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Rotation spring
	tween.tween_property(win_label, "rotation", deg_to_rad(90.0) if _current_layout_preset == LayoutPreset.LANDSCAPE else 0.0, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# After initial animation, add continuous pulse
	await tween.finished

	# Only continue animations if we're still waiting for dismissal
	if waiting_for_win_dismiss:
		var pulse_tween = create_tween()
		active_win_tweens.append(pulse_tween)
		pulse_tween.set_loops()
		pulse_tween.tween_property(win_label, "scale", Vector2(1.35, 1.35), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(win_label, "scale", Vector2(1.25, 1.25), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Add rainbow color cycle
		var color_tween = create_tween()
		active_win_tweens.append(color_tween)
		color_tween.set_loops()
		var colors = [
			Color(1.0, 0.85, 0.0, 1.0),   # Gold
			Color(1.0, 0.6, 0.0, 1.0),    # Orange
			Color(1.0, 0.85, 0.0, 1.0),   # Gold
			Color(0.9, 1.0, 0.0, 1.0),    # Yellow-green
			Color(1.0, 0.85, 0.0, 1.0),   # Gold
		]
		for i in range(colors.size()):
			var next_color = colors[i]
			color_tween.tween_property(win_label, "self_modulate", next_color, 1.0)

	# Bounce foundation cards with more energy
	for f_idx in range(FOUNDATION_SUIT_ORDER.size()):
		if not foundations[f_idx].is_empty():
			var top_card = foundations[f_idx].back()
			var display = get_display_for_card(top_card)
			if display:
				bounce_card(display, 0.15 + f_idx * 0.08)
				# Add sparkle burst at each foundation
				_create_particle_burst(display.position)

	# Launch the victory fountain after a brief moment
	await get_tree().create_timer(1.0).timeout
	if waiting_for_win_dismiss:  # Only if user hasn't dismissed yet
		_victory_card_fountain()

	# Wait for initial animations to complete before allowing dismissal
	await get_tree().create_timer(0.5).timeout
	victory_animation_playing = false
	_log_debug("Victory celebration animations complete, user can now dismiss")

	# NOTE: Removed automatic stats panel showing - now waits for user click

func bounce_card(card_display: FW_CardDisplay, delay: float) -> void:
	await get_tree().create_timer(delay).timeout

	var original_pos = card_display.position
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(card_display, "position", original_pos - Vector2(0, 40), 0.4)
	tween.tween_property(card_display, "position", original_pos, 0.4)

	# Add rotation wiggle with more energy
	var rotate_tween = create_tween()
	rotate_tween.set_parallel(true)
	var original_extra: float = card_display.extra_rotation
	rotate_tween.tween_property(card_display, "extra_rotation", original_extra + 0.3, 0.2)
	rotate_tween.tween_property(card_display, "extra_rotation", original_extra - 0.3, 0.2).set_delay(0.2)
	rotate_tween.tween_property(card_display, "extra_rotation", original_extra + 0.15, 0.15).set_delay(0.4)
	rotate_tween.tween_property(card_display, "extra_rotation", original_extra - 0.15, 0.15).set_delay(0.55)
	rotate_tween.tween_property(card_display, "extra_rotation", original_extra, 0.15).set_delay(0.7)

	# Add scale pulse
	var scale_tween = create_tween()
	scale_tween.tween_property(card_display, "scale", Vector2(1.15, 1.15), 0.2)
	scale_tween.tween_property(card_display, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_ELASTIC)

func flip_card_animation(card_display: FW_CardDisplay) -> void:
	# Simulate 3D flip by scaling X
	var tween = _create_card_tween(card_display)
	if tween == null:
		return
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Shrink to 0 width (flip to middle)
	tween.tween_property(card_display, "scale:x", 0.0, 0.15)
	# Refresh the card display at the middle of the flip
	tween.tween_callback(card_display.refresh)
	# Expand back to full width
	tween.tween_property(card_display, "scale:x", 1.0, 0.15)

	# Add a small bounce
	tween.tween_property(card_display, "scale", Vector2(1.05, 1.05), 0.1)
	tween.tween_property(card_display, "scale", Vector2(1.0, 1.0), 0.1)



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_undo"):
		perform_undo()
		#accept_event()

func perform_undo() -> void:
	# Don't allow undo if game is won
	if is_winner():
		return

	if not game_state or not game_state.can_undo():
		_log_debug("Cannot undo: no moves in history")
		return

	var move: FW_GameState.Move = game_state.pop_last_move()
	if not move:
		return

	_log_debug("Undoing move")
	undo_count += 1  # Track undo usage
	move_count = max(0, move_count - 1)
	update_stats_display()

	# Handle stock draw undo
	if move.from_stock:
		_log_debug("=== UNDO STOCK DRAW ===")
		_log_debug("Waste size before", waste.size())
		var cards_to_return: Array[FW_Card] = []
		if not move.cards_moved.is_empty():
			cards_to_return.assign(move.cards_moved)
		elif move.card:
			cards_to_return.append(move.card)
		_log_debug("Returning", cards_to_return.size(), "card(s) to stock")
		for i in range(cards_to_return.size()):
			if waste.is_empty():
				_log_debug("Waste empty sooner than expected during undo")
				break
			var card = waste.pop_back()
			_log_debug("Moving card back to stock", card._to_string())
			card.face_up = false
			stock.append(card)
			set_card_location(card, PileType.STOCK, 0)

			# Hide the card display that's going back to stock
			var card_display = get_display_for_card(card)
			if card_display:
				_log_debug("Hiding card display going to stock")
				card_display.visible = false

		_log_debug("Waste size after", waste.size())
		if not waste.is_empty():
			_log_debug("New top waste card", waste.back()._to_string())

		update_waste_display()
		update_stock_count()
		return

	# Handle regular card moves
	var cards_to_move = move.cards_moved if not move.cards_moved.is_empty() else [move.card]

	# Remove cards from destination
	match move.dest_pile:
		PileType.TABLEAU:
			for card in cards_to_move:
				tableau[move.dest_index].erase(card)
			# Don't flip any cards when removing during undo!
			# The revealed_card tracking will handle restoring face-down states
		PileType.FOUNDATION:
			for card in cards_to_move:
				foundations[move.dest_index].erase(card)
			# Show the card that was previously on top (if any)
			if not foundations[move.dest_index].is_empty():
				var new_top = foundations[move.dest_index].back()
				var new_top_display = get_display_for_card(new_top)
				if new_top_display:
					new_top_display.visible = true
					new_top_display.refresh()
		PileType.WASTE:
			for card in cards_to_move:
				waste.erase(card)

	# Return cards to source
	match move.source_pile:
		PileType.TABLEAU:
			for card in cards_to_move:
				tableau[move.source_index].append(card)
				set_card_location(card, PileType.TABLEAU, move.source_index)
				# Ensure card display is visible and refreshed
				var card_display = get_display_for_card(card)
				if card_display:
					card_display.visible = true
					card_display.refresh()
			# Un-reveal card if one was revealed (flip it back to face-down)
			if move.revealed_card:
				move.revealed_card.face_up = false
				var revealed_display = get_display_for_card(move.revealed_card)
				if revealed_display:
					revealed_display.refresh()
		PileType.FOUNDATION:
			# Hide the card that will be beneath the returned card
			if not foundations[move.source_index].is_empty():
				var old_top = foundations[move.source_index].back()
				var old_top_display = get_display_for_card(old_top)
				if old_top_display:
					old_top_display.visible = false
			for card in cards_to_move:
				foundations[move.source_index].append(card)
				set_card_location(card, PileType.FOUNDATION, move.source_index)
				# Ensure card display is visible and on top
				var card_display = get_display_for_card(card)
				if card_display:
					card_display.visible = true
					card_display.z_index = 200 + move.source_index
		PileType.WASTE:
			for card in cards_to_move:
				waste.append(card)
				set_card_location(card, PileType.WASTE, 0)
			# Don't update waste display here - let refresh_all_card_positions handle it

	# Refresh the board
	refresh_all_card_positions()

func refresh_all_card_positions() -> void:
	if tableau == null or tableau.size() == 0:
		return
	_update_static_slot_positions()
	# Update all tableau columns
	for col in range(7):
		update_tableau_positions(col)

	# Update waste display
	update_waste_display()
	update_stock_count()
	_sort_displays_by_z_index()

	# Update foundation card positions and visibility
	for f_idx in range(FOUNDATION_SUIT_ORDER.size()):
		if not foundations[f_idx].is_empty():
			# Hide all cards except the top one
			for i in range(foundations[f_idx].size()):
				var card_in_foundation = foundations[f_idx][i]
				var display = get_display_for_card(card_in_foundation)
				if display:
					var is_top_card = (i == foundations[f_idx].size() - 1)
					display.visible = is_top_card
					if is_top_card:
						display.position = _foundation_position(f_idx)
						display.z_index = 200 + f_idx
						display.refresh()


func _on_card_double_clicked(card_display: FW_CardDisplay) -> void:
	# Ignore double-clicks after the game is completed
	if game_completed:
		return
	if not card_display.card:
		return
	if not can_drag_card(card_display.card):
		return

	# Try to auto-move to foundation
	if try_auto_move_to_foundation(card_display):
		selected_cards.clear()
	elif try_auto_move_to_tableau(card_display):
		selected_cards.clear()
	else:
		pass

func try_auto_move_to_foundation(card_display: FW_CardDisplay) -> bool:
	var card = card_display.card
	if not card:
		return false
	if not can_drag_card(card):
		return false

	# Check if this is a single card (not part of a sequence in tableau)
	var location = get_card_location(card)
	if location.is_empty():
		return false

	# For tableau cards, must be the top card
	if location.get("pile") == PileType.TABLEAU:
		var col: int = location.get("index", -1)
		if col == -1 or tableau[col].is_empty():
			return false
		if tableau[col].back() != card:
			return false

	# Try each foundation
	for f_idx in range(FOUNDATION_SUIT_ORDER.size()):
		if can_move_to_foundation(card, f_idx):
			# Animate the move
			# CRITICAL: Check if card is already in this foundation (shouldn't happen)
			if not foundations[f_idx].is_empty() and foundations[f_idx].has(card):
				return false

			move_card_to_foundation_animated(card_display, f_idx)
			selected_cards.clear()
			return true

	return false


func try_auto_move_to_tableau(card_display: FW_CardDisplay) -> bool:
	var card = card_display.card
	if not card:
		return false

	var location = get_card_location(card)
	if location.is_empty():
		return false

	# Ensure card is movable (top of tableau column or top of waste)
	match location.get("pile", -1):
		PileType.TABLEAU:
			var col: int = location.get("index", -1)
			if col == -1 or tableau[col].is_empty() or tableau[col].back() != card:
				return false
		PileType.WASTE:
			if waste.is_empty() or waste.back() != card:
				return false
		_:
			return false

	for col in range(tableau.size()):
		if location.get("pile", -1) == PileType.TABLEAU and location.get("index", -1) == col:
			continue
		if can_move_to_tableau(card, col):
			var displays: Array = [card_display]
			move_card_to_tableau(displays, col)
			selected_cards.clear()
			return true

	return false

func move_card_to_foundation_animated(card_display: FW_CardDisplay, f_idx: int) -> void:
	var card: FW_Card = card_display.card
	if not card:
		return

	# Store reference before removing from pile
	var previous_location = get_card_location(card)
	var was_from_waste = previous_location.get("pile", -1) == PileType.WASTE

	# Hide any previous top card in the foundation (it should be beneath the new card)
	if not foundations[f_idx].is_empty():
		var prev_top = foundations[f_idx].back()
		var prev_display = get_display_for_card(prev_top)
		if prev_display:
			prev_display.visible = false  # Hide the card beneath

	# Remove from source pile AFTER getting the display
	# This is important: we need to update the data structures but NOT free the display yet
	match previous_location.get("pile", -1):
		PileType.TABLEAU:
			var col: int = previous_location.get("index", -1)
			if col != -1:
				tableau[col].erase(card)
				if not tableau[col].is_empty():
					var top_card: FW_Card = tableau[col].back()
					if not top_card.face_up:
						top_card.face_up = true
						var top_display: FW_CardDisplay = get_display_for_card(top_card)
						if top_display != null:
							flip_card_animation(top_display)
				update_tableau_positions(col)
		PileType.FOUNDATION:
			# Moving from one foundation to another (shouldn't happen in solitaire, but handle it)
			var source_f_idx: int = previous_location.get("index", -1)
			if source_f_idx != -1:
				foundations[source_f_idx].erase(card)
				# Show the card that was beneath this one
				if not foundations[source_f_idx].is_empty():
					var revealed = foundations[source_f_idx].back()
					var revealed_display = get_display_for_card(revealed)
					if revealed_display:
						revealed_display.visible = true
						revealed_display.refresh()
		PileType.WASTE:
			waste.erase(card)
		PileType.STOCK:
			stock.erase(card)
			update_stock_count()

	# Add to foundation
	foundations[f_idx].append(card)
	set_card_location(card, PileType.FOUNDATION, f_idx)

	# CRITICAL: Ensure the card display is in our card_displays array and is visible
	if not card_displays.has(card_display):
		card_displays.append(card_display)

	_cancel_active_card_tween(card_display)

	# Move card display to foundation position IMMEDIATELY (no animation yet)
	# This prevents overlap when we create the next waste card display
	card_display.position = _foundation_position(f_idx)
	card_display.visible = true
	card_display.z_index = 1000  # Temporarily very high during setup

	# CRITICAL: If moving from waste, update waste display NOW
	# Since we've already moved this card's display to foundation position,
	# the new waste display won't overlap
	if was_from_waste:
		update_waste_display()

	# Now set proper z-index for foundation
	card_display.z_index = 200 + f_idx

	# Record move in history
	if game_state and not previous_location.is_empty():
		var move = FW_GameState.Move.new(card)
		move.cards_moved.append(card)
		move.source_pile = previous_location.get("pile", -1)
		move.source_index = previous_location.get("index", -1)
		move.dest_pile = PileType.FOUNDATION
		move.dest_index = f_idx
		game_state.add_move(move)
		move_count += 1
		update_stats_display()

	# Create a "pop" animation at the foundation position
	# Lock the position first to prevent any movement
	var locked_position = _foundation_position(f_idx)
	card_display.position = locked_position

	var tween = _create_card_tween(card_display)
	if tween == null:
		return
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_display, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(card_display, "scale", Vector2(1.0, 1.0), 0.1)
	# Ensure position stays locked during animation
	tween.parallel().tween_property(card_display, "position", locked_position, 0.2)

	# Ensure card is visible and properly rendered
	# Capture card_display as a local variable to avoid reference issues
	var display_ref = card_display
	tween.finished.connect(func():
		if is_instance_valid(display_ref):
			display_ref.modulate = Color(1.0, 1.0, 1.0, 1.0)
			display_ref.refresh()
		# Note: We already called update_waste_display() before animation, no need to call again
		check_win()
		check_auto_complete_available()
	)


func highlight_valid_drop_zones(highlight: bool) -> void:
	if _drag_controller == null:
		return
	_drag_controller.highlight_valid_drop_zones(highlight)

func animate_invalid_move(card_display: FW_CardDisplay) -> void:
	var card: FW_Card = card_display.card
	if not card:
		return

	var location: Dictionary = get_card_location(card)
	if location.is_empty():
		return

	# Get the correct return position and z-index
	var return_pos: Vector2
	var return_z_index: int = 0
	var pile_type = int(location.get("pile", -1))
	var waste_layout_info: Dictionary = {}
	var waste_return_rotation = 0.0
	match pile_type:
		PileType.TABLEAU:
			var col: int = location.get("index", -1)
			if col == -1:
				return
			var row := tableau[col].find(card)
			if row == -1:
				if tableau[col].is_empty():
					return
				row = tableau[col].size() - 1
			return_pos = _tableau_position(col, row)
			return_z_index = 10 + (col * 20) + row
		PileType.FOUNDATION:
			var f_idx: int = location.get("index", -1)
			if f_idx == -1:
				return
			return_pos = _foundation_position(f_idx)
			return_z_index = 200 + f_idx
		PileType.WASTE:
			var layout = _calculate_waste_layout()
			if layout.has(card):
				waste_layout_info = layout[card]
			return_pos = waste_layout_info.get("position", _waste_position())
			return_z_index = waste_layout_info.get("z_index", 100)
			waste_return_rotation = float(waste_layout_info.get("rotation", 0.0))
		PileType.STOCK:
			return_pos = _stock_position()
			return_z_index = 5
		_:
			return

	# Animate with a "shake" effect then snap back
	var tween = _create_card_tween(card_display)
	if tween == null:
		return
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	var original_extra_rotation: float = card_display.extra_rotation

	# Brief red flash
	var original_modulate = card_display.modulate
	tween.tween_property(card_display, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(card_display, "modulate", original_modulate, 0.1)

	# Smooth return to position
	tween.parallel().tween_property(card_display, "position", return_pos, 0.3)
	tween.parallel().tween_property(card_display, "z_index", return_z_index, 0.3)
	var target_extra_rotation: float = original_extra_rotation
	if pile_type == PileType.WASTE:
		target_extra_rotation = float(waste_return_rotation)
		var display_ref = card_display
		tween.finished.connect(func():
			if is_instance_valid(display_ref):
				display_ref.refresh()
			update_waste_display()
		)
	tween.parallel().tween_property(card_display, "extra_rotation", target_extra_rotation, 0.3)


func animate_initial_deal() -> void:
	"""Animate cards being dealt from stock to tableau positions"""

	SoundManager._play_card_deal_sound()

	# Disable buttons during dealing
	if new_game_button:
		new_game_button.disabled = true
	if undo_button:
		undo_button.disabled = true
	# Don't disable auto_complete_button - we control it via visibility now

	# Get stock position as starting point
	var stock_pos = _stock_position()

	# Set all cards to start at stock position, face down, and hidden
	for col in range(tableau.size()):
		for row in range(tableau[col].size()):
			var card = tableau[col][row]
			var display = get_display_for_card(card)
			if display:
				display.position = stock_pos
				display.z_index = 1000  # High z-index during dealing
				display.visible = false  # Start hidden
				card.face_up = false  # Start face down
				display.scale = Vector2(0.8, 0.8)  # Start smaller

	# Deal cards with animation
	_deal_cards_sequentially()


func _deal_cards_sequentially() -> void:
	"""Async function to deal cards one by one with delays"""
	var delay_between_cards = 0.04  # Fast dealing speed
	var current_delay = 0.0

	# Deal in proper order: first card to first column, second to first 2 columns, etc.
	for row in range(7):  # Row 0 to 6
		for col in range(row, 7):  # Deal to columns row through 6
			if row <= col:  # Only deal if this position should have a card
				var card_index = row
				if card_index < tableau[col].size():
					var card = tableau[col][card_index]
					var display = get_display_for_card(card)
					if display:
						# Schedule this card's animation
						_animate_card_deal(display, col, card_index, current_delay, row == col)
						current_delay += delay_between_cards

	# After all cards are dealt, enable buttons
	var total_deal_time = current_delay + 0.3  # Animation time + buffer
	await get_tree().create_timer(total_deal_time).timeout

	if new_game_button:
		new_game_button.disabled = false
	if undo_button:
		undo_button.disabled = false
	# Auto-complete button is controlled via visibility, not disabled state


func _animate_card_deal(display: FW_CardDisplay, col: int, row: int, delay: float, is_top_card: bool) -> void:
	"""Animate a single card being dealt to its position"""
	# Wait for the delay
	await get_tree().create_timer(delay).timeout

	# Make card visible
	display.visible = true

	# Calculate target position
	var target_pos = _tableau_position(col, row)
	var target_z_index = 10 + (col * 20) + row

	# Animate card flying to position
	var tween = _create_card_tween(display)
	if tween == null:
		return
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(display, "position", target_pos, 0.25)
	tween.tween_property(display, "scale", Vector2(1.0, 1.0), 0.25)
	tween.tween_property(display, "z_index", target_z_index, 0.25)

	# Wait for animation to complete
	await tween.finished

	# Set clickable height based on card position
	if is_top_card:
		display.set_clickable_height(0)  # Full height for top card
	else:
		display.set_clickable_height(CARD_OFFSET_Y)  # Only visible portion for stacked cards

	# If this is the top card of the column, flip it face up
	if is_top_card:
		display.card.face_up = true
		flip_card_animation(display)




func _get_foundation_suit(f_idx: int) -> int:
	# Use cached values instead of array lookup with bounds checking every time
	if f_idx < 0 or f_idx >= foundation_suit_cache.size():
		return -1
	return foundation_suit_cache[f_idx]

func _initialize_foundation_caches() -> void:
	"""Pre-compute foundation suit mappings for faster lookups"""
	foundation_suit_cache.clear()
	suit_to_foundation_cache.clear()

	for i in range(FOUNDATION_SUIT_ORDER.size()):
		var suit = FOUNDATION_SUIT_ORDER[i]
		foundation_suit_cache.append(suit)
		suit_to_foundation_cache[suit] = i

	_log_debug("Foundation caches initialized:", foundation_suit_cache.size(), "foundations")

func _initialize_card_pool() -> void:
	"""Create a pool of reusable CardDisplay nodes to avoid expensive instantiation"""
	var start_time_ms := Time.get_ticks_msec()
	_log_debug("=== Initializing card display pool ===")

	var parent: Node = _get_card_display_parent()

	for i in range(CARD_POOL_SIZE):
		var display_node = card_display_scene.instantiate()
		var display = display_node as FW_CardDisplay
		if display == null:
			continue

		# Add to scene tree but hide it
		parent.add_child(display)
		display.visible = false
		display.card = null
		_apply_orientation_to_display(display)

		# Connect signals once during pool creation (except card_drag_moved which needs binding per use)
		if not display.card_drag_started.is_connected(_on_card_drag_started):
			display.card_drag_started.connect(_on_card_drag_started)
		if not display.card_drag_ended.is_connected(_on_card_drag_ended):
			display.card_drag_ended.connect(_on_card_drag_ended)
		if not display.card_double_clicked.is_connected(_on_card_double_clicked):
			display.card_double_clicked.connect(_on_card_double_clicked)
		# Note: card_drag_moved is NOT connected here - we'll connect it when getting from pool

		card_display_pool.append(display)

	var elapsed_ms := Time.get_ticks_msec() - start_time_ms
	_log_debug("Card pool initialized: %d displays in %d ms" % [card_display_pool.size(), elapsed_ms])

func _get_card_display_from_pool() -> FW_CardDisplay:
	"""Get a CardDisplay from the pool, or create a new one if pool is empty"""
	if not card_display_pool.is_empty():
		var pooled_display = card_display_pool.pop_back()
		pooled_display.visible = true

		_log_debug("Got display from pool, reconnecting signals")

		# Reconnect card_drag_moved with fresh binding for this display
		# First disconnect any existing connection
		if pooled_display.card_drag_moved.is_connected(_on_card_drag_moved):
			# Disconnect all connections to this signal
			for connection in pooled_display.card_drag_moved.get_connections():
				if connection["callable"].get_object() == self:
					pooled_display.card_drag_moved.disconnect(connection["callable"])
					_log_debug("Disconnected old card_drag_moved binding")

		# Connect with fresh binding
		pooled_display.card_drag_moved.connect(_on_card_drag_moved.bind(pooled_display))
		_log_debug("Connected new card_drag_moved binding for display")

		# Ensure mouse_filter is correct
		if pooled_display.mouse_filter != Control.MOUSE_FILTER_STOP:
			_log_warn("Display has wrong mouse_filter: %d, fixing to STOP" % pooled_display.mouse_filter)
			pooled_display.mouse_filter = Control.MOUSE_FILTER_STOP

		# Verify other signals are still connected
		if not pooled_display.card_drag_started.is_connected(_on_card_drag_started):
			_log_warn("card_drag_started NOT connected! Reconnecting...")
			pooled_display.card_drag_started.connect(_on_card_drag_started)
		if not pooled_display.card_drag_ended.is_connected(_on_card_drag_ended):
			_log_warn("card_drag_ended NOT connected! Reconnecting...")
			pooled_display.card_drag_ended.connect(_on_card_drag_ended)
		if not pooled_display.card_double_clicked.is_connected(_on_card_double_clicked):
			_log_warn("card_double_clicked NOT connected! Reconnecting...")
			pooled_display.card_double_clicked.connect(_on_card_double_clicked)

		_apply_orientation_to_display(pooled_display)
		return pooled_display

	# Pool exhausted - create a new display (shouldn't happen in normal play)
	_log_warn("Card display pool exhausted! Creating new display.")
	var parent: Node = _get_card_display_parent()
	var display_node = card_display_scene.instantiate()
	var new_display = display_node as FW_CardDisplay
	if new_display:
		parent.add_child(new_display)
		new_display.card_drag_started.connect(_on_card_drag_started)
		new_display.card_drag_ended.connect(_on_card_drag_ended)
		new_display.card_drag_moved.connect(_on_card_drag_moved.bind(new_display))
		new_display.card_double_clicked.connect(_on_card_double_clicked)
		_apply_orientation_to_display(new_display)
	return new_display

func _return_card_display_to_pool(display: FW_CardDisplay) -> void:
	"""Return a CardDisplay to the pool for reuse"""
	if not is_instance_valid(display):
		return

	# Disconnect card_drag_moved signal (has binding that needs to be cleared)
	if display.card_drag_moved.is_connected(_on_card_drag_moved):
		for connection in display.card_drag_moved.get_connections():
			if connection["callable"].get_object() == self:
				display.card_drag_moved.disconnect(connection["callable"])

	# Reset display state
	display.card = null
	display.visible = false
	display.position = Vector2(-10000, -10000)  # Move far off-screen to avoid blocking input
	display.set_extra_rotation(0.0)
	display.scale = Vector2.ONE
	display.z_index = -1000  # Very low z-index so it doesn't block anything
	display.modulate = Color(1, 1, 1, 1)
	display.set_clickable_height(0)  # Reset to full height

	# Reset dragging state in case it was left in a bad state
	display.is_dragging = false
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ignore mouse while in pool

	# Cancel any active tweens
	_cancel_active_card_tween(display)

	_apply_orientation_to_display(display)

	# Return to pool
	if not card_display_pool.has(display):
		card_display_pool.append(display)

func _get_foundation_index_for_suit(suit: int) -> int:
	"""Get foundation index for a given suit using cached lookup (O(1) instead of O(n))"""
	return suit_to_foundation_cache.get(suit, -1)


func _get_foundation_emoji(suit: int) -> String:
	match suit:
		FW_Card.Suit.HEARTS: return "♥️"
		FW_Card.Suit.DIAMONDS: return "♦️"
		FW_Card.Suit.CLUBS: return "♣️"
		FW_Card.Suit.SPADES: return "♠️"
		_: return "?"


func _get_foundation_suit_name(suit: int) -> String:
	match suit:
		FW_Card.Suit.HEARTS: return "hearts"
		FW_Card.Suit.DIAMONDS: return "diamonds"
		FW_Card.Suit.CLUBS: return "clubs"
		FW_Card.Suit.SPADES: return "spades"
		_: return "the suit"

func is_winner() -> bool:
	for foundation in foundations:
		if foundation.size() != 13:
			return false
	return true

func _calculate_waste_layout() -> Dictionary:
	var layout: Dictionary = {}
	var limit = 3 if draw_three_cards else 1
	var total = waste.size()
	var start_index = max(total - limit, 0)
	var visible_count = total - start_index
	var base_pos = _waste_position()
	var waste_axes := _slot_local_axes(waste_panel)
	var waste_horizontal: Vector2 = waste_axes.get("x_axis", Vector2.RIGHT)
	var waste_vertical: Vector2 = waste_axes.get("y_axis", Vector2.DOWN)
	for i in range(total):
		var card = waste[i]
		var info: Dictionary = {}
		var should_show = i >= start_index
		info["visible"] = should_show
		if should_show:
			var visible_index = i - start_index
			var horizontal_offset = float(visible_index - (visible_count - 1)) * WASTE_FAN_HORIZONTAL_OFFSET
			var vertical_offset = float(visible_index - (visible_count - 1)) * WASTE_FAN_VERTICAL_OFFSET
			var offset_vector := _axis_step(waste_horizontal, horizontal_offset) + _axis_step(waste_vertical, vertical_offset)
			var target_position = base_pos + offset_vector
			info["visible_index"] = visible_index
			info["position"] = target_position
			info["z_index"] = 100 + visible_index
			var rotation_step = 0.03 if draw_three_cards else 0.0
			info["rotation"] = float(visible_index - (visible_count - 1)) * rotation_step
			info["is_top"] = visible_index == visible_count - 1
		else:
			info["is_top"] = false
		layout[card] = info
	return layout

func _apply_waste_layout(layout: Dictionary, skip_cards: Array = []) -> void:
	for card in layout.keys():
		var info: Dictionary = layout[card]
		if skip_cards.has(card):
			continue
		var should_show: bool = info.get("visible", false)
		var display: FW_CardDisplay = null
		if should_show:
			display = _ensure_card_display(card)
		else:
			display = get_display_for_card(card)
		if display == null:
			continue
		if should_show:
			display.visible = true
			display.position = info.get("position", display.position)
			display.z_index = info.get("z_index", display.z_index)
			var rotation_offset: float = float(info.get("rotation", display.get_extra_rotation()))
			display.set_extra_rotation(rotation_offset)
			display.move_to_front()
			display.modulate = Color(1.0, 1.0, 1.0, 1.0)
			var is_top = info.get("is_top", false)
			display.mouse_filter = Control.MOUSE_FILTER_STOP if is_top else Control.MOUSE_FILTER_IGNORE
			display.refresh()
		else:
			display.visible = false
			display.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_waste_display(skip_cards: Array = []) -> void:
	var start_time_us := Time.get_ticks_usec()  # Use microseconds for more precision
	_log_debug("=== update_waste_display() called ===")
	_log_debug("Waste size", waste.size())
	if not waste.is_empty():
		_log_debug("Waste cards (bottom to top)")
		for i in range(waste.size()):
			_log_debug("[%d] %s" % [i, waste[i]._to_string()])
	if not skip_cards.is_empty():
		_log_debug("Skipping layout updates for", skip_cards.size(), "card(s)")
	_log_debug("Draw three mode", draw_three_cards)
	var layout = _calculate_waste_layout()
	for card in layout.keys():
		var info: Dictionary = layout[card]
		if info.get("visible", false):
			var layout_position = info.get("position", _waste_position())
			var layout_z_index = info.get("z_index", 0)
			_log_debug("Layout ->", card._to_string(), "position=", layout_position, "z=", layout_z_index)
	_apply_waste_layout(layout, skip_cards)

	var elapsed_us := Time.get_ticks_usec() - start_time_us
	_log_debug("=== update_waste_display() done in %.2f ms ===" % (elapsed_us / 1000.0))

func update_stock_count() -> void:
	if stock_panel == null:
		_log_warn("StockPanel not found")
		return
	var remaining := stock.size()
	_log_debug("Updating stock count", remaining, "cards remaining")
	if stock_texture != null:
		stock_texture.visible = remaining > 0
	if stock_count_label != null:
		stock_count_label.text = str(remaining)
		stock_count_label.visible = remaining > 0
		_log_debug("Stock count label set to", stock_count_label.text)
	else:
		_log_warn("StockCountLabel not found")
	stock_panel.modulate = Color(1, 1, 1, 1) if remaining > 0 else Color(0.7, 0.7, 0.7, 1)


func animate_stock_recycle() -> void:
	if stock_panel == null:
		return
	stock_panel.pivot_offset = stock_panel.size * 0.5
	stock_panel.scale = Vector2.ONE
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(stock_panel, "scale", Vector2(1.08, 1.08), 0.18)
	tween.tween_property(stock_panel, "scale", Vector2(1.0, 1.0), 0.18)


func animate_waste_draw_cards(cards: Array) -> void:
	if cards.is_empty():
		return
	var typed_cards: Array[FW_Card] = []
	typed_cards.assign(cards)
	var layout = _calculate_waste_layout()
	var skip_cards: Array[FW_Card] = []
	skip_cards.assign(typed_cards)
	_apply_waste_layout(layout, skip_cards)
	var last_index := typed_cards.size() - 1
	for i in range(typed_cards.size()):
		var card: FW_Card = typed_cards[i]
		var display = _ensure_card_display(card)
		if display == null:
			continue
		var info: Dictionary = layout.get(card, {})
		if info.is_empty():
			continue
		display.visible = true
		display.pivot_offset = Vector2(CARD_WIDTH, CARD_HEIGHT) * 0.5
		display.position = _stock_position()
		display.scale = Vector2.ONE
		display.extra_rotation = -0.25 + (0.05 * float(i))
		display.move_to_front()
		display.z_index = 500 + i
		var tween = _create_card_tween(display)
		if tween == null:
			display.position = info.get("position", display.position)
			display.extra_rotation = float(info.get("rotation", display.extra_rotation))
			display.z_index = info.get("z_index", display.z_index)
			display.refresh()
			if i == last_index:
				update_waste_display()
			continue
		var delay = 0.05 * float(i)
		if delay > 0.0:
			tween.tween_interval(delay)
		# Play a small card noise for each card drawn from stock
		SoundManager._play_random_card_sound()
		var position_track = tween.tween_property(display, "position", info.get("position", display.position), 0.24)
		position_track.set_ease(Tween.EASE_OUT)
		position_track.set_trans(Tween.TRANS_CUBIC)
		var rotation_track = tween.parallel().tween_property(display, "extra_rotation", float(info.get("rotation", display.extra_rotation)), 0.18)
		rotation_track.set_ease(Tween.EASE_OUT)
		rotation_track.set_trans(Tween.TRANS_CUBIC)
		var z_track = tween.parallel().tween_property(display, "z_index", info.get("z_index", display.z_index), 0.24)
		z_track.set_ease(Tween.EASE_OUT)
		z_track.set_trans(Tween.TRANS_CUBIC)
		var is_last := (i == last_index)
		tween.finished.connect(func():
			if is_instance_valid(display):
				display.refresh()
			if is_last:
				update_waste_display()
		)

func animate_waste_draw(card: FW_Card) -> void:
	if not card:
		return
	var wrapper: Array[FW_Card] = []
	wrapper.append(card)
	animate_waste_draw_cards(wrapper)


## Auto-complete functionality

func is_auto_completable() -> bool:
	"""Check if the game can be auto-completed (all remaining moves are safe)"""
	# No face-down cards in tableau
	for col in tableau:
		for card in col:
			if not card.face_up:
				return false

	# Stock and waste should be empty (or all can move to foundations)
	if not stock.is_empty():
		return false

	# All remaining cards must be movable to foundations
	# This is true when there are no more tableau moves needed
	return true

func check_auto_complete_available() -> void:
	"""Check if auto-complete should be enabled and update button visibility"""
	if not auto_complete_button:
		return

	if game_completed or not game_in_progress or auto_complete_in_progress:
		auto_complete_button.visible = false
		return

	# Show button if auto-completable, hide if not
	var should_show = is_auto_completable()
	if auto_complete_button.visible != should_show:
		auto_complete_button.visible = should_show
		# Ensure button is enabled when we show it
		if should_show:
			auto_complete_button.disabled = false

func start_auto_complete() -> void:
	"""Start the auto-complete animation sequence"""
	if not is_auto_completable():
		return

	if auto_complete_in_progress:
		_log_warn("Auto-complete already in progress")
		return

	_log_debug("Starting auto-complete")
	auto_complete_in_progress = true
	auto_complete_card_count = 0

	# Disable ALL UI interactions
	_disable_all_interactions()

	_auto_complete_next_card()

func _auto_complete_next_card() -> void:
	"""Recursively move cards to foundations with animation delays"""
	# Try to find a card that can move to a foundation
	var moved := false

	# Check waste pile first
	if not waste.is_empty():
		var card = waste.back()
		for f_idx in range(foundations.size()):
			if can_move_to_foundation(card, f_idx):
				var display = get_display_for_card(card)
				if display:
					auto_complete_card_count += 1
					_play_autocomplete_move_sound()

					# Use the NEW juicy animated version for auto-complete
					await _auto_complete_move_card_to_foundation(display, f_idx)
					_auto_complete_next_card()
					return

	# Check tableau piles
	for col in range(tableau.size()):
		if tableau[col].is_empty():
			continue
		var card = tableau[col].back()
		if not card.face_up:
			continue

		for f_idx in range(foundations.size()):
			if can_move_to_foundation(card, f_idx):
				var display = get_display_for_card(card)
				if display:
					auto_complete_card_count += 1
					_play_autocomplete_move_sound()

					# Use the NEW juicy animated version for auto-complete
					await _auto_complete_move_card_to_foundation(display, f_idx)
					moved = true
					_auto_complete_next_card()
					return

	# If no cards could be moved, we're done
	if not moved:
		_log_debug("Auto-complete finished!", auto_complete_card_count, "cards moved")
		auto_complete_in_progress = false

		# VICTORY CARD FOUNTAIN - the grand finale!
		# Shorten the wait before the victory fountain according to the auto-complete speed scale
		var _ac_scale: float = clamp(AUTO_COMPLETE_DURATION_SCALE, 0.05, 2.0)
		await get_tree().create_timer(0.5 * _ac_scale).timeout
		_victory_card_fountain()

		# Don't re-enable interactions - let victory animation take over
		# Victory detection happens via check_win() calls during moves

func _play_autocomplete_move_sound() -> void:
	"""Play escalating sound effects during auto-complete"""
	# Escalating pitch based on card count
	var pitch_scale = 1.0 + (auto_complete_card_count * 0.03)
	pitch_scale = clamp(pitch_scale, 1.0, 1.5)

	SoundManager._play_random_card_sound()

	# Play mini celebration every 5 cards
	if auto_complete_card_count % 5 == 0:
		SoundManager._play_random_positive_sound()


func _auto_complete_move_card_to_foundation(card_display: FW_CardDisplay, f_idx: int) -> void:
	"""Move card to foundation with ACTUAL animation for auto-complete (not instant)"""
	var card: FW_Card = card_display.card
	if not card:
		return

	_log_debug("Auto-complete moving card:", card._to_string(), "to foundation", f_idx)

	# Store starting position before we do anything
	var start_pos = card_display.position
	var target_pos = _foundation_position(f_idx)

	# Store reference before removing from pile
	var previous_location = get_card_location(card)
	var was_from_waste = previous_location.get("pile", -1) == PileType.WASTE

	# Hide any previous top card in the foundation
	if not foundations[f_idx].is_empty():
		var prev_top = foundations[f_idx].back()
		var prev_display = get_display_for_card(prev_top)
		if prev_display:
			prev_display.visible = false

	# Remove from source pile
	match previous_location.get("pile", -1):
		PileType.TABLEAU:
			var col: int = previous_location.get("index", -1)
			if col != -1:
				tableau[col].erase(card)
				if not tableau[col].is_empty():
					var top_card: FW_Card = tableau[col].back()
					if not top_card.face_up:
						top_card.face_up = true
						var top_display: FW_CardDisplay = get_display_for_card(top_card)
						if top_display != null:
							flip_card_animation(top_display)
				update_tableau_positions(col)
		PileType.WASTE:
			waste.erase(card)
		PileType.STOCK:
			stock.erase(card)
			update_stock_count()

	# Add to foundation
	foundations[f_idx].append(card)
	set_card_location(card, PileType.FOUNDATION, f_idx)

	# Make sure card is visible and in our tracking
	if not card_displays.has(card_display):
		card_displays.append(card_display)
	card_display.visible = true
	card_display.z_index = 1000  # High during animation

	# Update waste display NOW if needed
	if was_from_waste:
		update_waste_display()

	# Record move in history
	if game_state and not previous_location.is_empty():
		var move = FW_GameState.Move.new(card)
		move.cards_moved.append(card)
		move.source_pile = previous_location.get("pile", -1)
		move.source_index = previous_location.get("index", -1)
		move.dest_pile = PileType.FOUNDATION
		move.dest_index = f_idx
		game_state.add_move(move)
		move_count += 1
		update_stats_display()

	# NOW animate the actual movement with trail and particles!
	_add_card_trail(card_display, target_pos)
	_add_sparkle_particles(card_display, target_pos)

	# Create smooth movement tween
	_cancel_active_card_tween(card_display)
	var tween = _create_card_tween(card_display)
	if tween == null:
		card_display.position = target_pos
		card_display.z_index = 200 + f_idx
		check_win()
		check_auto_complete_available()
		return

	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)

	# Smooth movement from current position to target
	var _ac_scale: float = clamp(AUTO_COMPLETE_DURATION_SCALE, 0.05, 2.0)
	# Scale durations so users can speed up (smaller is faster); 0.5 -> ~50% faster
	tween.tween_property(card_display, "position", target_pos, 0.4 * _ac_scale)

	# Arc effect - slight upward curve
	var mid_y = start_pos.y - 30
	tween.tween_property(card_display, "position:y", mid_y, 0.2 * _ac_scale)
	tween.chain().tween_property(card_display, "position:y", target_pos.y, 0.2 * _ac_scale)

	# Scale pulse
	tween.parallel().tween_property(card_display, "scale", Vector2(1.1, 1.1), 0.2 * _ac_scale)
	tween.chain().tween_property(card_display, "scale", Vector2(1.0, 1.0), 0.2 * _ac_scale)

	# Final z-index
	tween.parallel().tween_property(card_display, "z_index", 200 + f_idx, 0.4 * _ac_scale)

	# Wait for animation to complete
	await tween.finished

	if is_instance_valid(card_display):
		card_display.modulate = Color(1.0, 1.0, 1.0, 1.0)
		card_display.refresh()

	check_win()
	check_auto_complete_available()


## ===============================================
## JUICY VISUAL EFFECTS
## ===============================================

func _add_card_trail(card_display: FW_CardDisplay, target_pos: Vector2) -> void:
	"""Add a smooth motion trail behind the card during movement"""
	if card_container == null:
		return

	var trail = Line2D.new()
	card_container.add_child(trail)
	trail.width = 4.0
	trail.default_color = Color(1.0, 0.85, 0.3, 0.8)  # Golden trail
	trail.z_index = card_display.z_index - 1
	trail.width_curve = _create_trail_width_curve()
	trail.gradient = _create_trail_gradient()

	var trail_points: Array[Vector2] = []
	var max_points = 25

	# Update trail during animation
	var update_timer = Timer.new()
	card_container.add_child(update_timer)
	update_timer.wait_time = 0.016  # ~60fps

	update_timer.timeout.connect(func():
		if not is_instance_valid(card_display):
			update_timer.stop()
			return

		# Add current position to trail
		trail_points.append(card_display.position + Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5))

		# Limit trail length
		if trail_points.size() > max_points:
			trail_points.pop_front()

		# Update line points
		trail.clear_points()
		for p in trail_points:
			trail.add_point(p)

		# Check if card reached destination (within threshold)
		if card_display.position.distance_to(target_pos) < 5.0:
			update_timer.stop()
	)

	update_timer.start()

	# Add sparkle particles at trail end
	_add_sparkle_particles(card_display, target_pos)

	# Cleanup after animation completes
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(update_timer):
		update_timer.queue_free()
	if is_instance_valid(trail):
		# Fade out the trail
		var fade_tween = create_tween()
		fade_tween.tween_property(trail, "modulate:a", 0.0, 0.3)
		await fade_tween.finished
		trail.queue_free()

func _create_trail_width_curve() -> Curve:
	"""Create a curve that makes the trail taper from thick to thin"""
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.3))  # Thin at start
	curve.add_point(Vector2(0.5, 1.0))  # Thick in middle
	curve.add_point(Vector2(1.0, 0.0))  # Fade at end
	return curve

func _create_trail_gradient() -> Gradient:
	"""Create a gradient that makes the trail fade from gold to transparent"""
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.85, 0.3, 0.0))   # Transparent gold at start
	grad.add_point(0.3, Color(1.0, 0.9, 0.5, 0.6))    # Bright yellow-gold
	grad.add_point(0.7, Color(1.0, 0.7, 0.2, 0.8))    # Rich gold
	grad.add_point(1.0, Color(1.0, 0.5, 0.0, 1.0))    # Deep orange-gold at end
	return grad

func _add_sparkle_particles(card_display: FW_CardDisplay, target_pos: Vector2) -> void:
	"""Add sparkle particles that follow the card and burst at destination"""
	if card_container == null:
		return

	var particles = CPUParticles2D.new()
	card_container.add_child(particles)
	particles.z_index = card_display.z_index + 1

	# Particle properties for trailing sparkles
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.8
	particles.explosiveness = 0.3
	particles.randomness = 0.5

	# Emission shape - emit from card center
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0

	# Movement
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2(0, 50)  # Slight downward pull
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 80.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0

	# Appearance
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	particles.scale_amount_curve = _create_particle_scale_curve()

	# Color - golden sparkles
	particles.color_ramp = _create_particle_color_ramp()
	particles.color_initial_ramp = _create_particle_initial_color_ramp()

	# Follow the card during movement
	var follow_timer = Timer.new()
	card_container.add_child(follow_timer)
	follow_timer.wait_time = 0.016

	follow_timer.timeout.connect(func():
		if not is_instance_valid(card_display) or not is_instance_valid(particles):
			follow_timer.stop()
			return

		# Update particle position to follow card
		particles.position = card_display.position + Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)

		# Check if card reached destination
		if card_display.position.distance_to(target_pos) < 5.0:
			follow_timer.stop()
			# Create burst at destination
			_create_particle_burst(target_pos)
	)

	follow_timer.start()

	# Cleanup
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(follow_timer):
		follow_timer.queue_free()
	if is_instance_valid(particles):
		particles.emitting = false
		await get_tree().create_timer(particles.lifetime).timeout
		if is_instance_valid(particles):
			particles.queue_free()

func _create_particle_scale_curve() -> Curve:
	"""Particles start small, grow, then shrink"""
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.3))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve

func _create_particle_color_ramp() -> Gradient:
	"""Particles fade from bright to transparent"""
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 1.0, 0.9, 1.0))
	grad.add_point(0.5, Color(1.0, 0.85, 0.4, 0.8))
	grad.add_point(1.0, Color(1.0, 0.6, 0.2, 0.0))
	return grad

func _create_particle_initial_color_ramp() -> Gradient:
	"""Random initial colors for variety"""
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.95, 0.7, 1.0))
	grad.add_point(0.5, Color(1.0, 0.85, 0.3, 1.0))
	grad.add_point(1.0, Color(1.0, 0.7, 0.2, 1.0))
	return grad

func _create_particle_burst(position: Vector2) -> void:
	"""Create an explosive burst of particles at the destination"""
	if card_container == null:
		return

	var burst = CPUParticles2D.new()
	card_container.add_child(burst)
	burst.position = position + Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)
	burst.z_index = 500

	# One-shot burst configuration
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 40
	burst.lifetime = 1.2
	burst.explosiveness = 1.0  # All at once!
	burst.randomness = 0.3

	# Emission
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 5.0

	# Movement - explode outward
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2(0, 150)
	burst.initial_velocity_min = 100.0
	burst.initial_velocity_max = 250.0
	burst.angular_velocity_min = -360.0
	burst.angular_velocity_max = 360.0
	burst.damping_min = 50.0
	burst.damping_max = 100.0

	# Appearance
	burst.scale_amount_min = 0.8
	burst.scale_amount_max = 2.0
	burst.scale_amount_curve = _create_burst_scale_curve()

	# Bright gold/yellow colors
	burst.color_ramp = _create_burst_color_ramp()

	# Cleanup after lifetime
	await get_tree().create_timer(burst.lifetime + 0.5).timeout
	if is_instance_valid(burst):
		burst.queue_free()

func _create_burst_scale_curve() -> Curve:
	"""Burst particles expand then contract"""
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(0.1, 1.5))  # Quick expand
	curve.add_point(Vector2(1.0, 0.0))  # Slow fade
	return curve

func _create_burst_color_ramp() -> Gradient:
	"""Bright flash that fades to nothing"""
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))    # Bright white flash
	grad.add_point(0.2, Color(1.0, 0.95, 0.5, 1.0))   # Golden
	grad.add_point(0.5, Color(1.0, 0.7, 0.3, 0.6))    # Orange-gold
	grad.add_point(1.0, Color(1.0, 0.5, 0.2, 0.0))    # Fade out
	return grad

func _victory_card_fountain() -> void:
	"""Create a spectacular cascading fountain of all foundation cards"""
	if card_container == null:
		return

	_log_debug("Starting victory card fountain!")

	# Collect all visible foundation cards (just the top card from each foundation)
	var fountain_cards: Array[FW_CardDisplay] = []
	for f_idx in range(foundations.size()):
		if foundations[f_idx].is_empty():
			continue
		# Only use the TOP card from each foundation to keep it clean
		var card = foundations[f_idx].back()
		var display = get_display_for_card(card)
		if display and display.visible:
			fountain_cards.append(display)

	_log_debug("Fountain launching", fountain_cards.size(), "cards!")

	# Launch all cards together for maximum impact!
	for i in range(fountain_cards.size()):
		var display = fountain_cards[i]
		var delay = i * 0.15  # Stagger launches
		_fountain_launch_card(display, delay)

	# Wait for fountain to complete
	await get_tree().create_timer(2.5).timeout
	_log_debug("Victory fountain complete!")

func _fountain_launch_card(display: FW_CardDisplay, delay: float) -> void:
	"""Launch a single card in a beautiful arc with particles"""
	await get_tree().create_timer(delay).timeout

	if not is_instance_valid(display):
		return

	var original_pos = display.position
	var original_z = display.z_index
	var original_rotation = display.rotation

	# Temporarily boost z-index so card appears above everything
	display.z_index = 2000

	# Create explosion of particles at launch
	_create_fountain_particle_explosion(display.position)

	# Calculate SMALLER arc parameters so cards stay on screen
	var apex_height = randf_range(100, 180)  # Reduced from 200-400
	var horizontal_spread = randf_range(-80, 80)  # Reduced from -150 to 150
	var rotation_spins = randf_range(-1, 1) * PI  # Reduced spins

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)

	# Vertical movement - up then down with bounce
	var up_duration = 0.5  # Slightly faster
	var down_duration = 0.6

	# Go up
	tween.tween_property(display, "position:y",
		display.position.y - apex_height, up_duration)

	# Come down with bounce
	tween.chain().tween_property(display, "position:y",
		original_pos.y, down_duration)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)

	# Horizontal spread
	tween.parallel().tween_property(display, "position:x",
		display.position.x + horizontal_spread, up_duration + down_duration)

	# Spin during flight
	tween.parallel().tween_property(display, "rotation",
		original_rotation + rotation_spins, up_duration + down_duration)

	# Scale pulse
	tween.parallel().tween_property(display, "scale",
		Vector2(1.15, 1.15), up_duration * 0.5)
	tween.chain().tween_property(display, "scale",
		Vector2(1.0, 1.0), down_duration)

	# Trail particles during flight
	_add_fountain_trail_particles(display, up_duration + down_duration)

	# Restore after landing
	await tween.finished
	if is_instance_valid(display):
		display.z_index = original_z
		display.rotation = original_rotation

func _create_fountain_particle_explosion(position: Vector2) -> void:
	"""Create a spectacular particle explosion for fountain launch"""
	if card_container == null:
		return

	var explosion = CPUParticles2D.new()
	card_container.add_child(explosion)
	explosion.position = position + Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)
	explosion.z_index = 1999

	explosion.emitting = true
	explosion.one_shot = true
	explosion.amount = 30
	explosion.lifetime = 1.0
	explosion.explosiveness = 1.0

	explosion.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	explosion.emission_sphere_radius = 15.0

	explosion.direction = Vector2(0, -1)
	explosion.spread = 180.0
	explosion.gravity = Vector2(0, 200)
	explosion.initial_velocity_min = 150.0
	explosion.initial_velocity_max = 300.0
	explosion.angular_velocity_min = -540.0
	explosion.angular_velocity_max = 540.0

	explosion.scale_amount_min = 1.0
	explosion.scale_amount_max = 2.5
	explosion.scale_amount_curve = _create_burst_scale_curve()

	# Rainbow colors for extra juice!
	var rainbow_ramp = Gradient.new()
	rainbow_ramp.add_point(0.0, Color(1.0, 0.3, 0.3, 1.0))   # Red
	rainbow_ramp.add_point(0.2, Color(1.0, 0.7, 0.2, 1.0))   # Orange
	rainbow_ramp.add_point(0.4, Color(1.0, 1.0, 0.3, 1.0))   # Yellow
	rainbow_ramp.add_point(0.6, Color(0.3, 1.0, 0.3, 0.8))   # Green
	rainbow_ramp.add_point(0.8, Color(0.3, 0.5, 1.0, 0.6))   # Blue
	rainbow_ramp.add_point(1.0, Color(0.7, 0.3, 1.0, 0.0))   # Purple fade
	explosion.color_ramp = rainbow_ramp

	await get_tree().create_timer(explosion.lifetime + 0.3).timeout
	if is_instance_valid(explosion):
		explosion.queue_free()

func _add_fountain_trail_particles(display: FW_CardDisplay, duration: float) -> void:
	"""Add trailing particles to a card during fountain animation"""
	if card_container == null:
		return

	var trail_particles = CPUParticles2D.new()
	card_container.add_child(trail_particles)
	trail_particles.z_index = display.z_index - 1

	trail_particles.emitting = true
	trail_particles.amount = 15
	trail_particles.lifetime = 0.6
	trail_particles.explosiveness = 0.2

	trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail_particles.emission_sphere_radius = 8.0

	trail_particles.direction = Vector2(0, 1)  # Trail behind
	trail_particles.spread = 60.0
	trail_particles.gravity = Vector2(0, 80)
	trail_particles.initial_velocity_min = 20.0
	trail_particles.initial_velocity_max = 60.0

	trail_particles.scale_amount_min = 0.3
	trail_particles.scale_amount_max = 1.0
	trail_particles.scale_amount_curve = _create_particle_scale_curve()
	trail_particles.color_ramp = _create_trail_gradient()

	# Follow card during animation
	var follow_timer = Timer.new()
	card_container.add_child(follow_timer)
	follow_timer.wait_time = 0.016

	var trail_start_time = Time.get_ticks_msec()
	follow_timer.timeout.connect(func():
		var elapsed = (Time.get_ticks_msec() - trail_start_time) / 1000.0
		if not is_instance_valid(display) or not is_instance_valid(trail_particles) or elapsed >= duration:
			follow_timer.stop()
			if is_instance_valid(trail_particles):
				trail_particles.emitting = false
			return

		trail_particles.position = display.position + Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)
	)

	follow_timer.start()

	# Cleanup
	await get_tree().create_timer(duration + trail_particles.lifetime).timeout
	if is_instance_valid(follow_timer):
		follow_timer.queue_free()
	if is_instance_valid(trail_particles):
		trail_particles.queue_free()


## ===============================================
## END OF JUICY VISUAL EFFECTS
## ===============================================


func show_stats_panel() -> void:
	var start_time_ms := Time.get_ticks_msec()
	_log_debug("=== show_stats_panel() START ===")

	if game_stats == null:
		_log_warn("Game stats not available")
		return

	# Ensure stats are loaded before displaying
	game_stats.ensure_loaded()

	if stats_slide_in == null:
		_log_error("StatsSlideIn not found")
		return

	_log_debug("Showing stats panel with", game_stats.current_stats.total_games, "games")	# Update the stats in the slide-in panel
	stats_slide_in.update_stats(game_stats)

	# Slide in the panel
	stats_slide_in.slide_in()

	var elapsed_ms := Time.get_ticks_msec() - start_time_ms
	_log_debug("=== show_stats_panel() END - took %d ms ===" % elapsed_ms)

func _on_stats_slide_in_back_button() -> void:
	if stats_slide_in == null:
		_log_warn("StatsSlideIn not bound during back button")
		return
	# Hide the stats panel
	stats_slide_in.slide_out()

	# If the stats panel was opened as a result of a victory, automatically
	# start a fresh game when the player returns. This prevents the player
	# from interacting with the completed game's state after viewing stats.
	if _stats_opened_from_victory:
		_stats_opened_from_victory = false
		# initialize_game resets timers, stats flags and re-deals a new game
		initialize_game()


func _on_back_button_pressed() -> void:
	ScreenRotator.change_scene("res://Scenes/game_menu2.tscn")
