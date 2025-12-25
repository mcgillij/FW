extends Button

@export var bar: FW_ManaBar

func _on_pressed() -> void:
	bar.change_value(bar.current_value + 10)

func _on2_pressed() -> void:
	bar.change_value(bar.current_value - 10)
