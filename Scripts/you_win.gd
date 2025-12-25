extends "res://Scripts/base_menu_panel.gd"

var is_out = false
signal trigger_story

@onready var score_label = $MarginContainer/TextureRect/VBoxContainer/HBoxContainer/score_label
@onready var moves_label = $MarginContainer/TextureRect/VBoxContainer/HBoxContainer2/moves_label

func _on_texture_button_pressed() -> void:
	if  $"../GameManager".level == 60:
		# unlocks boomer
		Achievements.unlock_achievement("boomer")
		GDM.safe_steam_set_achievement("Boomer")
	if $"../GameManager".triggers_story:
		slide_out()
		emit_signal("trigger_story", $"../GameManager".level)
	else:
		ScreenRotator.change_scene("res://Scenes/level_select.tscn")

func _on_game_manager_game_won(score: int, moves: int) -> void:
	score_label.text = str(score)
	moves_label.text = str(moves)
	if is_out == false:
		is_out = true
		slide_in()
