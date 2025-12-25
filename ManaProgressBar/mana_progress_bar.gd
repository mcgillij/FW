class_name FW_ManaBar extends Control

@export var bar_color: Color

@export var min_value: int
@export var max_value: int
@export var current_value: int
@export var top_layer_bar_time: = 0.2
@export var top_layer_bar_delay := 0
@export var bottom_layer_bar_time: = 0.4
@export var bottom_layer_bar_delay := 0.1
@export var left_to_right: bool = false

@onready var bottom_layer: ProgressBar = %BottomLayer
@onready var top_layer: ProgressBar = %TopLayer
@onready var value_label: Label = %value_label

func set_default_values(bar: ProgressBar, new_max_value: int) -> void:
	bar.min_value = min_value
	bar.max_value = new_max_value
	bar.value = current_value
	value_label.text = str(min_value) + "/" + str(max_value)

func set_fill_side() -> void:
	if !left_to_right:
		bottom_layer.fill_mode = ProgressBar.FillMode.FILL_END_TO_BEGIN
		top_layer.fill_mode = ProgressBar.FillMode.FILL_END_TO_BEGIN

func _ready() -> void:
	# apply defaults first so top_layer.max_value is correct before we compute shader fraction
	set_default_values(bottom_layer, max_value)
	set_default_values(top_layer, max_value)
	var new_top_stylebox_normal = top_layer.get_theme_stylebox("fill").duplicate()
	new_top_stylebox_normal.bg_color = bar_color
	top_layer.add_theme_stylebox_override("fill", new_top_stylebox_normal)
	var new_bottom_stylebox_normal = bottom_layer.get_theme_stylebox("background").duplicate()
	new_bottom_stylebox_normal.bg_color = bar_color.darkened(.4)
	bottom_layer.add_theme_stylebox_override("background", new_bottom_stylebox_normal)

func update_max(value: int) -> void:
	max_value = value
	set_default_values(bottom_layer, value)
	set_default_values(top_layer, value)

func change_value(value: int) -> void:
	var old_value = current_value
	current_value = clampi(value, min_value, max_value)
	value_label.text = str(current_value) + "/" + str(max_value)
	if old_value > current_value:
		do_tween(top_layer, current_value, top_layer_bar_time, top_layer_bar_delay)
		do_tween(bottom_layer, current_value, bottom_layer_bar_time, bottom_layer_bar_delay)
	else:
		do_tween(top_layer, current_value, bottom_layer_bar_time, bottom_layer_bar_delay)
		do_tween(bottom_layer, current_value, top_layer_bar_time, top_layer_bar_delay)

func do_tween(bar: ProgressBar, value: int, length: float, delay: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(bar, "value", value, length).set_delay(delay) #.set_trans()
