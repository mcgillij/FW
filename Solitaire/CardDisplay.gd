class_name FW_CardDisplay
extends Control

const CardClass = preload("res://Solitaire/FW_Card.gd")
const CARD_BACK_TEXTURE: Texture2D = preload("res://Solitaire/CardBack.png")
const LayoutMetrics := preload("res://Solitaire/Resources/FW_SolitaireLayoutMetrics.gd")
const EMOJI_FONT := preload("res://fonts/emoji_font.tres")

enum LayoutPreset { PORTRAIT, LANDSCAPE }

@onready var card_background_color_rect: Control = %card_background_color_rect
@onready var margin_container: MarginContainer = $MarginContainer
@onready var top_left_emoji_label: Label = %top_left_emoji_label
@onready var top_left_number_label: Label = %top_left_number_label
@onready var center_label: Label = %center_label
@onready var bottom_right_emoji_label: Label = %bottom_right_emoji_label
@onready var bottom_right_number_label: Label = %bottom_right_number_label
@onready var front_container: VBoxContainer = $MarginContainer/VBoxContainer

var _card: CardClass
var card_back_texture_rect: TextureRect

var card: CardClass:
	get:
		return _card
	set(value):
		if _card == value:
			return
		_card = value
		_update_display()

var is_dragging: bool = false
var drag_offset: Vector2
var last_click_time: float = 0.0
var double_click_threshold: float = 0.5  # seconds - increased from 0.3 for better detection
var click_start_pos: Vector2 = Vector2.ZERO
var drag_threshold: float = 5.0  # pixels - if mouse moves this much, it's a drag not a click
var clickable_height: float = 0.0  # Custom clickable height for stacked cards (0 = full height)
var layout_preset: int = LayoutPreset.PORTRAIT
var _base_rotation_rad: float = 0.0
var _extra_rotation_rad: float = 0.0
var _layout_metrics: FW_SolitaireLayoutMetrics
var _base_card_size: Vector2
var _metrics_changed_callable := Callable(self, "_on_metrics_changed")
var extra_rotation: float:
	get:
		return _extra_rotation_rad
	set(value):
		set_extra_rotation(value)

signal card_clicked(card_display: FW_CardDisplay)
signal card_double_clicked(card_display: FW_CardDisplay)
signal card_drag_started(card_display: FW_CardDisplay)
signal card_drag_ended(card_display: FW_CardDisplay, dropped_on: Control)
signal card_drag_moved(delta: Vector2)

func set_layout_metrics(metrics: FW_SolitaireLayoutMetrics) -> void:
	var resolved := metrics
	if resolved == null:
		resolved = LayoutMetrics.new()
	_disconnect_metrics_signal()
	_layout_metrics = resolved
	_connect_metrics_signal()
	_apply_metrics()

func _apply_metrics() -> void:
	if _layout_metrics == null:
		return
	_update_card_dimensions(_layout_metrics)
	_update_margin_overrides(_layout_metrics)
	_update_interaction_metrics(_layout_metrics)
	_update_label_metrics(_layout_metrics)
	_refresh_background_style(_layout_metrics)
	update_card_style(_get_current_background_color())
	set_layout_preset(layout_preset)
	_update_display()

func _get_current_background_color() -> Color:
	if card_background_color_rect is Panel:
		var style_box := (card_background_color_rect as Panel).get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if style_box != null:
			return style_box.bg_color
	return Color(0.95, 0.95, 0.95, 1.0)

func _update_card_dimensions(metrics: FW_SolitaireLayoutMetrics) -> void:
	var card_size := metrics.get_card_size()
	if card_size == Vector2.ZERO:
		card_size = _base_card_size if _base_card_size != Vector2.ZERO else Vector2(80, 120)
	custom_minimum_size = card_size
	set_deferred("size", card_size)
	pivot_offset = card_size * 0.5
	if card_background_color_rect:
		card_background_color_rect.custom_minimum_size = card_size
		card_background_color_rect.set_deferred("size", card_size)
	if card_back_texture_rect:
		card_back_texture_rect.set_deferred("size", card_size)
	if margin_container:
		margin_container.custom_minimum_size = card_size

