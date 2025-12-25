extends Resource

class_name FW_QuestGoal

enum GOAL_TYPE { COLLECT, ELIMINATE, VISIT, SPECIAL }

@export var quest_goal_name: String
@export_multiline var quest_goal_description: String

@export var type: GOAL_TYPE
@export var target: String = ""  # e.g., "goblin", "forest"
@export var collect_target: FW_QuestItem
@export var required_amount: int = 1
@export var current_amount: int = 0
@export var completed: bool = false

func add_progress(amount: int = 1) -> void:
    if completed:
        return
    current_amount += amount
    if current_amount >= required_amount:
        current_amount = required_amount
        completed = true

func _to_string() -> String:
    return "[QG: %s (%s), required: %s, current: %s, completed: %s ]" % [quest_goal_name, str(GOAL_TYPE.keys()[type]), str(required_amount), str(current_amount), str(completed)]
