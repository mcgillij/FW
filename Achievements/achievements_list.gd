extends "res://Scripts/base_menu_panel.gd"

signal back_button

@onready var achievement_list: VBoxContainer = %achievement_list
@export var achievement_prefab: PackedScene

var achievements = []

func _ready() -> void:
	for key in Achievements.achievements_keys:
		var a = achievement_prefab.instantiate()
		%achievement_list.add_child(a)
		a.setup(Achievements.get_achievement(key))

func _on_back_button_pressed() -> void:
	emit_signal("back_button")
