extends "res://Scripts/base_menu_panel.gd"

signal back_button

func _on_back_button_pressed() -> void:
	emit_signal("back_button")
