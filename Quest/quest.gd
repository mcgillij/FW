extends Resource

class_name FW_Quest

# have to make Unique / Recursive on each of the quest goals
# or the progress won't be loaded properly

@export var quest_id: String  # Unique identifier
@export var quest_npc_id: String  # NPC who gives this quest
@export var quest_name: String
@export_multiline var quest_description: String

@export var quest_goals:Array[FW_QuestGoal]
@export var completed := false
@export var cashed_in := false
@export var quest_npc := Resource
@export var auto_complete := false  # Whether quest completes automatically when goals are met
@export var completion_dialogue_id: String  # Dialogue to trigger when completed
@export var dialogue_id: String  # Menu/dialogue key that triggers this quest

func check_if_complete() -> bool:
    completed = quest_goals.all(func(goal): return goal.completed)
    return completed

func matches_quest(other_quest: FW_Quest) -> bool:
    # Use quest_id for comparison if both have it, otherwise use quest_name
    if quest_id != "" and other_quest.quest_id != "":
        return quest_id == other_quest.quest_id
    return quest_name == other_quest.quest_name

func _to_string() -> String:
    return "[Quest: %s (%s)]" % [quest_name, str(completed)]
