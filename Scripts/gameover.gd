extends "res://Scripts/base_menu_panel.gd"

func _on_quit_button_pressed() -> void:
    ScreenRotator.change_scene("res://Scenes/level_select.tscn")

func _on_restart_button_pressed() -> void:
    ScreenRotator.change_scene(ScreenRotator.get_current_scene_path())

func _on_game_manager_game_lost() -> void:
    slide_in()
