extends "res://Scripts/base_menu_panel.gd"

signal back_button

func _on_back_button_pressed() -> void:
    SoundManager._play_sound(5)
    emit_signal("back_button")
