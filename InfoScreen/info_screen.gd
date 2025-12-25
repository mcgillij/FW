extends "res://Scripts/base_menu_panel.gd"

@onready var grid: Node2D = $"../Grid"

func _ready() -> void:
	EventBus.info_screen_in.connect(trigger_slide_in)
	EventBus.info_screen_out.connect(trigger_slide_out)

func trigger_slide_in() -> void:
	grid.visible = false
	self.slide_in()

func trigger_slide_out() -> void:
	grid.visible = true
	self.slide_out()
