extends Panel

@onready var quest_name_label: Label = %quest_name_label
@onready var quest_description_label: Label = %quest_description_label
@onready var quest_goal_container: VBoxContainer = %quest_goal_container
@onready var quest_completed_image: TextureRect = %quest_completed_image
@onready var quest_cashed_in: TextureRect = %quest_cashed_in
@onready var quest_npc_image: TextureRect = %quest_npc_image
@onready var npc_name_label: Label = %npc_name_label

@export var goal_prefab: PackedScene

var completed_image:Texture2D = load("res://Icons/achievements_icon.png")
var not_completed_image:Texture2D = load("res://Icons/lock_icon.png")
var cashed_in_image = load("res://Icons/complete_icon.png")
const CONTAINER_SIZE := Vector2(680, 500)

func setup(quest:FW_Quest) -> void:
	quest_name_label.text = quest.quest_name
	quest_description_label.text = quest.quest_description
	quest_npc_image.texture = quest.quest_npc.image
	npc_name_label.text = quest.quest_npc.name

	custom_minimum_size = CONTAINER_SIZE
	for i in quest.quest_goals:
		var goal = goal_prefab.instantiate()
		quest_goal_container.add_child(goal)
		goal.setup(i)
	quest.check_if_complete()
	if quest.completed:
		if quest.cashed_in:
			quest_cashed_in.texture = cashed_in_image
		%quest_completed_image.texture = completed_image
		self_modulate = Color.GREEN
	else:
		%quest_completed_image.texture = not_completed_image
