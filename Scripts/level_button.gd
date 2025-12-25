extends Node2D

@export var level: int
var level_resource_path: String = "res://Levels/level"
var scene_extension: String = ".tscn"

@export var enabled: bool
@export var score_goal_met: bool

@export var blocked_texture: Texture2D
@export var open_texture: Texture2D
@export var open_unplayed_texture: Texture2D
@export var goal_met: Texture2D
@export var goal_not_met: Texture2D

@onready var levelbutton: TextureButton = %levelbutton
@onready var level_label: Label = %level_label
@onready var score_label: Label = %score_label
@onready var moves_label: Label = %moves_label
@onready var star: Sprite2D = %star

signal save_scroll_value

var original_material: Material
var hover_shader: ShaderMaterial = FW_Utils.shader_material()

func setup() -> void:
	level_label.text = str(level)
	if enabled:
		if GDM.level_info[level].has("high_score"):
			levelbutton.texture_normal = open_texture
		else:
			levelbutton.texture_normal = open_unplayed_texture
		levelbutton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		levelbutton.texture_normal = blocked_texture
	if GDM.level_info.has(level):
		if GDM.level_info[level].has("high_score"):
			score_label.text = str(GDM.level_info[level]["high_score"])
		if GDM.level_info[level].has("moves"):
			moves_label.text = str(GDM.level_info[level]["moves"])

	if score_goal_met:
		star.texture = goal_met
	else:
		star.texture = goal_not_met

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	original_material = levelbutton.material
	levelbutton.mouse_entered.connect(_on_button_mouse_entered)
	levelbutton.mouse_exited.connect(_on_button_mouse_exited)
	if GDM.level_info.has(level):
		enabled = GDM.level_info[level]["unlocked"]
		if GDM.level_info[level].has("stars_unlocked"):
			if GDM.level_info[level]["stars_unlocked"] == 1:
				score_goal_met = true
			else:
				score_goal_met = false

	else:
		enabled = false
	setup()

func _on_levelbutton_pressed() -> void:
	if enabled:
		get_parent().emit_signal("save_scroll_value")
		ScreenRotator.change_scene(level_resource_path + str(level) + scene_extension)

func _on_levelbutton_focus_entered() -> void:
	get_parent().emit_signal("controller_scroll", position)

func _on_button_mouse_entered() -> void:
	if enabled:
		levelbutton.material = hover_shader

func _on_button_mouse_exited() -> void:
	levelbutton.material = original_material
