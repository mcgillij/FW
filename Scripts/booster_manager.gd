extends HBoxContainer
class_name FW_BoosterManager

signal slots_ready

const BOOSTER_SLOT_COUNT := 5

@export var booster_slot_scene: PackedScene

var booster_slots: Array[FW_BoosterSlot] = []
var booster_buttons: Array[TextureButton] = []
var booster_cooldowns: Array[Label] = []
var damage_labels: Array[Label] = []
var emojis: Array[Label] = []
var hover_particles: Array[CPUParticles2D] = []
var damage_label_tweens: Array[Tween] = []
var emoji_tweens: Array[Tween] = []
var is_player_turn: bool = true

func _ready() -> void:
	_create_slots_if_needed()
	await get_tree().process_frame
	_cache_slot_references()
	_initialize_state()
	_connect_booster_signals()
	_prepare_hover_effects()
	_initialize_tween_arrays()
	emit_signal("slots_ready")

func get_booster_buttons() -> Array[TextureButton]:
	return booster_buttons.duplicate()

func _create_slots_if_needed() -> void:
	if get_child_count() > 0:
		return
	if booster_slot_scene == null:
		push_error("BoosterManager requires a booster_slot_scene resource.")
		return
	for i in range(BOOSTER_SLOT_COUNT):
		var slot_instance: FW_BoosterSlot = booster_slot_scene.instantiate()
		slot_instance.name = "BoosterSlot" + str(i + 1)
		add_child(slot_instance)

func _cache_slot_references() -> void:
	for particles in hover_particles:
		if is_instance_valid(particles):
			particles.queue_free()
	booster_slots.clear()
	booster_buttons.clear()
	booster_cooldowns.clear()
	damage_labels.clear()
	emojis.clear()
	for child in get_children():
		if child is FW_BoosterSlot:
			var slot := child as FW_BoosterSlot
			booster_slots.append(slot)
			var button := slot.get_button()
			booster_buttons.append(button)
			booster_cooldowns.append(slot.get_cooldown_label())
			damage_labels.append(slot.get_damage_label())
			emojis.append(slot.get_emoji_indicator())
		else:
			push_warning("Unexpected child under BoosterManager: " + child.name)

func _initialize_state() -> void:
	if GDM.game_manager and GDM.game_manager.turn_manager:
		is_player_turn = GDM.game_manager.turn_manager.is_player_turn()
	else:
		is_player_turn = true
	if GDM.is_vs_mode():
		EventBus.update_cooldowns.connect(set_cooldowns)
		EventBus.refresh_boosters.connect(show_hide_booster)
		set_cooldowns()
		activate_booster_buttons()
	EventBus.start_of_player_turn.connect(_on_player_turn_start)
	EventBus.start_of_monster_turn.connect(_on_monster_turn_start)

func _connect_booster_signals() -> void:
	for i in range(booster_buttons.size()):
		var button := booster_buttons[i]
		if button.is_connected("mouse_entered", Callable(self, "_on_booster_mouse_entered")):
			button.disconnect("mouse_entered", Callable(self, "_on_booster_mouse_entered"))
		if button.is_connected("mouse_exited", Callable(self, "_on_booster_mouse_exited")):
			button.disconnect("mouse_exited", Callable(self, "_on_booster_mouse_exited"))
		if button.is_connected("button_down", Callable(self, "_on_booster_button_down")):
			button.disconnect("button_down", Callable(self, "_on_booster_button_down"))
		if button.is_connected("button_up", Callable(self, "_on_booster_button_up")):
			button.disconnect("button_up", Callable(self, "_on_booster_button_up"))
		button.mouse_entered.connect(_on_booster_mouse_entered.bind(i))
		button.mouse_exited.connect(_on_booster_mouse_exited.bind(i))
		button.button_down.connect(_on_booster_button_down.bind(i))
		button.button_up.connect(_on_booster_button_up.bind(i))

