extends Panel

signal monster_dead
signal player_dead
signal screen_shake

@onready var red_bar: FW_ManaBar = %RedBar
@onready var green_bar: FW_ManaBar = %GreenBar
@onready var blue_bar: FW_ManaBar = %BlueBar
@onready var orange_bar: FW_ManaBar = %OrangeBar
@onready var pink_bar: FW_ManaBar = %PinkBar

# monster
@onready var enemy_red_bar: FW_ManaBar = %EnemyRedBar
@onready var enemy_green_bar: FW_ManaBar = %EnemyGreenBar
@onready var enemy_blue_bar: FW_ManaBar = %EnemyBlueBar
@onready var enemy_orange_bar: FW_ManaBar = %EnemyOrangeBar
@onready var enemy_pink_bar: FW_ManaBar = %EnemyPinkBar

@onready var monster_container: HBoxContainer = %monster_container
@onready var character_container: HBoxContainer = %character_container

@onready var combo_label: Label = %ComboLabel
@onready var turn_label: Label = %TurnLabel

@export var monster_prefab: PackedScene
@export var character_prefab: PackedScene
@export var monster_ability_prefab: PackedScene
@export var mana_drain_animation: PackedScene

var current_count: int = 0
var current_combo: int = 0

var default_font_size := 12
var font_size_multiplier := 1.1
var start_color := Color(1, 1, 0) # Yellow
var end_color := Color(1, 0, 0)   # Red
var max_combo_val := 15.0 # used for the steps the color gets darker in the transitions
var shake_intensity := 5.0
var shake_duration := 0.5

var turn_label_anchor_position := Vector2.ZERO
var turn_label_anchor_scale := Vector2.ONE
var turn_label_anchor_rotation := 0.0
var turn_label_anchor_ready := false
var turn_label_tween: Tween

@onready var monster_ability_container: HBoxContainer = %monster_ability_container
var player_max_manas: Dictionary = GDM.player.stats.calculate_max_mana()

