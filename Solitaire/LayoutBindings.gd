@tool
extends CanvasLayer
class_name FW_SolitaireLayoutBindings

const LayoutMetrics := preload("res://Solitaire/Resources/FW_SolitaireLayoutMetrics.gd")

var _layout_metrics: FW_SolitaireLayoutMetrics
var _metrics_changed_callable := Callable(self, "_on_metrics_resource_changed")

@export var layout_metrics: FW_SolitaireLayoutMetrics:
	get:
		return _layout_metrics
	set(value):
		_disconnect_metrics_signal()
		_layout_metrics = value
		_connect_metrics_signal()
		if Engine.is_editor_hint():
			_apply_metrics_deferred()
		elif is_inside_tree():
			_apply_metrics_deferred()

@onready var shader_bg: ColorRect = %ShaderBG
@onready var background: TextureRect = %background
@onready var slots_root: Control = %SlotsRoot
@onready var card_container: Control = %CardContainer
@onready var stock_panel: Panel = %StockPanel
@onready var waste_panel: Panel = %WastePanel
@onready var stock_texture: TextureRect = %StockTexture
@onready var stock_count_label: Label = %StockCountLabel
@onready var game_timer: Timer = $GameTimer
@onready var win_bg_panel: Panel = %WinBgPanel
@onready var win_label: Label = %WinLabel
@onready var new_game_button: Button = %NewGameButton
@onready var undo_button: Button = %UndoButton
@onready var auto_complete_button: Button = %AutoCompleteButton
@onready var draw_mode_toggle: CheckButton = %DrawModeToggle
@onready var view_stats_button: Button = %ViewStatsButton
@onready var layout_toggle_button: Button = %LayoutToggleButton
@onready var stats_label: Label = %StatsLabel
@onready var stats_slide_in: CanvasLayer = %StatsSlideIn
@onready var back_button: TextureButton = %back_button

@onready var foundation_slots: Array[Panel] = [
	%FoundationSlot0,
	%FoundationSlot1,
	%FoundationSlot2,
	%FoundationSlot3
]

@onready var tableau_slots: Array[Panel] = [
	%TableauSlot0,
	%TableauSlot1,
	%TableauSlot2,
	%TableauSlot3,
	%TableauSlot4,
	%TableauSlot5,
	%TableauSlot6
]

func _ready() -> void:
	if _layout_metrics == null:
		_layout_metrics = LayoutMetrics.new()
	apply_layout_metrics()

func get_layout_metrics() -> FW_SolitaireLayoutMetrics:
	return _ensure_metrics()

func apply_layout_metrics(metrics: FW_SolitaireLayoutMetrics = null) -> void:
	var resolved := metrics if metrics != null else _ensure_metrics()
	if resolved == null:
		return
	_update_slot_array(foundation_slots, resolved.get_foundation_slot_size(), resolved)
	_update_slot_array(tableau_slots, resolved.get_tableau_slot_size(), resolved)
	_update_panel(stock_panel, resolved.get_stock_slot_size(), resolved)
	_update_panel(waste_panel, resolved.get_waste_slot_size(), resolved)
	_update_slot_corner_styles(resolved)

func _apply_metrics_deferred() -> void:
	if is_inside_tree():
		call_deferred("apply_layout_metrics")
	elif Engine.is_editor_hint():
		call_deferred("apply_layout_metrics")

func _ensure_metrics() -> FW_SolitaireLayoutMetrics:
	if _layout_metrics == null:
		_layout_metrics = LayoutMetrics.new()
		_connect_metrics_signal()
	return _layout_metrics

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

func _on_metrics_resource_changed() -> void:
	apply_layout_metrics(_layout_metrics)

func _update_panel(panel: Control, size: Vector2, _metrics: FW_SolitaireLayoutMetrics) -> void:
	if panel == null:
		return
	panel.custom_minimum_size = size
	if Engine.is_editor_hint():
		panel.size = size
	else:
		panel.set_deferred("size", size)
	panel.pivot_offset = size * 0.5

func _update_slot_array(slots: Array[Panel], size: Vector2, metrics: FW_SolitaireLayoutMetrics) -> void:
	for slot in slots:
		_update_panel(slot, size, metrics)

func _update_slot_corner_styles(metrics: FW_SolitaireLayoutMetrics) -> void:
	var radius := metrics.slot_corner_radius
	var border_width := metrics.slot_border_width
	for slot in foundation_slots:
		_apply_slot_style(slot, radius, border_width)
	for slot in tableau_slots:
		_apply_slot_style(slot, radius, border_width)
	_apply_slot_style(stock_panel, radius, border_width)
	_apply_slot_style(waste_panel, radius, border_width)

func _apply_slot_style(slot: Control, radius: float, border_width: float) -> void:
	if slot == null:
		return
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.15, 0.3)
	style_box.border_color = slot.get_theme_color("border_color", "Panel") if slot.has_theme_color_override("border_color") else Color(0.5, 0.5, 0.5, 0.8)
	style_box.set_border_width_all(int(border_width))
	style_box.set_corner_radius_all(int(radius))
	slot.add_theme_stylebox_override("panel", style_box)
