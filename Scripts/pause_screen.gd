extends "res://Scripts/base_menu_panel.gd"

func _on_continue_pressed() -> void:
	get_tree().paused = false
	slide_out()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	ScreenRotator.change_scene("res://Scenes/level_select.tscn")

func _on_bottom_ui_pause_game() -> void:
	set_physics_process(true)
	set_process_input(true)
	slide_in()

func _on_obstacles_ui_pause_game() -> void:
	pass