func _ready() -> void:
	EventBus.update_mana.connect(_on_game_manager_2_update_mana)
	EventBus.publish_lifesteal.connect(_on_combat_resolver_lifesteal)
	# Connect owner-specific healing signals
	EventBus.do_player_regenerate.connect(_on_player_heal)
	EventBus.do_monster_regenerate.connect(_on_monster_heal)
	EventBus.do_booster_effect.connect(_on_booster_effect)

	# Connect death signals from centralized system
	EventBus.monster_died.connect(_on_monster_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.update_cooldowns.connect(_update_monster_cooldowns)
	EventBus.do_mana_drain.connect(_drain_mana)
	EventBus.do_channel_mana.connect(_channel_mana)
	EventBus.publish_evasion.connect(_on_evasion)
	EventBus.request_mana_bar_targets.connect(_on_request_mana_bar_targets)

	# Connect to the new EventBus turn signals
	EventBus.start_of_player_turn.connect(_on_player_turn)
	EventBus.start_of_monster_turn.connect(_on_monster_turn)

	setup_mana_bars()
	call_deferred("_capture_turn_label_defaults")
	call_deferred("_emit_mana_bar_targets")

func _on_evasion(is_player: bool) -> void:
	var target
	if is_player:
		target = character_container.get_child(0)
	else:
		target = monster_container.get_child(0)

	if target:
		var floating_text = target.floating_damage_numbers.instantiate()
		floating_text.set_combatant_owner(is_player)
		target.add_child(floating_text)
		floating_text.show_evade(is_player)

func setup_mana_bars() -> void:
	blue_bar.update_max(player_max_manas["blue"])
	red_bar.update_max(player_max_manas["red"])
	orange_bar.update_max(player_max_manas["orange"])
	pink_bar.update_max(player_max_manas["pink"])
	green_bar.update_max(player_max_manas["green"])
	enemy_blue_bar.set_fill_side()
	enemy_red_bar.set_fill_side()
	enemy_orange_bar.set_fill_side()
	enemy_pink_bar.set_fill_side()
	enemy_green_bar.set_fill_side()

func _capture_turn_label_defaults() -> void:
	if !turn_label:
		turn_label = %TurnLabel
	if !turn_label:
		return
	turn_label_anchor_position = turn_label.position
	turn_label_anchor_scale = turn_label.scale
	turn_label_anchor_rotation = turn_label.rotation_degrees
	turn_label_anchor_ready = true

func _reset_turn_label_transform() -> void:
	if !turn_label_anchor_ready:
		return
	if !turn_label:
		turn_label = %TurnLabel
	if !turn_label:
		return
	turn_label.position = turn_label_anchor_position
	turn_label.scale = turn_label_anchor_scale
	turn_label.rotation_degrees = turn_label_anchor_rotation
	turn_label.modulate = Color(1, 1, 1, 1)
	turn_label_tween = null

func _play_turn_label_animation(new_text: String, is_player: bool) -> void:
	if !turn_label:
		turn_label = %TurnLabel
	if !turn_label:
		return
	if is_instance_valid(turn_label_tween):
		turn_label_tween.kill()
	_reset_turn_label_transform()
	turn_label.text = new_text
	turn_label.show()

	var anchor_pos := turn_label_anchor_position
	var anchor_scale := turn_label_anchor_scale
	var entry_duration := randf_range(0.16, 0.25)
	var start_offset := Vector2(randf_range(-180.0, 180.0), randf_range(-110.0, 110.0))
	var settle_offset := Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
	var entry_scale_factor := randf_range(0.55, 0.75)
	var peak_scale_factor := randf_range(1.12, 1.25)
	var wobble_scale_factor := randf_range(0.96, 1.05)
	var flare_scale_factor := randf_range(1.02, 1.12)
	var entry_rotation := randf_range(-30.0, 30.0)
	var lean_rotation := randf_range(-12.0, 12.0)
	var rebound_rotation := randf_range(-4.0, 4.0)
	var sustain_time := randf_range(0.28, 0.4)
	var accent_hue := randf_range(0.5, 0.65) if is_player else randf_range(0.0, 0.1)
	var accent_color := Color.from_hsv(accent_hue, randf_range(0.4, 0.75), 1.0, 1.0)
	var final_color := Color(1, 1, 1, 1)

	turn_label.modulate = Color(accent_color.r, accent_color.g, accent_color.b, 0.0)
	turn_label.position = anchor_pos + start_offset
	turn_label.scale = anchor_scale * entry_scale_factor
	turn_label.rotation_degrees = turn_label_anchor_rotation + entry_rotation

	turn_label_tween = create_tween()
	turn_label_tween.tween_property(turn_label, "modulate", Color(accent_color.r, accent_color.g, accent_color.b, 1.0), entry_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	turn_label_tween.parallel().tween_property(turn_label, "position", anchor_pos + settle_offset, entry_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn_label_tween.parallel().tween_property(turn_label, "scale", anchor_scale * peak_scale_factor, entry_duration * 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn_label_tween.parallel().tween_property(turn_label, "rotation_degrees", turn_label_anchor_rotation + lean_rotation, entry_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	turn_label_tween.tween_property(turn_label, "rotation_degrees", turn_label_anchor_rotation + rebound_rotation, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn_label_tween.parallel().tween_property(turn_label, "scale", anchor_scale * wobble_scale_factor, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn_label_tween.tween_property(turn_label, "scale", anchor_scale * flare_scale_factor, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	turn_label_tween.tween_property(turn_label, "scale", anchor_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var jitter_offset := Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	turn_label_tween.parallel().tween_property(turn_label, "position", anchor_pos + jitter_offset, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn_label_tween.tween_property(turn_label, "position", anchor_pos, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turn_label_tween.tween_interval(sustain_time)
	turn_label_tween.tween_property(turn_label, "modulate", final_color, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn_label_tween.tween_callback(Callable(self, "_reset_turn_label_transform"))

func _on_game_manager_2_create_monster(monster: FW_Monster_Resource) -> void:
	var current_monster = monster_prefab.instantiate()
	if !monster_container:
		monster_container = %monster_container
	if !monster_ability_container:
		monster_ability_container = %monster_ability_container
	monster_container.add_child(current_monster)
	current_monster.set_combatant_values(monster)
	for a in monster.abilities:
		var monster_ability = monster_ability_prefab.instantiate()
		monster_ability_container.add_child(monster_ability)
		monster_ability.setup(a)

func _update_monster_cooldowns() -> void:
	for ability_ui in monster_ability_container.get_children():
		ability_ui.update_cooldown(ability_ui.ability_res)

func _on_game_manager_2_create_character(character: FW_Character) -> void:
	var current = character_prefab.instantiate()
	if !character_container:
		character_container = %character_container
	character_container.add_child(current)
	current.set_combatant_values(character)

func _drain_mana(mana_dict: Dictionary) -> void:
	var mana_drain_effect = mana_drain_animation.instantiate()
	if GDM.game_manager.turn_manager.is_player_turn():
		mana_drain_effect.position = Vector2(500, 100)
		_update_enemy_mana(mana_dict)
	else:
		mana_drain_effect.position = Vector2(200, 100)
		_update_player_mana(mana_dict)
	add_child(mana_drain_effect)

func _channel_mana(mana_dict: Dictionary, owner_is_player: bool) -> void:
	var mana_drain_effect = mana_drain_animation.instantiate()
	if owner_is_player:
		mana_drain_effect.position = Vector2(200, 100)
		_update_player_mana(mana_dict)
	else:
		mana_drain_effect.position = Vector2(500, 100)
		_update_enemy_mana(mana_dict)
	add_child(mana_drain_effect)

func _update_enemy_mana(mana_dict: Dictionary) -> void:
	enemy_blue_bar.change_value(mana_dict["blue"])
	enemy_red_bar.change_value(mana_dict["red"])
	enemy_orange_bar.change_value(mana_dict["orange"])
	enemy_pink_bar.change_value(mana_dict["pink"])
	enemy_green_bar.change_value(mana_dict["green"])

func _update_player_mana(mana_dict: Dictionary) -> void:
	blue_bar.change_value(mana_dict["blue"])
	red_bar.change_value(mana_dict["red"])
	orange_bar.change_value(mana_dict["orange"])
	pink_bar.change_value(mana_dict["pink"])
	green_bar.change_value(mana_dict["green"])

func _on_game_manager_2_update_mana(mana_dict: Dictionary) -> void:
	if GDM.game_manager.turn_manager.is_player_turn():
		_update_player_mana(mana_dict)
	else:
		_update_enemy_mana(mana_dict)

# Turn signal handlers - updated to work with TurnManager
func _on_player_turn() -> void:
	_play_turn_label_animation("Your Turn!", true)

func _on_monster_turn() -> void:
	_play_turn_label_animation("Enemy Turn!", false)

# Legacy handlers - kept for backward compatibility but should be removed once verified not used
func _on_game_manager_2_enemy_turn() -> void:
	_play_turn_label_animation("Enemy Turn!", false)

func _on_game_manager_2_player_turn() -> void:
	_play_turn_label_animation("Your Turn!", true)

func _on_game_manager_update_combo(combo: int) -> void:
	if !combo_label:
		combo_label = %ComboLabel
	# Reset combo display when the combo is too low
	if combo <= 1:
		combo_label.text = ""
		combo_label.add_theme_font_size_override("font_size", default_font_size)
		combo_label.add_theme_color_override("font_color", Color(1, 1, 1)) # Default white
		combo_label.global_position = Vector2(241, 40) # Reset position
		return
	# Update combo text
	combo_label.text = "x" + str(combo)
	# Tween setup
	var tween = get_tree().create_tween()
	var font_size = int(default_font_size * (font_size_multiplier * combo))
	# Scale animation
	tween.tween_property(
		combo_label,
		"theme_override_font_sizes/font_size",
		font_size,
		0.1 # length
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Shake animation
	for i in range(int(shake_duration / 0.05)): # Create a sequence of random offsets
		var random_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		tween.tween_callback(
			Callable(_set_label_position.bind(Vector2(241, 40) + random_offset))
		).set_delay(i * 0.05)
	tween.tween_callback(Callable(_set_label_position.bind(Vector2(241, 40))))

	# Pop scale animation
	tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_label, "scale", Vector2(1, 1), 0.08).set_delay(0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Outline effect for high combos
	if combo >= int(max_combo_val * 0.7):
		combo_label.add_theme_color_override("font_outline_color", Color(1, 1, 0))
		combo_label.add_theme_constant_override("outline_size", 2)
	else:
		combo_label.add_theme_constant_override("outline_size", 0)

	# Interpolate color
	var t = clamp(float(combo) / max_combo_val, 0.0, 1.0)
	var interpolated_color = Color(
		lerp(start_color.r, end_color.r, t),
		lerp(start_color.g, end_color.g, t),
		lerp(start_color.b, end_color.b, t)
	)
	combo_label.add_theme_color_override("font_color", interpolated_color)

	# Emit screen shake signal if combo is high enough
	if combo > GDM.screenshake_num:
		emit_signal("screen_shake")

# Helper function for setting label position during shake
func _set_label_position(pos: Vector2) -> void:
	combo_label.global_position = pos

func _on_request_mana_bar_targets() -> void:
	FW_Debug.debug_log(["TopUI2", "target_request_received"])
	_emit_mana_bar_targets()

func _emit_mana_bar_targets() -> void:
	var player_targets := _build_player_mana_targets()
	var enemy_targets := _build_enemy_mana_targets()
	FW_Debug.debug_log(["TopUI2", "emitting_targets", {"player": player_targets.keys(), "enemy": enemy_targets.keys()}])
	EventBus.mana_bar_targets_ready.emit(player_targets, enemy_targets)

func _build_player_mana_targets() -> Dictionary:
	return {
		"red": red_bar,
		"blue": blue_bar,
		"green": green_bar,
		"orange": orange_bar,
		"pink": pink_bar,
	}

func _build_enemy_mana_targets() -> Dictionary:
	return {
		"red": enemy_red_bar,
		"blue": enemy_blue_bar,
		"green": enemy_green_bar,
		"orange": enemy_orange_bar,
		"pink": enemy_pink_bar,
	}

func _handle_healing(_amount: int, is_player: bool, _text_method_name: String) -> void:
	var target_node = null
	if is_player:
		# Healing already applied by CombatManager, just get the target node
		target_node = character_container.get_child(0)
	else:
		# Healing already applied by CombatManager, just get the target node
		# NOTE: Monster is child 1 because of HBoxContainer ordering
		target_node = monster_container.get_child(0)

	if target_node:
		# Sync the HP/Shield bars
		if target_node.has_method("sync_state_from_central"):
			target_node.sync_state_from_central()

		# Healing effects are now handled by the base CombatantPrefab class
		# via EventBus signals, so no need to manually instantiate here

func _on_combat_resolver_lifesteal(amount: int, owner_is_player: bool) -> void:
	_handle_healing(amount, owner_is_player, "show_lifesteal")

func _on_player_heal(amount: int) -> void:
	_handle_healing(amount, true, "show_heal")

func _on_monster_heal(amount: int) -> void:
	_handle_healing(amount, false, "show_heal")

func _on_radiance_heal(amount: int) -> void:
	# Radiance healing should affect the current turn's combatant
	var is_player = GDM.game_manager.turn_manager.is_player_turn()
	_handle_healing(amount, is_player, "show_heal")

func _on_booster_effect(resource: Resource, effect_category: String) -> void:
	if effect_category == "radiance":
		var amount = int(resource.effect_strength)
		var is_player = GDM.game_manager.turn_manager.is_player_turn()
		_handle_healing(amount, is_player, "show_heal")

# Death signal handlers from centralized system
func _on_monster_died() -> void:
	emit_signal("monster_dead")

func _on_player_died() -> void:
	emit_signal("player_dead")