func _update_margin_overrides(metrics: FW_SolitaireLayoutMetrics) -> void:
	if margin_container == null:
		return
	margin_container.add_theme_constant_override("margin_left", int(round(metrics.margin_left)))
	margin_container.add_theme_constant_override("margin_top", int(round(metrics.margin_top)))
	margin_container.add_theme_constant_override("margin_right", int(round(metrics.margin_right)))
	margin_container.add_theme_constant_override("margin_bottom", int(round(metrics.margin_bottom)))

func _update_interaction_metrics(metrics: FW_SolitaireLayoutMetrics) -> void:
	drag_threshold = max(1.0, metrics.drag_start_threshold)
	double_click_threshold = max(0.1, metrics.double_click_time)
	if clickable_height > 0.0:
		clickable_height = clampf(clickable_height, 0.0, metrics.card_height)

func _update_label_metrics(metrics: FW_SolitaireLayoutMetrics) -> void:
	if top_left_number_label:
		top_left_number_label.add_theme_font_size_override("font_size", metrics.corner_rank_font_size)
	if bottom_right_number_label:
		bottom_right_number_label.add_theme_font_size_override("font_size", metrics.corner_rank_font_size)
	if top_left_emoji_label:
		top_left_emoji_label.add_theme_font_size_override("font_size", metrics.corner_symbol_font_size)
	if bottom_right_emoji_label:
		bottom_right_emoji_label.add_theme_font_size_override("font_size", metrics.corner_symbol_font_size)
	if center_label:
		center_label.add_theme_font_size_override("font_size", metrics.center_pip_font_size)

func _refresh_background_style(metrics: FW_SolitaireLayoutMetrics) -> void:
	if card_background_color_rect is Panel:
		var panel := card_background_color_rect as Panel
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = _get_current_background_color()
		style_box.set_corner_radius_all(int(metrics.card_corner_radius))
		style_box.border_color = Color(0.2, 0.2, 0.2, 1.0)
		style_box.set_border_width_all(int(metrics.card_border_width))
		style_box.shadow_color = Color(0, 0, 0, 0.3)
		style_box.shadow_size = int(round(metrics.card_shadow_size))
		style_box.shadow_offset = metrics.card_shadow_offset
		panel.add_theme_stylebox_override("panel", style_box)

func _ready() -> void:
	if not card_background_color_rect or not top_left_emoji_label or not top_left_number_label or not center_label or not bottom_right_emoji_label or not bottom_right_number_label:
		push_error("CardDisplay requires ColorRect and Label children")
		return
	if _base_card_size == Vector2.ZERO:
		_base_card_size = size
	pivot_offset = size * 0.5
	card_background_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left_emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_right_emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_right_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Make sure VBoxContainer doesn't block mouse input
	if front_container:
		front_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	focus_mode = Control.FOCUS_CLICK

	# Add rounded corners to card background
	setup_rounded_card()
	if _layout_metrics == null:
		_layout_metrics = LayoutMetrics.new()
		_connect_metrics_signal()
	_apply_metrics()

	set_layout_preset(layout_preset)

func _connect_metrics_signal() -> void:
	if _layout_metrics == null:
		return
	if not _layout_metrics.changed.is_connected(_metrics_changed_callable):
		_layout_metrics.changed.connect(_metrics_changed_callable)

func _disconnect_metrics_signal() -> void:
	if _layout_metrics == null:
		return
	if _layout_metrics.changed.is_connected(_metrics_changed_callable):
		_layout_metrics.changed.disconnect(_metrics_changed_callable)

func _on_metrics_changed() -> void:
	_apply_metrics()
	_update_display()

