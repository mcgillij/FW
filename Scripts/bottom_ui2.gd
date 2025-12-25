extends TextureRect

signal pause_game
signal booster_pressed
signal show_hide_booster
signal hide_ingame_combat_log
signal show_ingame_combat_log

@onready var pause: TextureButton = %pause
@onready var booster_manager: FW_BoosterManager = %booster_holder
@onready var ability_info_button: TextureButton = %ability_info_button
@onready var combat_log_button: TextureButton = %combat_log_button

# Click-hold configuration
const LONG_PRESS_DURATION: float = 0.7  # Configurable: seconds to hold for info popup
const BOOSTER_SLOT_COUNT := 5
var press_timers: Dictionary = {}  # slot_index -> timer
var is_long_press: Dictionary = {}  # slot_index -> bool
var press_feedback_tweens: Dictionary = {}  # slot_index -> tween for visual feedback
var booster_buttons: Array[TextureButton] = []
var activation_tweens: Dictionary = {}

var info_toggle := false

func _ready() -> void:
	var slots_ready_callable := Callable(self, "_on_booster_slots_ready")
	if booster_manager and not booster_manager.slots_ready.is_connected(slots_ready_callable):
		booster_manager.slots_ready.connect(slots_ready_callable)
	await get_tree().process_frame
	_initialize_booster_buttons()

func _initialize_booster_buttons() -> void:
	_cleanup_press_state()
	booster_buttons.clear()
	if booster_manager:
		for button in booster_manager.get_booster_buttons():
			if button:
				booster_buttons.append(button)
	if booster_buttons.is_empty():
		call_deferred("_initialize_booster_buttons")
		return
	for i in range(booster_buttons.size()):
		is_long_press[i] = false

func _cleanup_press_state() -> void:
	for timer in press_timers.values():
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	press_timers.clear()
	is_long_press.clear()
	for slot_index in press_feedback_tweens.keys():
		var tween: Tween = press_feedback_tweens[slot_index]
		if is_instance_valid(tween):
			tween.kill()
	press_feedback_tweens.clear()
	for slot_index in activation_tweens.keys():
		var tween: Tween = activation_tweens[slot_index]
		if is_instance_valid(tween):
			tween.kill()
		var button := _get_booster_button(slot_index)
		if button:
			button.scale = Vector2.ONE
			button.rotation_degrees = 0.0
	activation_tweens.clear()

func _on_booster_slots_ready() -> void:
	_initialize_booster_buttons()

func _handle_booster_button_release(slot_index: int) -> void:
	var was_long_press: bool = is_long_press.get(slot_index, false)
	if was_long_press:
		is_long_press[slot_index] = false
		return
	is_long_press[slot_index] = false
	var ability := _get_player_ability(slot_index)
	if ability != null:
		_trigger_ability(slot_index)
		_play_activation_feedback(slot_index)

func _get_booster_button(slot_index: int) -> TextureButton:
	"""Helper to get the booster button node by index"""
	if slot_index >= 0 and slot_index < booster_buttons.size():
		return booster_buttons[slot_index]
	if booster_manager:
		var refreshed: Array = booster_manager.get_booster_buttons()
		booster_buttons.clear()
		for button in refreshed:
			if button:
				booster_buttons.append(button)
		if slot_index >= 0 and slot_index < booster_buttons.size():
			return booster_buttons[slot_index]
	return null

func _start_press_timer(slot_index: int) -> void:
	"""Start timing for long press detection"""
	# Cancel existing timer if any
	if press_timers.has(slot_index) and press_timers[slot_index] != null:
		press_timers[slot_index].queue_free()

	# Reset long press flag
	is_long_press[slot_index] = false

	# Create new timer
	var timer = Timer.new()
	timer.wait_time = LONG_PRESS_DURATION
	timer.one_shot = true
	add_child(timer)
	press_timers[slot_index] = timer

	# Add visual feedback - slight scale pulse
	_start_press_feedback(slot_index)

	# Connect to mark as long press when timer completes
	timer.timeout.connect(func():
		is_long_press[slot_index] = true
		_show_ability_info(slot_index)
		_stop_press_feedback(slot_index)
	)

	timer.start()

