extends Control

class_name FW_GameDifficulty

signal difficulty_selected

@onready var diff_name_label: Label = %diff_name_label
@onready var diff_image: TextureRect = %diff_image
@onready var diff_desc: RichTextLabel = %diff_desc
@onready var continue_image: TextureRect = %continue_image
@onready var number_of_continues: Label = %number_of_continues
@onready var diff_panel: Panel = %diff_panel
@onready var select_diff_button: Button = %select_diff_button

const CONTINUE_IMAGE := preload("res://DifficultySelect/Images/continue_token.png")

const DIFFICULTY_MAPPING := {
	FW_Player.DIFFICULTY.CASUAL: {
		"name": "Casual",
		"description": "Casual walk in the park!\n Character not saved for PvP",
		"image": "res://DifficultySelect/Images/casual.png",
		"continues": -1,
		"color": Color.LIGHT_GREEN
		},
	FW_Player.DIFFICULTY.NORMAL: {
		"name": "Normal",
		"description": "An stroll through the trail, with almost unlimited continues",
		"image": "res://DifficultySelect/Images/easy.png",
		"continues": 50,
		"color": Color.WEB_GREEN
		 },
	FW_Player.DIFFICULTY.BRAVE: {
		"name": "Brave",
		"description": "An adventure like no other fraught with challenges and perils at every turn!",
		"image": "res://DifficultySelect/Images/normal.png",
		"continues": 15,
		"color": Color.RED
		},
	FW_Player.DIFFICULTY.IRONDOG: {
		"name": "IronDog",
		"description": "Only for the fiercest of adventurers, reduced treasures",
		"image": "res://DifficultySelect/Images/irondog.png",
		"continues": 0,
		"color": Color.MEDIUM_VIOLET_RED
	 },
}

var difficulty: FW_Player.DIFFICULTY

func setup(diff: FW_Player.DIFFICULTY) -> void:
	difficulty = diff
	diff_name_label.text = DIFFICULTY_MAPPING[diff].name
	diff_name_label.self_modulate = DIFFICULTY_MAPPING[diff].color
	diff_image.texture = load(DIFFICULTY_MAPPING[diff].image)
	diff_image.self_modulate = DIFFICULTY_MAPPING[diff].color
	diff_desc.text = DIFFICULTY_MAPPING[diff].description
	continue_image.texture = CONTINUE_IMAGE
	continue_image.self_modulate = FW_Colors.alertness
	if DIFFICULTY_MAPPING[diff].continues == -1: # unlimited from casual
		number_of_continues.text = "Unlimited"
	else:
		number_of_continues.text = str(DIFFICULTY_MAPPING[diff].continues)

func _on_select_diff_button_pressed() -> void:
	emit_signal("difficulty_selected", difficulty)

func _ready() -> void:
	select_diff_button.connect("mouse_entered", _on_mouse_entered)
	select_diff_button.connect("mouse_exited", _on_mouse_exited)

func _on_mouse_entered() -> void:
	diff_panel.self_modulate = Color.GREEN # Example: light yellow highlight

func _on_mouse_exited() -> void:
	diff_panel.self_modulate = Color(1, 1, 1) # Reset to default