func setup_rounded_card() -> void:
	# Replace the ColorRect with a styled Panel for rounded corners
	if card_background_color_rect:
		var panel = Panel.new()
		panel.name = "BackgroundPanel"
		panel.size = card_background_color_rect.size
		panel.position = card_background_color_rect.position
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = -1
		panel.clip_contents = true  # Enable clipping for rounded corners

		# Create initial style
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0x62 / 255.0, 0x72 / 255.0, 0xa4 / 255.0, 1.0)  # #6272a4ff
		style_box.set_corner_radius_all(8)
		style_box.border_color = Color(0.2, 0.2, 0.2, 1.0)
		style_box.set_border_width_all(2)
		style_box.shadow_color = Color(0, 0, 0, 0.3)
		style_box.shadow_size = 2
		style_box.shadow_offset = Vector2(1, 1)
		panel.add_theme_stylebox_override("panel", style_box)

		# Replace ColorRect with Panel
		var parent = card_background_color_rect.get_parent()
		if parent:
			var idx = card_background_color_rect.get_index()
			parent.add_child(panel)
			parent.move_child(panel, idx)
			card_background_color_rect.queue_free()
			card_background_color_rect = panel

		card_back_texture_rect = TextureRect.new()
		card_back_texture_rect.name = "CardBackTexture"
		card_back_texture_rect.texture = CARD_BACK_TEXTURE
		card_back_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_back_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back_texture_rect.anchor_left = 0.0
		card_back_texture_rect.anchor_top = 0.0
		card_back_texture_rect.anchor_right = 1.0
		card_back_texture_rect.anchor_bottom = 1.0
		card_back_texture_rect.offset_left = 0.0
		card_back_texture_rect.offset_top = 0.0
		card_back_texture_rect.offset_right = 0.0
		card_back_texture_rect.offset_bottom = 0.0

		panel.add_child(card_back_texture_rect)
		card_back_texture_rect.visible = false


func _update_display() -> void:
	if not card_background_color_rect or not top_left_emoji_label or not top_left_number_label or not center_label or not bottom_right_emoji_label or not bottom_right_number_label:
		return

	if not card:
		update_card_style(Color(0.8, 0.8, 0.8, 1))  # Light gray for empty
		if front_container:
			front_container.visible = false
		if card_back_texture_rect:
			card_back_texture_rect.visible = false
		top_left_emoji_label.text = ""
		top_left_number_label.text = ""
		center_label.text = ""
		bottom_right_emoji_label.text = ""
		bottom_right_number_label.text = ""
		return

	if card.face_up:
		# Set background color to white for face-up cards
		update_card_style(Color(0.95, 0.95, 0.95, 1))
		if front_container:
			front_container.visible = true
		if card_back_texture_rect:
			card_back_texture_rect.visible = false

		# Set label texts
		var suit_emoji = _get_suit_emoji(card.suit)
		var rank_text = _get_rank_text(card.rank)
		top_left_number_label.text = rank_text
		top_left_emoji_label.text = suit_emoji
		center_label.text = _get_center_text(card.rank)
		bottom_right_number_label.text = rank_text
		bottom_right_emoji_label.text = suit_emoji

		# Use emoji font only for face cards, default font for numbers
		var is_face_card = card.rank in [FW_Card.Rank.JACK, FW_Card.Rank.QUEEN, FW_Card.Rank.KING]
		if is_face_card:
			var face_size := 32
			if _layout_metrics != null:
				face_size = _layout_metrics.center_face_font_size
			center_label.add_theme_font_size_override("font_size", face_size)
			# Ensure the center label uses the bundled emoji-capable font for face cards
			if EMOJI_FONT:
				center_label.add_theme_font_override("font", EMOJI_FONT)
		else:
			# Use default font for number cards
			center_label.remove_theme_font_override("font")
			var pip_size := 48
			if _layout_metrics != null:
				pip_size = _layout_metrics.center_pip_font_size
			center_label.add_theme_font_size_override("font_size", pip_size)

		var text_color = Color(0.8, 0, 0, 1) if card.get_color() == "red" else Color(0, 0, 0, 1)
		top_left_emoji_label.add_theme_color_override("font_color", text_color)
		top_left_number_label.add_theme_color_override("font_color", text_color)
		center_label.add_theme_color_override("font_color", text_color)
		bottom_right_emoji_label.add_theme_color_override("font_color", text_color)
		bottom_right_number_label.add_theme_color_override("font_color", text_color)
	else:
		# Face down - show textured back with blue tint
		update_card_style(Color(0x62 / 255.0, 0x72 / 255.0, 0xa4 / 255.0, 1.0))  # #6272a4ff
		if front_container:
			front_container.visible = false
		if card_back_texture_rect:
			card_back_texture_rect.visible = true
		top_left_emoji_label.text = ""
		top_left_number_label.text = ""
		center_label.text = ""
		bottom_right_emoji_label.text = ""
		bottom_right_number_label.text = ""

