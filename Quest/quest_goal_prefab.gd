extends Panel

@onready var quest_goal_name: Label = %quest_goal_name
@onready var quest_goal_description: Label = %quest_goal_description
@onready var quest_goal_image: TextureRect = %quest_goal_image
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var quest_type: Label = %quest_type

var completed_image:Texture2D = load("res://Icons/achievements_icon.png")
var not_completed_image:Texture2D = load("res://Icons/lock_icon.png")
const CONTAINER_SIZE = Vector2(660.0, 154)

func setup(quest_goal: FW_QuestGoal) -> void:
	quest_goal_name.text = quest_goal.quest_goal_name
	quest_goal_description.text = quest_goal.quest_goal_description
	quest_type.text = str(FW_QuestGoal.GOAL_TYPE.keys()[quest_goal.type])
	progress_bar.max_value = quest_goal.required_amount
	progress_bar.min_value = 0
	progress_bar.value = quest_goal.current_amount
	custom_minimum_size = CONTAINER_SIZE
	if quest_goal.completed:
		%quest_goal_image.texture = completed_image
		self_modulate = Color.html("#ff36ff")
	else:
		%quest_goal_image.texture = not_completed_image
