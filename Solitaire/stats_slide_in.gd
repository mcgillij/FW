extends "res://Scripts/base_menu_panel.gd"

signal back_button

@onready var stats_display: FW_StatsDisplay = %StatsDisplay

func _on_back_button_pressed() -> void:
	emit_signal("back_button")

func update_stats(game_stats: FW_GameStats) -> void:
	if stats_display:
		stats_display.update_display(game_stats)
	else:
		pass  # ERROR: FW_StatsDisplay not found in stats_slide_in
