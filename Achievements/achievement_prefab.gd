extends Panel

@onready var image: TextureRect = %image
@onready var desc: RichTextLabel = %desc
@onready var achievement_name: Label = %achievement_name
@onready var locked_image: TextureRect = %locked_image
@onready var current_progress: ProgressBar = %current_progress

@export var locked_texture: Texture2D
@export var unlocked_texture: Texture2D

func setup(achievement: Dictionary) -> void:
	if !image:
		image = %image
	if !desc:
		desc = %desc
	if !achievement_name:
		achievement_name = %achievement_name
	var png = load(achievement.get("icon_path"))
	image.texture = png
	var unlocked: bool = achievement.get("unlocked")
	if unlocked:
		locked_image.texture = unlocked_texture
		locked_image.self_modulate = Color.YELLOW
		self_modulate = Color.GREEN
	else:
		locked_image.texture = locked_texture
	var progress_value = achievement.get("current_progress")
	current_progress.value = progress_value
	desc.text = achievement.get("description")
	achievement_name.text = achievement.get("name")

func _gui_input(event):
	if (
		(event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT) or
		event is InputEventScreenDrag
	):
		var scroll = find_parent_scrollcontainer()
		if scroll:
			scroll.scroll_vertical -= event.relative.y

func find_parent_scrollcontainer():
	var node = get_parent()
	while node:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null
