extends Control

signal battle_notification_over

@onready var battle_label: Label = %battle_label

func battle_notification() -> void:
	battle_label.modulate = Color(1, 1, 1, 0) # Start invisible
	battle_label.scale = Vector2(0.5, 0.5)    # Start small
	battle_label.rotation_degrees = randf_range(-30, 30) # Random angle

	battle_label.self_modulate = Color.RED
	var final_angle = randf_range(-45, -10)
	battle_label.text = get_random_battle_message()
	battle_label.show()

	# Anchor position (where the message should end up)
	var anchor_pos = battle_label.position

	# Randomize starting offset and direction
	var start_offset = Vector2(randf_range(-200, 200), randf_range(-100, 100))
	battle_label.position = anchor_pos + start_offset

	# Randomize scale and color
	var start_scale = Vector2(randf_range(0.4, 0.7), randf_range(0.4, 0.7))
	battle_label.scale = start_scale
	var end_scale = Vector2(1, 1) + Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))

	var mid_color = Color(randf_range(0.8, 1), randf_range(0.2, 1), randf_range(0.2, 1), 1)
	var end_color = Color(1, 1, 1, 0)

	# Randomize tween durations and easing
	var move_duration = randf_range(0.18, 0.35)
	var scale_duration = randf_range(0.15, 0.25)
	var rotate_duration = randf_range(0.22, 0.35)
	var fade_out_delay = randf_range(0.8, 1.2)
	var fade_out_duration = randf_range(0.22, 0.35)
	# sound
	SoundManager._play_battle_notification_sound()

	var tween = create_tween()
	tween.tween_property(battle_label, "modulate", mid_color, move_duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(battle_label, "position", anchor_pos, move_duration).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(battle_label, "scale", end_scale, scale_duration).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(battle_label, "rotation_degrees", final_angle, rotate_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(battle_label, "scale", Vector2(1, 1), 0.3)
	tween.tween_interval(fade_out_delay)
	tween.tween_property(battle_label, "modulate", end_color, fade_out_duration)
	#tween.tween_callback(trigger_level_start)
	tween.tween_callback(Callable(self, "_on_battle_notification_over"))

func _on_battle_notification_over() -> void:
	emit_signal("battle_notification_over")

func get_battle_messages() -> Array:
	return [
		"To Battle!",
		"Prepare for Battle!",
		"Let the Battle Begin!",
		"Battle Awaits!",
		"Face Your Foe!",
		"Clash of Titans!",
		"Engage the Enemy!",
		"Time to Fight!",
		"Draw Your Weapons!",
		"Ready for Combat!",
		"Charge!",
		"Sound the Warhorn!",
		"Unleash Fury!",
		"Steel Yourself!",
		"Let’s Do Battle!",
		"Arf!",
		"Fight for Glory!",
		"Defend Your Honor!",
		"Stand and Fight!",
		"Enter the Fray!",
		"Raise Your Blade!",
		"Bark!",
		"Prepare to Duel!",
		"Ready Your Arms!",
		"Battle Stations!",
		"Let’s Rumble!",
		"Show No Mercy!",
		"Time for War!",
		"Let’s Throw Down!",
		"Ready to Rumble!",
		"Let’s Clash!",
		"War Cries Echo!",
		"Let’s Go to War!",
		"Prepare for Glory!",
		"Get Dangerous!",
		"Test Your Mettle!",
		"It's GO TIME!",
		"Let's get it on!",
        "Time to fight!"
	]

func get_random_battle_message() -> String:
	var messages = get_battle_messages()
	return messages[randi() % messages.size()]
