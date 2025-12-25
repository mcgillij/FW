extends Control

class_name FW_CombatNotification

enum message_type { COMBO, CHAIN, BOMB_CHAIN, BOMB_COMBO, SPECIAL, GIGA_CLEAR, MANA_SURGE, DEFAULT }

signal combat_notification_over

@onready var combat_label: Label = %combat_label

var notification_queue: Array = []
var notification_active: bool = false
var base_position: Vector2 # = Vector2(40, get_viewport_rect().size.y - 120)
var vertical_offset: float = 40.0

func _ready() -> void:
	base_position = combat_label.position
	EventBus.combat_notification.connect(combat_notification)

func combat_notification(m_type: FW_CombatNotification.message_type = FW_CombatNotification.message_type.DEFAULT, custom_message: String = "") -> void:
	notification_queue.append({ "type": m_type, "message": custom_message })
	process_notification_queue()

func process_notification_queue():
	if notification_active or notification_queue.is_empty():
		return
	notification_active = true
	var next = notification_queue.pop_front()
	var queue_index = notification_queue.size()
	var pos = base_position - Vector2(0, vertical_offset * queue_index)
	combat_label.position = pos

	combat_label.modulate = Color(1, 1, 1, 0)
	combat_label.scale = Vector2(0.5, 0.5)
	combat_label.rotation_degrees = randf_range(-30, 30)

	combat_label.self_modulate = get_type_color(next.type)
	var final_angle = randf_range(-45, -10)
	combat_label.text = next.message if next.message != "" else get_random_combat_message(next.type)
	combat_label.show()

	var anchor_pos = combat_label.position
	#var start_offset = Vector2(randf_range(-100, 100), randf_range(-50, 50))
	combat_label.position = anchor_pos #+ start_offset

	var start_scale = Vector2(randf_range(0.4, 0.7), randf_range(0.4, 0.7))
	combat_label.scale = start_scale
	var end_scale = Vector2(1, 1) + Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))

	var mid_color = get_type_color(next.type)
	var end_color = Color(1, 1, 1, 0)

	var move_duration = randf_range(0.18, 0.35)
	var scale_duration = randf_range(0.15, 0.25)
	var rotate_duration = randf_range(0.22, 0.35)
	var fade_out_delay = randf_range(0.8, 1.2)
	var fade_out_duration = randf_range(0.22, 0.35)

	# Play sound based on type
	#SoundManager._play_combat_notification_sound(message_type)

	var tween = create_tween()
	tween.tween_property(combat_label, "modulate", mid_color, move_duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(combat_label, "position", anchor_pos, move_duration).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(combat_label, "scale", end_scale, scale_duration).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(combat_label, "rotation_degrees", final_angle, rotate_duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(combat_label, "scale", Vector2(1, 1), 0.3)
	tween.tween_interval(fade_out_delay)
	tween.tween_property(combat_label, "modulate", end_color, fade_out_duration)
	tween.tween_callback(Callable(self, "_on_combat_notification_over"))

func _on_combat_notification_over() -> void:
	notification_active = false
	process_notification_queue()

func get_combat_messages(m_type: FW_CombatNotification.message_type) -> Array:
	var messages = {
		FW_CombatNotification.message_type.COMBO: [
			"Combo!",
			"Combo!!",
			"Combo Chain!",
            "Wild Combo!"
		],
		FW_CombatNotification.message_type.CHAIN: [
			"Chain!",
			"Chain!!",
            "Chain!!!"
		],
		FW_CombatNotification.message_type.BOMB_CHAIN: [
			"Bomb Chain!",
			"Bomb Chain!!",
            "Bomb CHAIN!!!"
		],
		FW_CombatNotification.message_type.BOMB_COMBO: [
			"Bomb COMBO!",
			"Bomb COMBO!!",
            "Bomb COMBO!!!"
		],
		FW_CombatNotification.message_type.GIGA_CLEAR: [
			"SCREEN WIPE!",
			"GIGA CLEAR!!",
            "DOUBLE COLOR!!!"
		],
		FW_CombatNotification.message_type.SPECIAL: [
			"Critical Hit!",
			"Finisher!",
			"Ultimate Move!",
            "Special Attack!"
		],
		FW_CombatNotification.message_type.DEFAULT: [
			"Attack!",
			"Strike!",
			"Hit!",
            "Go!"
		],
		FW_CombatNotification.message_type.MANA_SURGE: [
			"Mana Surge!"
		]
	}
	return messages.get(m_type, messages[FW_CombatNotification.message_type.DEFAULT])

func get_random_combat_message(m_type: FW_CombatNotification.message_type) -> String:
	var messages = get_combat_messages(m_type)
	return messages[randi() % messages.size()]

func get_type_color(m_type: FW_CombatNotification.message_type) -> Color:
	match m_type:
		FW_CombatNotification.message_type.COMBO:
			return Color(1, 0.7, 0.2, 1) # Orange
		FW_CombatNotification.message_type.BOMB_CHAIN:
			return Color.PALE_VIOLET_RED # PALE_VIOLET_RED
		FW_CombatNotification.message_type.BOMB_COMBO:
			return Color.VIOLET # VIOLET
		FW_CombatNotification.message_type.CHAIN:
			return Color(0.2, 0.8, 1, 1) # Blue
		FW_CombatNotification.message_type.GIGA_CLEAR:
			return Color.YELLOW # Yellow
		FW_CombatNotification.message_type.SPECIAL:
			return Color(1, 0.2, 0.6, 1) # Pink
		FW_CombatNotification.message_type.MANA_SURGE:
			return Color.CYAN # Cyan - electric mana energy
		_: # DEFAULT
			return Color(1, 1, 1, 1) # White

func _on_button_pressed() -> void:
	combat_notification()