func _cancel_press_timer(slot_index: int) -> void:
	"""Cancel press timer (user released or moved mouse away)"""
	if press_timers.has(slot_index) and press_timers[slot_index] != null:
		press_timers[slot_index].stop()
		press_timers[slot_index].queue_free()
		press_timers[slot_index] = null

	_stop_press_feedback(slot_index)

func _start_press_feedback(slot_index: int) -> void:
	"""Visual feedback while holding button"""
	var button = _get_booster_button(slot_index)
	if button:
		# Cancel existing tween
		if press_feedback_tweens.has(slot_index) and press_feedback_tweens[slot_index]:
			press_feedback_tweens[slot_index].kill()

		# Ensure the wobble pivots around center
		button.pivot_offset = button.size * 0.5
		if button.pivot_offset == Vector2.ZERO and button.custom_minimum_size != Vector2.ZERO:
			button.pivot_offset = button.custom_minimum_size * 0.5
		button.rotation_degrees = 0.0
		button.scale = Vector2(1.0, 1.0)

		# Subtle wobble effect: scale pulse with a gentle tilt
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(button, "rotation_degrees", 3.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(button, "rotation_degrees", -3.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(button, "rotation_degrees", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		press_feedback_tweens[slot_index] = tween

func _play_activation_feedback(slot_index: int) -> void:
	var button := _get_booster_button(slot_index)
	if button == null:
		return
	if activation_tweens.has(slot_index):
		var existing: Tween = activation_tweens[slot_index]
		if is_instance_valid(existing):
			existing.kill()
	button.scale = Vector2.ONE
	button.rotation_degrees = 0.0
	button.pivot_offset = button.size * 0.5
	if button.pivot_offset == Vector2.ZERO and button.custom_minimum_size != Vector2.ZERO:
		button.pivot_offset = button.custom_minimum_size * 0.5
	var tween := create_tween()
	activation_tweens[slot_index] = tween
	tween.tween_property(button, "scale", Vector2(1.16, 1.16), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "rotation_degrees", -4.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(button, "rotation_degrees", 3.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "rotation_degrees", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var stored_index := slot_index
	tween.finished.connect(func():
		var btn := _get_booster_button(stored_index)
		if btn:
			btn.scale = Vector2.ONE
			btn.rotation_degrees = 0.0
		if activation_tweens.has(stored_index):
			activation_tweens.erase(stored_index)
	)

func _stop_press_feedback(slot_index: int) -> void:
	"""Stop visual feedback"""
	if press_feedback_tweens.has(slot_index) and press_feedback_tweens[slot_index]:
		press_feedback_tweens[slot_index].kill()
		press_feedback_tweens[slot_index] = null

	# Reset scale
	var button = _get_booster_button(slot_index)
	if button:
		button.scale = Vector2(1.0, 1.0)
		button.rotation_degrees = 0.0

func _get_player_ability(slot_index: int) -> FW_Ability:
	"""Get the player ability at the given slot index"""
	if slot_index >= 0 and slot_index < GDM.player.abilities.size():
		return GDM.player.abilities[slot_index]
	return null

func _show_ability_info(slot_index: int) -> void:
	"""Show ability info popup for the given slot"""
	var ability = _get_player_ability(slot_index)
	if ability != null:
		EventBus.player_ability_clicked.emit(ability)

func _trigger_ability(slot_index: int) -> void:
	"""Trigger the ability for the given slot"""
	var ability = _get_player_ability(slot_index)
	if ability != null:
		emit_signal("booster_pressed", ability)

func _on_pause_pressed() -> void:
	emit_signal("pause_game")
	get_tree().paused = true

func _on_ability_info_button_pressed() -> void:
	if info_toggle:
		EventBus.info_screen_out.emit()
	else:
		EventBus.info_screen_in.emit()
	info_toggle = !info_toggle

func _on_combat_log_button_pressed() -> void:
	if ConfigManager.ingame_combat_log:
		ConfigManager.ingame_combat_log = false
		emit_signal("hide_ingame_combat_log")
	else:
		ConfigManager.ingame_combat_log = true
		emit_signal("show_ingame_combat_log")
	ConfigManager.save_config()
