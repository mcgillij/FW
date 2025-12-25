extends Resource

class_name FW_QuestRegistry

@export var available_quests: Array[FW_Quest] = []

func get_quest_by_id(quest_id: String) -> FW_Quest:
	for quest in available_quests:
		if quest.quest_id == quest_id:
			return quest
	return null

func get_quests_for_npc(npc_id: String) -> Array[FW_Quest]:
	var npc_quests: Array[FW_Quest] = []
	for quest in available_quests:
		if quest.quest_npc_id == npc_id:
			npc_quests.append(quest)
	return npc_quests

func get_all_available_quests() -> Array[FW_Quest]:
	return available_quests

func add_quest_to_registry(quest: FW_Quest) -> void:
	if not available_quests.has(quest):
		available_quests.append(quest)

func remove_quest_from_registry(quest: FW_Quest) -> void:
	available_quests.erase(quest)