func _prepare_hover_effects() -> void:
	hover_particles.clear()
	for button in booster_buttons:
		var particles := _create_hover_particles()
		button.add_child(particles)
		hover_particles.append(particles)

func _create_hover_particles() -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emitting = false
	particles.amount = 20
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.preprocess = 0.0
	particles.speed_scale = 1.2
	particles.explosiveness = 0.0
	particles.randomness = 0.4
	particles.fixed_fps = 0
	particles.fract_delta = true
	particles.draw_order = CPUParticles2D.DRAW_ORDER_INDEX
	particles.texture = null
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 50.0
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.gravity = Vector2(0, -25)
	particles.initial_velocity_min = 15.0
	particles.initial_velocity_max = 35.0
	particles.angular_velocity_min = -60.0
	particles.angular_velocity_max = 60.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = Color(1.0, 0.95, 0.6, 1.0)
	particles.color_ramp = Gradient.new()
	particles.color_ramp.add_point(0.0, Color(1.0, 1.0, 0.8, 1.0))
	particles.color_ramp.add_point(0.6, Color(1.0, 0.9, 0.4, 0.9))
	particles.color_ramp.add_point(1.0, Color(1.0, 0.7, 0.0, 0.0))
	particles.position = Vector2(50, 50)
	particles.z_index = 10
	particles.z_as_relative = false
	particles.visible = true
	return particles

func _initialize_tween_arrays() -> void:
	damage_label_tweens.resize(booster_buttons.size())
	emoji_tweens.resize(booster_buttons.size())
	for i in range(damage_label_tweens.size()):
		damage_label_tweens[i] = null
		emoji_tweens[i] = null

func activate_booster_buttons() -> void:
	for i in range(booster_buttons.size()):
		var ability = _get_player_ability(i)
		var button := booster_buttons[i]
		var slot := booster_slots[i]
		if ability != null:
			button.texture_normal = ability.texture
			button.texture_disabled = ability.disabled_texture
			button.modulate.a = 0.5
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot.update_mana_cost(ability, true)
		else:
			button.texture_normal = null
			button.texture_disabled = null
			button.modulate.a = 1.0
			button.mouse_default_cursor_shape = Control.CURSOR_ARROW
			slot.clear_mana_cost()

func _get_player_ability(slot_index: int) -> FW_Ability:
	"""Get the player ability at the given slot index"""
	if slot_index >= 0 and slot_index < GDM.player.abilities.size():
		return GDM.player.abilities[slot_index]
	return null

func set_cooldowns() -> void:
	for i in range(booster_buttons.size()):
		var ability = _get_player_ability(i)
		var button := booster_buttons[i]
		if ability != null:
			var key = ["player", ability.name]
			var cooldown_manager = GDM.game_manager.player_cooldown_manager if GDM.game_manager else null
			if cooldown_manager and cooldown_manager.abilities.has(key):
				var cd = cooldown_manager.abilities[key]
				booster_cooldowns[i].visible = true
				booster_cooldowns[i].text = str(cd)
				button.disabled = true
				button.mouse_default_cursor_shape = Control.CURSOR_ARROW
			else:
				booster_cooldowns[i].visible = false
				button.disabled = false
				if button.modulate.a >= 1.0:
					button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func mana_labels(iterator: int, can_see: bool = true) -> void:
	var ability = _get_player_ability(iterator)
	if ability:
		booster_slots[iterator].update_mana_cost(ability, can_see)
	else:
		booster_slots[iterator].clear_mana_cost()

func show_hide_booster(toggle: bool, ability_name: String) -> void:
	for i in range(booster_buttons.size()):
		var ability = _get_player_ability(i)
		if ability != null and ability.name == ability_name:
			mana_labels(i)
			if toggle:
				booster_buttons[i].modulate.a = 1
				booster_buttons[i].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				booster_buttons[i].modulate.a = 0.5
				booster_buttons[i].mouse_default_cursor_shape = Control.CURSOR_ARROW