func update_card_style(bg_color: Color) -> void:
	if card_background_color_rect is Panel:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = bg_color
		var corner_radius := 8
		var border_width := 2
		var shadow_size := 2
		var shadow_offset := Vector2(1, 1)
		if _layout_metrics != null:
			corner_radius = int(round(_layout_metrics.card_corner_radius))
			border_width = int(round(_layout_metrics.card_border_width))
			shadow_size = int(round(_layout_metrics.card_shadow_size))
			shadow_offset = _layout_metrics.card_shadow_offset
		style_box.set_corner_radius_all(corner_radius)
		style_box.border_color = Color(0.2, 0.2, 0.2, 1.0)
		style_box.set_border_width_all(border_width)
		style_box.shadow_color = Color(0, 0, 0, 0.3)
		style_box.shadow_size = shadow_size
		style_box.shadow_offset = shadow_offset
		card_background_color_rect.add_theme_stylebox_override("panel", style_box)
	elif card_background_color_rect is ColorRect:
		card_background_color_rect.color = bg_color

func refresh() -> void:
	_update_display()

func _get_suit_emoji(suit: FW_Card.Suit) -> String:
	match suit:
		FW_Card.Suit.HEARTS: return "♥️"
		FW_Card.Suit.DIAMONDS: return "♦️"
		FW_Card.Suit.CLUBS: return "♣️"
		FW_Card.Suit.SPADES: return "♠️"
	return "?"

func _get_rank_text(rank: FW_Card.Rank) -> String:
	match rank:
		FW_Card.Rank.ACE: return "A"
		FW_Card.Rank.JACK: return "J"
		FW_Card.Rank.QUEEN: return "Q"
		FW_Card.Rank.KING: return "K"
		_: return str(rank)

func _get_center_text(rank: FW_Card.Rank) -> String:
	match rank:
		FW_Card.Rank.JACK: return "🤴"
		FW_Card.Rank.QUEEN: return "👸"
		FW_Card.Rank.KING: return "👑"
		_: return _get_rank_text(rank)

func flip() -> void:
	if card:
		card.face_up = not card.face_up
		_update_display()

