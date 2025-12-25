extends Node

func add_quest(quest: FW_Quest) -> void:
	if not do_we_already_have_it(quest):
		var quest_instance = quest.duplicate(true)
		GDM.player.quests.append(quest_instance)
		EventBus.quest_added.emit(quest_instance)

func update_quest_progress(goal_type: FW_QuestGoal.GOAL_TYPE, target, amount: int = 1) -> void:
	for quest in GDM.player.quests:
		var quest_was_completed = quest.completed
		for goal in quest.quest_goals:
			var goal_was_completed = goal.completed
			if goal.completed:
				continue
			match goal_type:
				FW_QuestGoal.GOAL_TYPE.COLLECT:
					if goal.collect_target == target:
						goal.add_progress(amount)
				FW_QuestGoal.GOAL_TYPE.ELIMINATE:
					if goal.target == target:
						goal.add_progress(amount)
				FW_QuestGoal.GOAL_TYPE.VISIT:
					if goal.target == target:
						goal.add_progress(amount)
				FW_QuestGoal.GOAL_TYPE.SPECIAL:
					pass
			if not goal_was_completed and goal.completed:
				EventBus.quest_goal_completed.emit(quest, goal)
		quest.check_if_complete()
		if not quest_was_completed and quest.completed:
			EventBus.quest_completed.emit(quest)

func get_active_quests() -> Array:
	return GDM.player.quests

func get_required_quest_items_for_quest(quest: FW_Quest) -> Array[FW_QuestItem]:
	var needed_items: Array[FW_QuestItem] = []
	for goal in quest.quest_goals:
		if goal.type == FW_QuestGoal.GOAL_TYPE.COLLECT: # and not goal.completed:
			if goal.collect_target != null and not needed_items.has(goal.collect_target):
				needed_items.append(goal.collect_target)
	return needed_items

func do_we_already_have_it(quest: FW_Quest) -> bool:
	for q in GDM.player.quests:
		if q.matches_quest(quest):
			return true
	return false

func get_quest_item_counts_for_quest(quest: FW_Quest) -> Dictionary:
	var counts: Dictionary = {}
	var required_items = get_required_quest_items_for_quest(quest)
	# Use the item's name as the key
	for item in required_items:
		counts[item.name] = 0
	for inv_item in GDM.player.inventory:
		for req_item in required_items:
			if inv_item.name == req_item.name:
				counts[req_item.name] += 1
	return counts

# Legacy function - kept for debugging/manual sync purposes
# Collection quest progress is now updated automatically when items are added to inventory
func update_collect_quest_goals_from_inventory_for_quest(quest: FW_Quest) -> void:
	var item_counts = get_quest_item_counts_for_quest(quest)
	for goal in quest.quest_goals:
		if goal.type == FW_QuestGoal.GOAL_TYPE.COLLECT and not goal.completed:
			if goal.collect_target != null and item_counts.has(goal.collect_target.name):
				var count = item_counts[goal.collect_target.name]
				goal.current_amount = min(count, goal.required_amount)
				goal.completed = goal.current_amount >= goal.required_amount
	quest.check_if_complete()

func has_completed_quest(quest: FW_Quest) -> bool:
	for q in GDM.player.quests:
		if q.matches_quest(quest) and q.completed and not q.cashed_in:
			return true
	return false

func is_already_cashed_in(quest: FW_Quest) -> bool:
	for q in GDM.player.quests:
		if q.matches_quest(quest) and q.completed and q.cashed_in:
			return true
	return false

func mark_cashed_in(quest: FW_Quest) -> void:
	for q in GDM.player.quests:
		if q.matches_quest(quest) and q.completed:
			q.cashed_in = true
			remove_quest_items_for_quest(q)
	GDM.vs_save()

func remove_quest_items_for_quest(quest: FW_Quest) -> void:
	var required_items = get_required_quest_items_for_quest(quest)
	for item in required_items:
		GDM.player.inventory = GDM.player.inventory.filter(func(inv_item):
			if inv_item.name == item.name:
				return false
			return true
		)
