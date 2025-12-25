extends Node

class_name FW_NPCQuestManager

@export var npc_id: String
@export var quest_registry: FW_QuestRegistry

signal quest_state_changed(quest: FW_Quest)

func _ready() -> void:
	# Connect to quest events if EventBus exists
	if has_node("/root/EventBus"):
		EventBus.quest_completed.connect(_on_quest_completed)
		EventBus.quest_goal_completed.connect(_on_quest_goal_completed)

func get_dialogue_variables() -> Dictionary:
	var variables = {}
	if not quest_registry:
		return variables

	var npc_quests = quest_registry.get_quests_for_npc(npc_id)

	for quest in npc_quests:
		var quest_var_prefix = quest.quest_id
		if quest_var_prefix.is_empty():
			# Fallback to quest name if no ID
			quest_var_prefix = quest.quest_name.to_lower().replace(" ", "_")

		# Check if player has this quest
		var player_has_quest = QuestManager.do_we_already_have_it(quest)
		variables[quest_var_prefix + "_given"] = player_has_quest

		if player_has_quest:
			var is_completed = QuestManager.has_completed_quest(quest)
			var is_cashed_in = QuestManager.is_already_cashed_in(quest)

			variables[quest_var_prefix + "_complete"] = is_completed
			variables[quest_var_prefix + "_cashed_in"] = is_cashed_in

			# Add individual goal completion variables
			for i in range(quest.quest_goals.size()):
				var goal = quest.quest_goals[i]
				variables[quest_var_prefix + "_goal_" + str(i) + "_complete"] = goal.completed
		else:
			# Set default values for quests not yet obtained
			variables[quest_var_prefix + "_complete"] = false
			variables[quest_var_prefix + "_cashed_in"] = false

	return variables

func handle_dialogue_signal(signal_value: String) -> bool:
	if not quest_registry:
		return false

	var npc_quests = quest_registry.get_quests_for_npc(npc_id)

	for quest in npc_quests:
		var quest_var_prefix = quest.quest_id
		if quest_var_prefix.is_empty():
			quest_var_prefix = quest.quest_name.to_lower().replace(" ", "_")

		# Handle quest giving
		if signal_value == "add_" + quest_var_prefix:
			if not QuestManager.do_we_already_have_it(quest):
				QuestManager.add_quest(quest)
				quest_state_changed.emit(quest)
			return true

		# Handle quest completion
		if signal_value == quest_var_prefix + "_completed":
			if QuestManager.has_completed_quest(quest):
				QuestManager.mark_cashed_in(quest)
				quest_state_changed.emit(quest)
			return true

	return false

func get_available_quests_for_npc() -> Array[FW_Quest]:
	if not quest_registry:
		return []
	return quest_registry.get_quests_for_npc(npc_id)

func get_active_quests_for_npc() -> Array[FW_Quest]:
	var active_quests: Array[FW_Quest] = []
	var available_quests = get_available_quests_for_npc()

	for quest in available_quests:
		if QuestManager.do_we_already_have_it(quest):
			active_quests.append(quest)

	return active_quests

func _on_quest_completed(quest: FW_Quest) -> void:
	if quest.quest_npc_id == npc_id and quest.auto_complete:
		# Auto-trigger completion dialogue or reward
		QuestManager.mark_cashed_in(quest)
		quest_state_changed.emit(quest)

func _on_quest_goal_completed(quest: FW_Quest, _goal: FW_QuestGoal) -> void:
	# Handle any special logic when quest goals are completed
	if quest.quest_npc_id == npc_id:
		quest_state_changed.emit(quest)