func _exit_tree() -> void:
	_disconnect_metrics_signal()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not card:
					return
				if not card.face_up:
					return

				# Store click position
				click_start_pos = get_global_mouse_position()

				# Check for double-click first
				var current_time = Time.get_ticks_msec() / 1000.0
				var time_since_last_click = current_time - last_click_time

				if time_since_last_click < double_click_threshold and time_since_last_click > 0.05:
					# Double-click detected - prioritize this over drag
					is_dragging = false  # Cancel any drag that was started
					emit_signal("card_double_clicked", self)
					last_click_time = 0.0  # Reset to prevent triple-click
					accept_event()  # Consume the event
					return

				# Update last click time for next potential double-click
				last_click_time = current_time

				# Prepare for potential drag (but don't start yet)
				drag_offset = get_global_mouse_position() - _get_global_position()
			else:
				# Mouse button released
				if is_dragging:
					is_dragging = false
					emit_signal("card_drag_ended", self, null)

	if event is InputEventMouseMotion:
		# Only start dragging if we've moved beyond threshold
		if not is_dragging and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
			if not card:
				return
			if not card.face_up:
				return
			var mouse_moved = get_global_mouse_position().distance_to(click_start_pos)
			if mouse_moved > drag_threshold:
				# Now we're sure it's a drag, not a click
				is_dragging = true

				# Calculate drag offset in parent's local space to handle rotation correctly
				var parent_canvas := get_parent() as CanvasItem
				if parent_canvas:
					var parent_transform := parent_canvas.get_global_transform_with_canvas()
					var mouse_local := parent_transform.affine_inverse() * get_global_mouse_position()
					# The offset should be from position to mouse, so that when we drag,
					# we can do: position = mouse - offset
					# For rotated cards, we want to keep the same visual point under the cursor
					# Since rotation happens around pivot_offset, we need to account for that
					drag_offset = mouse_local - position
				else:
					drag_offset = get_global_mouse_position() - _get_global_position()

				emit_signal("card_drag_started", self)

		# Continue dragging if already started
		if is_dragging:
			var parent_canvas := get_parent() as CanvasItem
			if parent_canvas:
				# Transform mouse position to parent's local space
				var parent_transform := parent_canvas.get_global_transform_with_canvas()
				var mouse_local := parent_transform.affine_inverse() * get_global_mouse_position()

				# Calculate new position using the offset calculated at drag start
				var new_position := mouse_local - drag_offset
				var delta := new_position - position
				position = new_position

				emit_signal("card_drag_moved", delta)

func can_drop_on(other: FW_CardDisplay) -> bool:
	if not card or not other.card:
		return false
	# Check if this card can be placed on the other card
	# This depends on the pile type, but basic check
	return card.can_stack_on_tableau(other.card) or card.can_stack_on_foundation(other.card)

func set_clickable_height(height: float) -> void:
	"""Set a custom clickable height for stacked cards. Use 0 for full card height."""
	clickable_height = height

func set_layout_preset(preset: int) -> void:
	layout_preset = preset
	match layout_preset:
		LayoutPreset.PORTRAIT:
			_base_rotation_rad = 0.0
		LayoutPreset.LANDSCAPE:
			_base_rotation_rad = deg_to_rad(90.0)
	_apply_total_rotation()

func set_extra_rotation(angle: float) -> void:
	if is_equal_approx(_extra_rotation_rad, angle):
		return
	_extra_rotation_rad = angle
	_apply_total_rotation()

func get_extra_rotation() -> float:
	return _extra_rotation_rad

func _apply_total_rotation() -> void:
	rotation = _base_rotation_rad + _extra_rotation_rad

func _has_point(point: Vector2) -> bool:
	"""Override to limit clickable area for stacked cards"""
	if clickable_height > 0:
		# Get the card's local rect
		var rect = get_rect()

		if layout_preset == LayoutPreset.LANDSCAPE:
			# In landscape mode (90° rotation), cards are rotated and stack along what appears as horizontal
			# When rotated 90° clockwise, the card's local X becomes screen Y, and local Y becomes screen -X
			# Cards stack with their "bottom" edge (high X in local space after rotation) visible
			# So we want to only accept clicks in the rightmost portion (high X in local space)
			var start_x = max(rect.size.x - clickable_height, 0.0)
			var visible_rect_landscape = Rect2(start_x, 0, min(clickable_height, rect.size.x), rect.size.y)
			return visible_rect_landscape.has_point(point)
		else:
			# Portrait mode: cards stack vertically with bottom portion visible
			# Only accept clicks in the bottom portion (visible area when stacked)
			var start_y = max(rect.size.y - clickable_height, 0.0)
			var visible_rect = Rect2(0, start_y, rect.size.x, min(clickable_height, rect.size.y))
			return visible_rect.has_point(point)

	# Default behavior - full card is clickable
	return Rect2(Vector2.ZERO, size).has_point(point)

func _get_global_position() -> Vector2:
	return get_global_transform_with_canvas().origin