func _on_player_turn_start() -> void:
	is_player_turn = true
	EventBus.ability_preview_cleared.emit()

func _on_monster_turn_start() -> void:
	is_player_turn = false
	EventBus.ability_preview_cleared.emit()

func _on_booster_mouse_entered(slot_index: int) -> void:
	if _is_ability_usable(slot_index):
		hover_particles[slot_index].emitting = true
		# Add subtle dimmer tint effect
		booster_buttons[slot_index].self_modulate = Color(0.75, 0.77, 1.0, 1.0)
		var ability = _get_player_ability(slot_index)
		if ability:
			EventBus.ability_preview_requested.emit(ability)
			var display_info = FW_Ability.get_effect_display_info(ability)
			if display_info.type != "none":
				emojis[slot_index].text = display_info.emoji
				emojis[slot_index].visible = true
				emojis[slot_index].modulate.a = 0.0
				if emoji_tweens[slot_index]:
					emoji_tweens[slot_index].stop()
				emoji_tweens[slot_index] = create_tween()
				emoji_tweens[slot_index].tween_property(emojis[slot_index], "modulate:a", 1.0, 0.3)
			if ability.damage > 0:
				if damage_label_tweens[slot_index]:
					damage_label_tweens[slot_index].stop()
				damage_labels[slot_index].text = str(ability.damage)
				damage_labels[slot_index].modulate = display_info.color
				damage_labels[slot_index].visible = true
				damage_labels[slot_index].modulate.a = 0.0
				damage_label_tweens[slot_index] = create_tween()
				damage_label_tweens[slot_index].tween_property(damage_labels[slot_index], "modulate:a", 1.0, 0.3)

func _on_booster_mouse_exited(slot_index: int) -> void:
	hover_particles[slot_index].emitting = false
	# Remove tint effect
	booster_buttons[slot_index].self_modulate = Color.WHITE
	EventBus.ability_preview_cleared.emit()
	# Fade out emoji
	if emoji_tweens[slot_index]:
		emoji_tweens[slot_index].stop()
	emoji_tweens[slot_index] = create_tween()
	emoji_tweens[slot_index].tween_property(emojis[slot_index], "modulate:a", 0.0, 0.3).finished.connect(func(): emojis[slot_index].visible = false)
	# Fade out damage label
	if damage_label_tweens[slot_index]:
		damage_label_tweens[slot_index].stop()
	damage_label_tweens[slot_index] = create_tween()
	damage_label_tweens[slot_index].tween_property(damage_labels[slot_index], "modulate:a", 0.0, 0.3).finished.connect(func(): damage_labels[slot_index].visible = false)

func _is_ability_usable(slot_index: int) -> bool:
	# First check if ability exists
	var ability = _get_player_ability(slot_index)
	if not ability:
		return false

	if not is_player_turn:
		return false

	var button = booster_buttons[slot_index]
	return not button.disabled and button.modulate.a >= 1.0

func _on_booster_button_down(slot_index: int) -> void:
	"""Called when booster button is pressed down - start long-press timer"""
	var bottom_ui := _find_bottom_ui_owner()
	if bottom_ui and bottom_ui.has_method("_start_press_timer"):
		bottom_ui._start_press_timer(slot_index)
	EventBus.ability_preview_cleared.emit()

func _on_booster_button_up(slot_index: int) -> void:
	"""Called when booster button is released - cancel timer if still running"""
	var bottom_ui := _find_bottom_ui_owner()
	if bottom_ui and bottom_ui.has_method("_cancel_press_timer"):
		bottom_ui._cancel_press_timer(slot_index)
	if bottom_ui and bottom_ui.has_method("_handle_booster_button_release"):
		bottom_ui._handle_booster_button_release(slot_index)

func _find_bottom_ui_owner() -> Node:
	var current: Node = self
	while current:
		if current.has_method("_start_press_timer"):
			return current
		current = current.get_parent()
	return null
