extends "res://Scripts/base_menu_panel.gd"

@onready var run_container: VBoxContainer = %run_container
@onready var back_button: TextureButton = %back_button
@export var history_prefab: PackedScene


func setup() -> void:
	var run_stats = FW_RunStatistics.new()
	var results = run_stats.load_all_statistics()
	results.reverse()
	for i in results:
		var p = history_prefab.instantiate()
		run_container.add_child(p)
		p.setup(i)

func _on_back_button_pressed() -> void:
	slide_out()
