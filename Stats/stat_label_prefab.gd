extends VBoxContainer

@onready var stat_image: TextureRect = %stat_image
@onready var letter_label: Label = %letter_label
@onready var stat_value: Label = %stat_value

var my_stat: FW_Stat

func _ready() -> void:
	mouse_entered.connect(_on_button_mouse_entered)
	mouse_exited.connect(_on_button_mouse_exited)

func _on_button_mouse_entered() -> void:
	stat_image.modulate = Color(1,1,1,.5)
	EventBus.stat_hover.emit(my_stat)

func _on_button_mouse_exited() -> void:
	stat_image.modulate = Color(1,1,1,1)
	EventBus.stat_unhover.emit()

func setup(stat: FW_Stat, old_value: float = 0.0, is_modified: bool = false) -> void:
	if !stat_value:
		stat_value = $stat_value
	# Use static API on Colors
	# var c = FW_Colors.new()
	my_stat = stat
	stat_image.texture = stat.stat_image
	letter_label.text = stat.stat_name.left(1)
	var new_value = GDM.player.stats.get_stat(stat.stat_name.to_lower())
	stat_value.text = str(int(new_value))
	var default_color = FW_Colors.get_stat_color(stat)
	var final_color = Color.DEEP_SKY_BLUE if is_modified else default_color
	stat_value.self_modulate = final_color
	if new_value != old_value:
		var tween = create_tween()
		tween.tween_property(stat_value, "self_modulate", Color.DEEP_SKY_BLUE, 0.5)
		tween.tween_property(stat_value, "self_modulate", final_color, 0.5).set_delay(0.5)
