extends Node

# global event bus that I'm going to use to pass programmatic events
# the kind that generally can't be wired up ahead of time, like user selected abilities
signal tab_highlight
# combat notifications
signal combat_notification(message_type: FW_CombatNotification.message_type, custom_message: String)
signal monster_request_tile_move
# for 3d dice roller
signal trigger_roll(level_name: String)
signal dice_roll_result(result: int)
signal dice_roll_result_for(result: int, roll_for: String)

# consumables
signal consumable_clicked(c: FW_Consumable)
signal consumable_used(consumable: FW_Consumable)
signal consumable_slots_changed()
signal show_dice
signal hide_dice

#dungeon blacksmith
signal trigger_blacksmith(character: FW_Character)
signal blacksmith_completed

# Quest events
signal quest_added(quest)
signal quest_goal_completed(quest, goal)
signal quest_completed(quest)

# Doghouse/feature unlock signals
signal doghouse_unlocked
signal forge_unlocked
signal garden_unlocked
signal forge_item_unlocked(item_name: String)
signal garden_potion_unlocked(index: int)

# Item/Equipment/Consumable events
signal equipment_added(equipment: FW_Equipment)
signal consumable_added(consumable: FW_Consumable)
signal inventory_item_added(item: FW_Item)
signal inventory_changed

signal ascension_triggered(world_id: String)

# loot screen
signal roll_won
signal roll_lost
# stats screen
signal stat_hover(stat: FW_Stat)
signal stat_unhover
signal skill_hover(skill_name: String)
signal skill_unhover

# Combined Stats / Abilities panel
signal ability_hover(ability: FW_Ability)
signal ability_unhover()
signal ability_preview_requested(ability: FW_Ability)
signal ability_preview_cleared()

# info screen
signal achievement_trigger(achievement: Dictionary)
signal show_monster(monster: FW_Monster_Resource)
signal show_player_combatant(combatant: FW_Combatant)
signal skilltree_select
signal skilltree_deselect
signal info_screen_in
signal info_screen_out
signal player_ability_clicked(ability: FW_Ability)
signal player_buff_clicked(buff: FW_Buff)
signal monster_buff_clicked(buff: FW_Buff)
# event
signal trigger_event(event: FW_EventResource)
signal process_event_result(event: FW_EventResource, choice: Dictionary, skill_success: bool)
signal choice_requires_skill_check(choice_prefab: Control, skill_check: Resource)
signal level_completed(level_node: FW_LevelNode)

# boosters -> grid
signal publish_sinker_damage(damage: int, reason: String, sinker_owner:FW_Piece.OWNER)
signal sinker_destroyed(sinker_owner:FW_Piece.OWNER, sinker_type: FW_Ability)

# Generic booster signal - ONLY system now
signal do_booster_effect(resource: Resource, effect_category: String)

signal wrap_up_booster
signal do_booster_screen_effect
signal do_mana_drain(mana: Dictionary)
signal do_channel_mana(mana: Dictionary, owner_is_player: bool)

# Owner-specific healing signals
signal do_player_regenerate(amount: int)
signal do_monster_regenerate(amount: int)

# Owner-specific shield gain signals
signal do_player_gain_shields(amount: int, ability_texture: Texture2D, target_name: String)
signal do_monster_gain_shields(amount: int, ability_texture: Texture2D, target_name: String)

# Owner-specific damage over time signals
signal do_damage_to_player(amount: int, reason: String)
signal do_damage_to_monster(amount: int, reason: String)

# Owner-specific mana gain signals
signal do_player_gain_mana(mana_dict: Dictionary)
signal do_monster_gain_mana(mana_dict: Dictionary)

# gold
signal gain_gold
signal gain_xp

# booster cooldowns
signal update_cooldowns
signal refresh_boosters(toggle, booster_name)

# environment
signal environment_clicked(data: FW_EnvironmentalEffect)
signal environment_inspect(e: FW_EnvironmentalEffect)
signal monster_clicked
signal player_clicked
signal monster_ability_clicked(ability: FW_Ability)

# buffbar

signal player_add_buff(buff: FW_Buff)
signal player_update_buff_bar
signal player_remove_buff(buff: FW_Buff)
signal player_publish_buff_expire(buff: FW_Buff)

signal monster_add_buff(buff: FW_Buff)
signal monster_update_buff_bar
signal monster_remove_buff(buff: FW_Buff)
signal monster_publish_buff_expire(buff: FW_Buff)

# abilities screen

signal calculate_job

# damage signals
#signal do_damage(damage: int, reason: String, bomb: bool) # currently used for shout
signal publish_bypass_damage(damage: int, _reason: String)

