extends "res://Scripts/base_menu_panel.gd"

signal confirm_button_pressed

func _on_confirm_button_pressed() -> void:
	emit_signal("confirm_button_pressed")

func _on_cancel_button_pressed() -> void:
	slide_out()
