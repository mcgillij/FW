extends "res://Scripts/base_menu_panel.gd"
signal back_button

@onready var ascension_level_list: ItemList = %ascension_level_list

func _ready() -> void:
	var first: bool = true
	for i in FW_GameConstants.ascension_levels:
		if first:
			first = false
			ascension_level_list.add_item(i)
		else:
			ascension_level_list.add_item(i, load("res://Icons/ascension_icon.png"))

func _on_back_button_pressed() -> void:
	emit_signal("back_button")