# visual effect signals for damage
signal show_monster_damage_effects(amount: int, bypass: bool, shield_damage: bool)
signal show_player_damage_effects(amount: int, bypass: bool, shield_damage: bool)
signal show_monster_heal_effects(amount: int)
signal show_player_heal_effects(amount: int)
signal show_monster_shield_effects(amount: int)
signal show_player_shield_effects(amount: int)

# ability visual effects
signal ability_visual_effect_requested(effect_name: String, params: Dictionary)

# combat state initialization
signal combat_state_initialized

# UI sync signals (for display updates only, no state changes)
signal monster_state_changed
signal player_state_changed

# Death detection signals
signal monster_died
signal player_died

# debug
signal debug_log(to_log: String)

# grid
signal trigger_refill
signal start_of_player_turn
signal start_of_monster_turn
# --- Combat logging signals ---
# These signals are used to communicate combat events. Some are gameplay/visual
# signals (used by UI/effects/state), others are logging-only and should be
# routed through CombatLogBus and eventually replaced by `publish_combat_log`.
# When possible, prefer emitting structured events (publish_damage, etc.) and
# let `CombatLogBus` produce final `publish_combat_log` messages.
signal publish_damage(damage: int, reason: String, is_player: bool)
signal publish_bonus_damage(ability: FW_Ability, effect: int)
signal update_mana(mana_dict: Dictionary)
signal mana_match_fx_requested(match_tiles: Array, mana_totals: Dictionary, owner_is_player: bool)
signal request_mana_bar_targets
signal mana_bar_targets_ready(player_targets: Dictionary, monster_targets: Dictionary)
signal trigger_show_hide_boosters
signal publish_used_ability(ability: FW_Ability)
signal publish_mana_drain(mana: Dictionary)
signal publish_channel_mana(mana: Dictionary, color: String, owner_is_player: bool, added: int)
signal publish_crit
signal publish_evasion(player_turn:bool)
signal publish_damage_resist(amount: int)
signal publish_lifesteal(amount: int, owner_is_player: bool)
signal publish_monster_used_ability(ability: FW_Ability)
signal publish_tenacity_reduction(amount: int)

# Generic combat log signal for unified logging
signal publish_combat_log(message: String)
signal publish_combat_log_with_icon(message: String, icon: Texture2D)

# monster turn
signal monster_turn
signal play_sound_for_booster # probably pass a param eventually with the sound, but for now any sound is fine

const MOUSE_SPEED = 400.0
# Controller input for menu's / pause screen
var _controller_enabled: bool = false
var _mouse_warp_threshold: float = 0.1  # Minimum input magnitude to trigger mouse warp

func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect to joypad signals to track controller connection
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_check_controller_availability()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	"""Handle controller connection/disconnection"""
	_check_controller_availability()

func _check_controller_availability() -> void:
	"""Check if any controllers are connected"""
	_controller_enabled = Input.get_connected_joypads().size() > 0

func _physics_process(delta: float) -> void:
	# Only process controller input if a controller is connected
	if not _controller_enabled:
		return
		
	var left_stick_vector = Input.get_vector("LEFT", "RIGHT", "UP", "DOWN")
	
	# Only warp mouse if there's significant input to prevent drift/noise
	if left_stick_vector.length() > _mouse_warp_threshold:
		var current_mouse_pos = get_viewport().get_mouse_position()
		var new_mouse_pos = current_mouse_pos + left_stick_vector * MOUSE_SPEED * delta
		
		# Ensure we don't warp the mouse outside the window bounds
		var viewport_size = get_viewport().get_visible_rect().size
		new_mouse_pos.x = clamp(new_mouse_pos.x, 0, viewport_size.x)
		new_mouse_pos.y = clamp(new_mouse_pos.y, 0, viewport_size.y)
		
		get_viewport().warp_mouse(new_mouse_pos)
		# Simulate mouse motion
		simulate_mouse_motion()

func _click():
	call_deferred("do_a_left_click")

func _unclick():
	call_deferred("do_a_left_unclick")

func do_a_left_unclick():
	var a = InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	a.position = get_viewport().get_mouse_position()
	a.pressed = false
	Input.parse_input_event(a)

func do_a_left_click():
	var a = InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	a.position = get_viewport().get_mouse_position()
	a.pressed = true
	Input.parse_input_event(a)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("JS_CLICK") and InputEventJoypadButton:
		_click()
	elif event.is_action_released("JS_CLICK") and InputEventJoypadButton:
		_unclick()

func simulate_mouse_motion():
	var motion_event = InputEventMouseMotion.new()
	motion_event.position = get_viewport().get_mouse_position()
	motion_event.relative = Vector2.ZERO  # Update if necessary
	Input.parse_input_event(motion_event)
