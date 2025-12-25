extends Control
class_name FW_SkillCheck

signal skill_check_result

@onready var skill_label: Label = $Panel/MarginContainer/VBoxContainer/skill_label
@onready var result_value: Label = $VBoxContainer/HBoxContainer/result_value

@onready var target_value: Label = $VBoxContainer/target_value
@onready var check_result_label: Label = $check_result_label
@onready var roll_value: Label = $VBoxContainer/HBoxContainer/roll_value
@onready var skill_value: Label = $VBoxContainer/HBoxContainer/skill_value

@onready var roll_dice_button: TextureButton = $roll_dice_button

var skill: FW_SkillCheckRes
var is_processing_result := false

const success_string := "Success!"
const failure_string := "Fail!"
var level_name: String # used as a unique identifier for signals
var final_angle = 45
var success_or_fail_label_pos: Vector2

func _exit_tree() -> void:
	# Godot Best Practice: Always disconnect from global singletons when the node is freed.
	var c = Callable(self, "_on_dice_roll_results")
	if EventBus.is_connected("dice_roll_result_for", c):
		EventBus.dice_roll_result_for.disconnect(c)

	# If this skill check UI is being destroyed while a check is in progress,
	# reset the global flag to prevent blocking future checks
	if GDM.skill_check_in_progress:
		GDM.skill_check_in_progress = false

func setup(skill_p: FW_SkillCheckRes, level_name_p: String) -> void:
	if !skill_label:
		skill_label = %skill_label
	if !target_value:
		target_value = %target_value
	if !roll_dice_button:
		roll_dice_button = %roll_dice_button
	if !check_result_label:
		check_result_label = %check_result_label
	level_name = level_name_p
	skill = skill_p
	skill_label.text = skill.skill_name + ": " + str(int(GDM.player.stats.get_stat(skill.skill_name.to_lower())))
	skill_label.self_modulate = skill.color
	target_value.text = str(skill.target)
	roll_dice_button.self_modulate = skill.color

	# Reset the skill check state for fresh use
	is_processing_result = false
	roll_dice_button.disabled = false
	check_result_label.hide()

	# Connect to the global event bus, ensuring it only happens once.
	var c = Callable(self, "_on_dice_roll_results")
	if not EventBus.is_connected("dice_roll_result_for", c):
		EventBus.dice_roll_result_for.connect(c)

	success_or_fail_label_pos = check_result_label.position

func show_skill_check_result(success: bool) -> void:
	check_result_label.modulate = Color(1, 1, 1, 0) # Start invisible
	check_result_label.scale = Vector2(0.5, 0.5)    # Start small
	check_result_label.rotation_degrees = randf_range(-30, 30) # Random angle

	if success:
		check_result_label.text = self.success_string
		check_result_label.self_modulate = Color.GREEN
		final_angle = randf_range(10, 45)
		check_result_label.position = success_or_fail_label_pos
		SoundManager._play_random_positive_sound()
	else:
		check_result_label.text = self.failure_string
		check_result_label.self_modulate = Color.RED
		final_angle = randf_range(-45, -10)
		check_result_label.position = Vector2(-30, 50) # Down and to the left
		SoundManager._play_random_negative_sound()

	check_result_label.show()
	var tween = create_tween()
	tween.tween_property(check_result_label, "modulate", Color(1, 1, 1, 1), 0.25).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(check_result_label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(check_result_label, "rotation_degrees", final_angle, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(check_result_label, "scale", Vector2(1, 1), 0.1)
	# Optional: fade out after a delay
	tween.tween_interval(1.0)
	tween.tween_property(check_result_label, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(Callable(emit_signal).bind("skill_check_result", success, skill))
	# Reset processing state after the signal is emitted
	tween.tween_callback(func(): GDM.skill_check_in_progress = false)
	tween.tween_callback(func(): GDM.player_action_in_progress = false)  # Allow other actions again

func _on_dice_roll_results(roll: int, roll_for: String) -> void:
	if roll_for == level_name: # filter all the other nodes
		if is_processing_result: # Prevent double execution
			return
		is_processing_result = true

		roll_value.text = str(roll) + " + "
		skill_value.text = str(int(GDM.player.stats.get_stat(skill.skill_name.to_lower()))) + " = "
		skill_value.self_modulate = skill.color
		result_value.text = str(roll + int(GDM.player.stats.get_stat(skill.skill_name.to_lower())))
		var result = perform_skill_check(skill, roll)
		if result:
			result_value.self_modulate = Color.GREEN
		else:
			result_value.self_modulate = Color.RED
		show_skill_check_result(result)

func perform_skill_check(skill_res: FW_SkillCheckRes, roll: int) -> bool:
	var total = roll + GDM.player.stats.get_stat(skill_res.skill_name.to_lower())
	return total >= skill_res.target

func _on_roll_dice_button_pressed() -> void:
	if GDM.skill_check_in_progress or GDM.player_action_in_progress:
		return
	GDM.skill_check_in_progress = true
	GDM.player_action_in_progress = true  # Prevent other actions during skill check
	roll_dice_button.disabled = true
	# Ensure the dice viewport is enabled and has a frame to start physics
	# processing before we trigger the dice roll. This prevents the dice
	# from starting from stale positions when the viewport was just shown.
	EventBus.show_dice.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	EventBus.trigger_roll.emit(level_name)
