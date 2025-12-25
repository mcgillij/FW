extends RefCounted
class_name FW_MinigameRewardHelper

const DEFAULT_DEBUFF_RESOURCES := [
	preload("res://Buffs/Resources/stabbed_debuff.tres"),
	preload("res://Buffs/Resources/poison_debuff.tres"),
	preload("res://Buffs/Resources/hamstrung_debuff.tres"),
	preload("res://Buffs/Resources/discouraged_debuff.tres"),
	preload("res://Buffs/Resources/cursed_luck_debuff.tres"),
	preload("res://Buffs/Resources/clumsy_debuff.tres"),
	preload("res://Buffs/Resources/butterpaws_debuff.tres"),
	preload("res://Buffs/Resources/bruised_debuff.tres"),
	preload("res://Buffs/Resources/fatigued_debuff.tres"),
]

static func ensure_loot_manager(current: FW_LootManager) -> FW_LootManager:
	if current == null:
		return FW_LootManager.new()
	return current

static func build_debuff_queue(custom_pool: Array) -> Array[FW_Buff]:
	var pool: Array[FW_Buff] = []
	for entry in custom_pool:
		if entry is FW_Buff:
			pool.append(entry)
	if pool.is_empty():
		for resource in DEFAULT_DEBUFF_RESOURCES:
			if resource is FW_Buff:
				pool.append(resource)
	pool.shuffle()
	return pool

static func draw_buff_from_queue(queue: Array) -> FW_Buff:
	if queue.is_empty():
		return null
	var template: Variant = queue.pop_front()
	if template is FW_Buff:
		return duplicate_buff(template)
	return null

static func duplicate_buff(template: FW_Buff) -> FW_Buff:
	if template == null:
		return null
	var buff: FW_Buff = template.duplicate(true)
	if buff.duration > 0 and buff.duration_left <= 0:
		buff.duration_left = buff.duration
	buff.owner_type = "player"
	return buff

static func queue_debuff_on_player(buff: FW_Buff) -> void:
	if buff == null:
		return
	var pending: Array = []
	if GDM.has_meta("pending_combat_buffs"):
		var existing: Variant = GDM.get_meta("pending_combat_buffs")
		if existing is Array:
			pending = existing.duplicate()
	pending.append(buff)
	GDM.set_meta("pending_combat_buffs", pending)

static func mark_minigame_completed(_success: bool = true) -> void:
	# Persist minigame completion and advance progression safely (win or loss)
	if not GDM or not GDM.world_state:
		return
	if not GDM.current_info or not GDM.current_info.world:
		return
	var completed_node: FW_LevelNode = GDM.current_info.level
	if not completed_node:
		return
	var map_hash = GDM.current_info.world.world_hash
	var path_history := GDM.world_state.get_path_history(map_hash)
	var existing = path_history.get(completed_node.level_depth, null)
	if existing and existing is FW_LevelNode and existing.level_hash == completed_node.level_hash:
		return

	GDM.mark_node_cleared(map_hash, completed_node.level_hash, true)
	completed_node.cleared = true
	GDM.world_state.update_path_history(map_hash, completed_node.level_depth, completed_node)
	var max_depth = GDM.current_info.level_to_generate.get("max_depth", 0)
	if completed_node.level_depth == max_depth:
		GDM.world_state.update_completed(map_hash, true)
	var current_level := GDM.world_state.get_current_level(map_hash)
	var next_level := completed_node.level_depth + 1
	if current_level < next_level:
		GDM.world_state.update_current_level(map_hash, next_level)
	GDM.vs_save()
	GDM.player_action_in_progress = false
	GDM.skill_check_in_progress = false
	EventBus.level_completed.emit(completed_node)
