extends "res://Scripts/base_menu_panel.gd"

signal cancel_button_pressed

func _on_confirm_button_pressed() -> void:
	GDM.super_delete_data()
	Achievements.reset_all_achievements()
	# Force delete achievements file in case
	var ach_path = OS.get_user_data_dir().path_join("achievements2.json")
	if FileAccess.file_exists(ach_path):
		DirAccess.remove_absolute(ach_path)
	GDM.set_data()
	GDM.save_data()
	ScreenRotator.change_scene("res://Scenes/game_menu2.tscn")

func _on_cancel_button_pressed() -> void:
	emit_signal("cancel_button_pressed")
	slide_out()
