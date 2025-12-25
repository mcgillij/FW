extends HBoxContainer


@onready var skill_label: Label = %skill_label
@onready var skill_value: Label = %skill_value

var skill: String

func _ready() -> void:
	mouse_entered.connect(_on_button_mouse_entered)
	mouse_exited.connect(_on_button_mouse_exited)

func setup(skill_name: String, old_value: float = 0.0, is_modified: bool = false) -> void:
	skill = skill_name
	skill_label.text = skill_name.capitalize() + ": "
	var new_value = GDM.player.stats.get_stat(skill_name)
	if skill_name in GDM.player.stats.INT_STATS:
		skill_value.text = str(int(new_value))
	else:
		#var Utils = load("res://Scripts/FW_Utils.gd")
		skill_value.text = FW_Utils.to_percent(new_value)
	var final_color = Color.DEEP_SKY_BLUE if is_modified else Color.WHITE
	skill_value.self_modulate = final_color
	if new_value != old_value:
		var tween = create_tween()
		tween.tween_property(skill_value, "self_modulate", Color.DEEP_SKY_BLUE, 0.5)
		tween.tween_property(skill_value, "self_modulate", final_color, 0.5).set_delay(0.5)

func _on_button_mouse_entered() -> void:
	skill_label.modulate = Color(1,1,1,.5)
	skill_value.modulate = Color(1,1,1,.5)
	EventBus.skill_hover.emit(skill)

func _on_button_mouse_exited() -> void:
	skill_label.modulate = Color(1,1,1,1)
	skill_value.modulate = Color(1,1,1,1)
	EventBus.skill_unhover.emit()
