extends Node
class_name FW_SkillCheckLogic

signal skill_check_result(result: Dictionary, skill_res: FW_SkillCheckRes)

var skill: FW_SkillCheckRes
var level_name: String
var is_processing_result := false
var timeout_timer: Timer

static func perform_skill_check_async(skill_res: FW_SkillCheckRes, level_name_p: String) -> Dictionary:
	"""Static method to perform a skill check asynchronously. Returns dict with success, roll, total."""
	var logic = FW_SkillCheckLogic.new()
	logic.skill = skill_res
	logic.level_name = level_name_p
	logic.is_processing_result = false

	# Add to tree temporarily for signal handling
	var root = Engine.get_main_loop().root
	root.add_child(logic)

	# Connect signal
	var result = await logic._perform_roll_and_wait()

	# Cleanup
	root.remove_child(logic)
	logic.queue_free()

	return result

func _perform_roll_and_wait() -> Dictionary:
	# Connect to EventBus
	var c = Callable(self, "_on_dice_roll_results")
	if not EventBus.is_connected("dice_roll_result_for", c):
		EventBus.dice_roll_result_for.connect(c)

	# Trigger roll
	if GDM.skill_check_in_progress:
		return {
			"success": false,
			"roll": 0,
			"total": 0,
			"stat_value": GDM.player.stats.get_stat(skill.skill_name.to_lower()),
			"target": skill.target
		}
	GDM.skill_check_in_progress = true
	EventBus.show_dice.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	EventBus.trigger_roll.emit(level_name)

	# Start timeout timer to prevent hanging
	timeout_timer = Timer.new()
	timeout_timer.wait_time = 10.0  # 10 seconds timeout
	timeout_timer.one_shot = true
	timeout_timer.timeout.connect(_on_timeout)
	add_child(timeout_timer)
	timeout_timer.start()

	# Wait for result
	var result = await skill_check_result
	timeout_timer.stop()
	return result[0]  # Return the result dictionary

func _on_timeout() -> void:
	# Timeout occurred, reset state and emit failure
	var result = {
		"success": false,
		"roll": 0,
		"total": 0,
		"stat_value": GDM.player.stats.get_stat(skill.skill_name.to_lower()),
		"target": skill.target
	}
	# Emit a failure result and clear global flags so UI is responsive again
	skill_check_result.emit(result, skill)
	GDM.skill_check_in_progress = false
	GDM.player_action_in_progress = false
	is_processing_result = false

	# Ensure timer is stopped and freed
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()

func _on_dice_roll_results(roll: int, roll_for: String) -> void:
	if roll_for == level_name:
		if is_processing_result:
			return
		is_processing_result = true
		var stat_value = GDM.player.stats.get_stat(skill.skill_name.to_lower())
		var total = roll + stat_value
		var success = total >= skill.target
		var result = {
			"success": success,
			"roll": roll,
			"total": total,
			"stat_value": stat_value,
			"target": skill.target
		}
		skill_check_result.emit(result, skill)
		# Clear global flags to allow other UI interactions
		GDM.skill_check_in_progress = false
		GDM.player_action_in_progress = false
		is_processing_result = false

func _exit_tree() -> void:
	var c = Callable(self, "_on_dice_roll_results")
	if EventBus.is_connected("dice_roll_result_for", c):
		EventBus.dice_roll_result_for.disconnect(c)
	if timeout_timer:
		timeout_timer.stop()
		timeout_timer.queue_free()

	# Make sure global flags are reset if this logic node is freed prematurely
	GDM.skill_check_in_progress = false
	GDM.player_action_in_progress = false
