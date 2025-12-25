extends CanvasLayer

const CARD_BACK_TEXTURE: Texture2D = preload("res://Solitaire/CardBack.png")
const DEFAULT_GOLD_ICON: Texture2D = preload("res://Item/Junk/Images/gold_coins.png")
const RESULT_TYPE_EQUIPMENT := "equipment"
const RESULT_TYPE_CONSUMABLE := "consumable"
const RESULT_TYPE_GOLD := "gold"
const RESULT_TYPE_DEBUFF := "debuff"

class MemoryCard:
	extends Button

	signal card_revealed(card: MemoryCard)

	var pair_id: int = -1
	var reward_payload: Dictionary = {}
	var is_face_up := false
	var is_matched := false
	var _flip_duration := 0.2
	var _card_back_texture: Texture2D
	var _back_rect: TextureRect
	var _front_panel: Panel
	var _back_panel: Panel
	var _front_icon: TextureRect
	var _front_label: Label
	var _flip_tween: Tween
	var _card_size := Vector2(160, 240)
	var _is_interactive := true
	var _flip_guard: Callable

	func _init(back_texture: Texture2D, card_size: Vector2, flip_duration: float) -> void:
		_card_back_texture = back_texture
		_card_size = card_size
		_flip_duration = max(0.05, flip_duration)
		custom_minimum_size = card_size
		size = card_size
		pivot_offset = card_size * 0.5
		focus_mode = FOCUS_NONE
		toggle_mode = false
		flat = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		_build_visuals()
		scale = Vector2.ONE

	func _build_visuals() -> void:
		_back_panel = Panel.new()
		_back_panel.name = "CardBackPanel"
		_back_panel.anchor_left = 0.0
		_back_panel.anchor_top = 0.0
		_back_panel.anchor_right = 1.0
		_back_panel.anchor_bottom = 1.0
		_back_panel.offset_left = 0.0
		_back_panel.offset_top = 0.0
		_back_panel.offset_right = 0.0
		_back_panel.offset_bottom = 0.0
		_back_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var back_style := StyleBoxFlat.new()
		back_style.bg_color = Color(0x62 / 255.0, 0x72 / 255.0, 0xa4 / 255.0, 1.0)
		back_style.set_corner_radius_all(16)
		back_style.border_color = Color(0.1, 0.1, 0.2, 1.0)
		back_style.set_border_width_all(3)
		back_style.shadow_color = Color(0, 0, 0, 0.18)
		back_style.shadow_size = 4
		back_style.shadow_offset = Vector2(2, 2)
		_back_panel.add_theme_stylebox_override("panel", back_style)
		add_child(_back_panel)

		_back_rect = TextureRect.new()
		_back_rect.name = "CardBack"
		_back_rect.texture = _card_back_texture
		_back_rect.anchor_left = 0.0
		_back_rect.anchor_top = 0.0
		_back_rect.anchor_right = 1.0
		_back_rect.anchor_bottom = 1.0
		var inset := 12.0
		_back_rect.offset_left = inset
		_back_rect.offset_top = inset
		_back_rect.offset_right = -inset
		_back_rect.offset_bottom = -inset
		_back_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_back_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_back_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back_panel.add_child(_back_rect)

		_front_panel = Panel.new()
		_front_panel.name = "CardFront"
		_front_panel.anchor_left = 0.0
		_front_panel.anchor_top = 0.0
		_front_panel.anchor_right = 1.0
		_front_panel.anchor_bottom = 1.0
		_front_panel.offset_left = 0.0
		_front_panel.offset_top = 0.0
		_front_panel.offset_right = 0.0
		_front_panel.offset_bottom = 0.0
		_front_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front_panel.visible = false
		add_child(_front_panel)

		var style_box := StyleBoxFlat.new()
		style_box.bg_color = Color(0.96, 0.96, 0.96, 1.0)
		style_box.set_corner_radius_all(16)
		style_box.border_color = Color(0.15, 0.15, 0.15, 1.0)
		style_box.set_border_width_all(3)
		style_box.shadow_color = Color(0, 0, 0, 0.18)
		style_box.shadow_size = 4
		style_box.shadow_offset = Vector2(2, 2)
		_front_panel.add_theme_stylebox_override("panel", style_box)

		_front_icon = TextureRect.new()
		_front_icon.name = "RewardIcon"
		_front_icon.anchor_left = 0.1
		_front_icon.anchor_top = 0.1
		_front_icon.anchor_right = 0.9
		_front_icon.anchor_bottom = 0.9
		_front_icon.offset_left = 0.0
		_front_icon.offset_top = 0.0
		_front_icon.offset_right = 0.0
		_front_icon.offset_bottom = 0.0
		_front_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_front_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_front_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front_panel.add_child(_front_icon)

		_front_label = Label.new()
		front_label_setup()
		_front_panel.add_child(_front_label)

	func front_label_setup() -> void:
		_front_label.name = "RewardLabel"
		_front_label.anchor_left = 0.05
		_front_label.anchor_right = 0.95
		_front_label.anchor_bottom = 0.95
		_front_label.anchor_top = 0.75
		_front_label.offset_left = 0.0
		_front_label.offset_right = 0.0
		_front_label.offset_top = 0.0
		_front_label.offset_bottom = 0.0
		_front_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_front_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_front_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_front_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front_label.visible = false
		_front_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1.0))
		_front_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
		_front_label.add_theme_constant_override("outline_size", 2)
		_front_label.add_theme_font_size_override("font_size", 20)

	func assign_payload(payload: Dictionary, reward_icon: Texture2D, pair_identifier: int) -> void:
		reward_payload = payload
		pair_id = pair_identifier
		_front_icon.texture = reward_icon
		_apply_payload_visuals()

	func _apply_payload_visuals() -> void:
		var label_text := String(reward_payload.get("card_label", "")).strip_edges()
		if _front_label:
			_front_label.text = label_text
			_front_label.visible = label_text != ""
		if _front_icon:
			var icon_modulate: Color = reward_payload.get("icon_modulate", Color.WHITE)
			_front_icon.self_modulate = icon_modulate

	func set_flip_guard(guard_callable: Callable) -> void:
		_flip_guard = guard_callable

	func flip_up() -> void:
		if is_face_up or is_matched or not _is_interactive:
			return
		is_face_up = true
		_show_front(true)

	func flip_down() -> void:
		if not is_face_up or is_matched:
			return
		is_face_up = false
		_show_front(false)

	func lock_in() -> void:
		is_matched = true
		_is_interactive = false
		disabled = true

	func set_interactive(enabled: bool) -> void:
		_is_interactive = enabled
		disabled = not enabled

	func _pressed() -> void:
		if _flip_guard.is_valid():
			var guard_result: bool = _flip_guard.call(self)
			if not guard_result:
				return
		if is_face_up or is_matched or not _is_interactive:
			return
		flip_up()
		card_revealed.emit(self)

	func _show_front(show_front: bool) -> void:
		if _flip_tween and _flip_tween.is_valid():
			_flip_tween.kill()
		_flip_tween = create_tween()
		_flip_tween.set_trans(Tween.TRANS_QUAD)
		_flip_tween.set_ease(Tween.EASE_IN_OUT)
		_flip_tween.tween_property(self, "scale", Vector2(0.0, 1.0), _flip_duration * 0.5)
		_flip_tween.tween_callback(Callable(self, "_swap_faces").bind(show_front))
		_flip_tween.tween_property(self, "scale", Vector2(1.0, 1.0), _flip_duration * 0.5)
		_flip_tween.finished.connect(Callable(self, "_on_flip_tween_finished"), CONNECT_ONE_SHOT)
		# Flip sound
		if show_front and SoundManager:
			SoundManager._play_random_card_sound()

	func _swap_faces(show_front: bool) -> void:
		_back_panel.visible = not show_front
		_front_panel.visible = show_front

	func _on_flip_tween_finished() -> void:
		_flip_tween = null
		scale = Vector2.ONE

@export_range(2, 8, 1) var grid_columns := 4
@export_range(2, 6, 1) var grid_rows := 4
@export_range(1, 40, 1) var max_attempts := 6
@export_range(0.05, 0.6, 0.01, "seconds") var card_flip_duration := 0.2
@export_range(0.1, 3.0, 0.05, "seconds") var mismatch_hide_delay := 0.8
@export_range(0.0, 2.0, 0.05, "seconds") var match_lock_delay := 0.3
@export var card_size := Vector2(160, 224)
@export var reward_mix: Array[String] = ["equipment", "equipment", "consumable", "gold", "debuff"]
@export_range(1, 6, 1) var streak_bonus_threshold := 3
@export_range(1, 3, 1) var streak_bonus_attempts := 1
@export_range(1, 5, 1) var peek_unlock_streak := 2
@export_range(1, 3, 1) var peek_max_charges := 2
@export_range(0.5, 3.0, 0.1, "seconds") var peek_reveal_duration := 1.5
@export var debuff_pool: Array[FW_Buff] = []

@onready var card_grid: GridContainer = %CardGrid
@onready var attempts_label: Label = %AttemptsLabel
@onready var matches_label: Label = %MatchesLabel
@onready var info_label: Label = %InfoLabel
@onready var loot_screen: Node = %LootScreen
@onready var streak_label: Label = %StreakLabel
@onready var peek_button: Button = %PeekButton

var _loot_manager: FW_LootManager
var _rng := RandomNumberGenerator.new()
var _debuff_queue: Array = []
var _cards: Array[MemoryCard] = []
var _active_cards: Array[MemoryCard] = []
var _current_loot: Array[Dictionary] = []
var _claimed_pairs := {}
var _attempts_left := 0
var _matches_found := 0
var _pair_id_counter := 1
var _is_resolving_pair := false
var _round_complete := false
var _match_streak := 0
var _best_streak := 0
var _peek_charges := 0
var _peek_in_progress := false
var _no_match_notification_shown := false
var _used_consumable_visual_keys: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	SoundManager.wire_up_all_buttons()
	if is_instance_valid(loot_screen) and loot_screen.has_signal("back_button"):
		if not loot_screen.back_button.is_connected(Callable(self, "_on_loot_screen_back_button")):
			loot_screen.back_button.connect(Callable(self, "_on_loot_screen_back_button"))
	_start_new_round()

func _start_new_round() -> void:
	_reset_state()
	var total_cards := _get_even_card_capacity()
	if total_cards < 2:
		printerr("MemoryGame: grid too small to start a round.")
		return
	var pair_target := int(total_cards * 0.5)
	var deck := _build_card_deck(pair_target)
	if deck.is_empty():
		printerr("MemoryGame: failed to build deck data.")
		return
	deck.shuffle()
	card_grid.columns = grid_columns
	for reward in deck:
		var card := MemoryCard.new(CARD_BACK_TEXTURE, card_size, card_flip_duration)
		var icon: Texture2D = reward.get("icon", null)
		card.assign_payload(reward, icon, reward.get("pair_id", -1))
		card.set_flip_guard(Callable(self, "_can_flip_card"))
		card.card_revealed.connect(_on_card_revealed)
		card_grid.add_child(card)
		_cards.append(card)
	_refresh_card_interactivity()

func _reset_state() -> void:
	_clear_existing_cards()
	_attempts_left = max_attempts
	_matches_found = 0
	_pair_id_counter = 1
	_active_cards.clear()
	_current_loot.clear()
	_claimed_pairs.clear()
	_is_resolving_pair = false
	_round_complete = false
	_match_streak = 0
	_best_streak = 0
	_peek_charges = 0
	_peek_in_progress = false
	_no_match_notification_shown = false
	_used_consumable_visual_keys.clear()
	_update_status_labels()
	if info_label:
		info_label.text = "Find the matching pairs"
	_update_peek_button()
	_update_streak_label()
	_refresh_card_interactivity()

func _clear_existing_cards() -> void:
	_cards.clear()
	if card_grid == null:
		return
	for child in card_grid.get_children():
		child.queue_free()

func _get_even_card_capacity() -> int:
	var total := grid_columns * grid_rows
	if total % 2 != 0:
		total -= 1
		printerr("MemoryGame: grid has odd slot count, reserving one slot as empty.")
	return max(total, 0)

func _build_card_deck(pair_target: int) -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	var fails := 0
	while deck.size() < pair_target * 2 and fails < maxi(1, pair_target) * 4:
		var reward := _build_reward_entry()
		if reward.is_empty():
			fails += 1
			continue
		var pair_id := _next_pair_id()
		reward["pair_id"] = pair_id
		var pair_copy := reward.duplicate(true)
		deck.append(reward)
		deck.append(pair_copy)
	return deck

func _build_reward_entry() -> Dictionary:
	var reward_type := _pick_reward_type()
	match reward_type:
		"equipment":
			return _prepare_equipment_reward()
		"consumable":
			return _prepare_consumable_reward()
		"gold":
			return _prepare_gold_reward()
		"debuff":
			return _prepare_debuff_reward()
		_:
			return _prepare_equipment_reward()

func _pick_reward_type() -> String:
	if reward_mix.is_empty():
		return "equipment"
	var index := _rng.randi_range(0, reward_mix.size() - 1)
	return reward_mix[index]

func _ensure_loot_manager() -> FW_LootManager:
	_loot_manager = FW_MinigameRewardHelper.ensure_loot_manager(_loot_manager)
	return _loot_manager

func _prepare_equipment_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var equipment: FW_Item = manager.sweet_loot()
	if equipment == null:
		return {}
	var rarity_color := Color.WHITE
	if equipment.has_method("get_rarity_color"):
		rarity_color = equipment.get_rarity_color(equipment.rarity)
	return {
		"type": RESULT_TYPE_EQUIPMENT,
		"item": equipment,
		"icon": equipment.texture,
		"icon_modulate": rarity_color,
		"card_label": equipment.name,
		"description": "Matched %s" % equipment.name,
	}

func _prepare_consumable_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	# Attempt to choose a consumable that hasn't already been used in this round to avoid visually indistinguishable duplicates
	var pick_attempts := 12
	var attempts := 0
	var consumable: FW_Item = null
	while attempts < pick_attempts:
		consumable = manager.generate_random_consumable()
		if consumable == null:
			return {}
		var visual_key := _consumable_visual_key(consumable)
		# If we couldn't derive a visual key, accept the item (too much complexity otherwise)
		if visual_key == "" or not _used_consumable_visual_keys.has(visual_key):
			_used_consumable_visual_keys[visual_key] = true
			FW_Debug.debug_log(["MemoryGame: selected consumable key: %s" % visual_key])
			break
		attempts += 1
	if attempts >= pick_attempts and consumable == null:
		# Could not pick a unique consumable, give up on this reward
		FW_Debug.debug_log(["MemoryGame: could not pick unique consumable after %d attempts" % pick_attempts])
		return {}
	return {
		"type": RESULT_TYPE_CONSUMABLE,
		"item": consumable,
		"icon": consumable.texture,
		"card_label": consumable.name,
		"description": "Secured %s" % consumable.name,
	}

func _prepare_gold_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var amount := _rng.randi_range(80, 200)
	var gold_item: FW_Item = manager.create_gold_item(amount)
	if gold_item == null:
		return {}
	gold_item.name = "%d gp" % amount
	if gold_item.flavor_text == null or gold_item.flavor_text.strip_edges() == "":
		gold_item.flavor_text = "A tidy stash of %d gold coins." % amount
	var icon: Texture2D = gold_item.texture if gold_item.texture else DEFAULT_GOLD_ICON
	return {
		"type": RESULT_TYPE_GOLD,
		"item": gold_item,
		"amount": amount,
		"icon": icon,
		"card_label": "%d gp" % amount,
		"description": "Found %d gold" % amount,
	}

func _prepare_debuff_reward() -> Dictionary:
	if _debuff_queue.is_empty():
		_debuff_queue = _build_debuff_queue()
	var buff: FW_Buff = FW_MinigameRewardHelper.draw_buff_from_queue(_debuff_queue)
	if buff == null:
		return {}
	return {
		"type": RESULT_TYPE_DEBUFF,
		"buff": buff,
		"icon": buff.texture,
		"card_label": buff.name,
		"description": "Beware: %s" % buff.name,
	}

func _build_debuff_queue() -> Array:
	return FW_MinigameRewardHelper.build_debuff_queue(debuff_pool)

func _next_pair_id() -> int:
	var value := _pair_id_counter
	_pair_id_counter += 1
	return value

func _on_card_revealed(card: MemoryCard) -> void:
	if _round_complete or _is_resolving_pair:
		return
	if _active_cards.has(card):
		return
	_active_cards.append(card)
	_refresh_card_interactivity()
	if _active_cards.size() == 2:
		_process_pair()

func _process_pair() -> void:
	if _active_cards.size() != 2:
		return
	_is_resolving_pair = true
	_attempts_left = maxi(0, _attempts_left - 1)
	_update_status_labels()
	var first := _active_cards[0]
	var second := _active_cards[1]
	if first.pair_id != -1 and first.pair_id == second.pair_id:
		_handle_match(first, second)
	else:
		_handle_mismatch(first, second)

func _handle_match(first: MemoryCard, second: MemoryCard) -> void:
	first.lock_in()
	second.lock_in()
	_matches_found += 1
	if SoundManager:
		SoundManager._play_random_positive_sound()
	_handle_match_streak_feedback(first.reward_payload)
	_update_status_labels()
	if not _claimed_pairs.has(first.pair_id):
		_claimed_pairs[first.pair_id] = true
		_current_loot.append(first.reward_payload.duplicate(true))
	await get_tree().create_timer(match_lock_delay).timeout
	_active_cards.clear()
	_is_resolving_pair = false
	_refresh_card_interactivity()
	_check_round_completion()

func _handle_mismatch(first: MemoryCard, second: MemoryCard) -> void:
	await get_tree().create_timer(mismatch_hide_delay).timeout
	first.flip_down()
	second.flip_down()
	if SoundManager:
		SoundManager._play_random_negative_sound()
	_handle_streak_break()
	_active_cards.clear()
	_is_resolving_pair = false
	_refresh_card_interactivity()
	_check_round_completion()

func _check_round_completion() -> void:
	var target_matches := int(_get_even_card_capacity() * 0.5)
	if _matches_found >= target_matches and target_matches > 0:
		_finish_round(true)
	elif _attempts_left <= 0:
		_finish_round(false)

func _finish_round(success: bool) -> void:
	if _round_complete:
		return
	_round_complete = true
	for card in _cards:
		card.set_interactive(false)
	if info_label:
		info_label.text = "All pairs found!" if success else "Out of attempts"
		# Play victory/defeat sound
		if SoundManager:
			if success:
				SoundManager._play_random_win_sound()
			else:
				SoundManager._play_random_negative_sound()
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	var loot_items: Array[FW_Item] = []
	var debuff_rewards: Array[FW_Buff] = []
	for reward in _current_loot:
		var reward_type := String(reward.get("type", ""))
		match reward_type:
			RESULT_TYPE_DEBUFF:
				var buff: FW_Buff = reward.get("buff", null)
				if buff:
					debuff_rewards.append(buff)
					_queue_debuff(buff)
			_:
				var item: FW_Item = reward.get("item", null)
				if item:
					loot_items.append(item)
	if _matches_found <= 0:
		# No matches found at all; give the player a clearer notification
		_present_no_match_notification()

	if not loot_items.is_empty():
		var manager := _ensure_loot_manager()
		manager.grant_loot_to_player(loot_items)
	if loot_items.is_empty() and debuff_rewards.is_empty():
		# No rewards found — notify the player if this round ended with no matches
		if _matches_found <= 0:
			_present_no_match_notification()
		return
	var summary := "All pairs cleared!" if success else "Attempts exhausted. Here's what you found."
	_present_loot_results(loot_items, debuff_rewards, summary)

func _update_status_labels() -> void:
	if attempts_label:
		attempts_label.text = "Attempts: %d" % _attempts_left
	if matches_label:
		matches_label.text = "Matches: %d" % _matches_found
	_update_streak_label()

func _display_status(message: String) -> void:
	var trimmed := message.strip_edges()
	if trimmed == "":
		return
	if info_label:
		info_label.text = trimmed

func _handle_match_streak_feedback(payload: Dictionary) -> void:
	_match_streak += 1
	if _match_streak > _best_streak:
		_best_streak = _match_streak
	var reward_name := String(payload.get("card_label", "pair")).strip_edges()
	if reward_name == "":
		reward_name = "pair"
	_display_status("Matched %s! Streak %d" % [reward_name, _match_streak])
	var bonus_awarded := streak_bonus_threshold > 0 and _match_streak % streak_bonus_threshold == 0
	if bonus_awarded:
		_attempts_left += streak_bonus_attempts
		var attempt_word := "attempt" if streak_bonus_attempts == 1 else "attempts"
		_display_status("Streak %d! +%d %s" % [_match_streak, streak_bonus_attempts, attempt_word])
	if peek_unlock_streak > 0 and _match_streak % peek_unlock_streak == 0:
		_grant_peek_charge()
	_update_streak_label()

func _handle_streak_break() -> void:
	if _match_streak <= 0:
		return
	_match_streak = 0
	_display_status("Streak lost! Reset and refocus.")
	_update_streak_label()

func _grant_peek_charge() -> void:
	if peek_max_charges <= 0:
		return
	if _peek_charges >= peek_max_charges:
		return
	_peek_charges += 1
	_display_status("Quick Peek ready (%d)" % _peek_charges)
	_update_peek_button()

func _update_streak_label() -> void:
	if streak_label == null:
		return
	streak_label.text = "Streak: %d" % _match_streak
	streak_label.tooltip_text = "Best streak: %d" % _best_streak

func _update_peek_button() -> void:
	if peek_button == null:
		return
	var label := "Quick Peek"
	if _peek_charges > 0:
		label = "Quick Peek (%d)" % _peek_charges
	peek_button.text = label
	var disabled := _peek_charges <= 0 or _round_complete or _peek_in_progress or _is_resolving_pair
	peek_button.disabled = disabled

func _consume_peek_charge() -> bool:
	if _peek_charges <= 0:
		return false
	_peek_charges -= 1
	_update_peek_button()
	return true

func _on_peek_button_pressed() -> void:
	if _round_complete or _peek_in_progress:
		return
	if not _consume_peek_charge():
		return
	_peek_in_progress = true
	_refresh_card_interactivity()
	if SoundManager:
		SoundManager._play_peek_sound()
	var success := await _reveal_random_pair_peek()
	_peek_in_progress = false
	_refresh_card_interactivity()
	if not success:
		_peek_charges = mini(_peek_charges + 1, peek_max_charges)
		_update_peek_button()
		_display_status("No hidden pairs to peek at.")

func _reveal_random_pair_peek() -> bool:
	var pair_buckets: Dictionary = {}
	for card in _cards:
		if card == null:
			continue
		if card.is_matched or card.is_face_up:
			continue
		if not pair_buckets.has(card.pair_id):
			pair_buckets[card.pair_id] = []
		pair_buckets[card.pair_id].append(card)
	var viable_pair_ids: Array[int] = []
	for pair_id in pair_buckets.keys():
		var bucket: Array = pair_buckets[pair_id]
		if bucket.size() >= 2:
			viable_pair_ids.append(pair_id)
	if viable_pair_ids.is_empty():
		return false
	var chosen_pair: int = viable_pair_ids[_rng.randi_range(0, viable_pair_ids.size() - 1)]
	var reveal_set: Array = pair_buckets[chosen_pair]
	for card in reveal_set:
		card.flip_up()
	_display_status("Memorize this pair!")
	await get_tree().create_timer(peek_reveal_duration).timeout
	for card in reveal_set:
		if card == null:
			continue
		if card.is_matched:
			continue
		if _active_cards.has(card):
			continue
		card.flip_down()
	return true

func _can_flip_card(card: MemoryCard) -> bool:
	if card == null:
		return false
	if _round_complete:
		return false
	if _is_resolving_pair:
		return false
	if _active_cards.size() >= 2:
		return false
	if _active_cards.size() == 1 and _active_cards[0] == card:
		return false
	return true

func _refresh_card_interactivity() -> void:
	var allow_selection := not _round_complete and not _is_resolving_pair and not _peek_in_progress and _active_cards.size() < 2
	for card in _cards:
		if card == null:
			continue
		if card.is_matched or card.is_face_up:
			card.set_interactive(false)
		else:
			card.set_interactive(allow_selection)
	_update_peek_button()

func _present_loot_results(items: Array, debuffs: Array, summary: String) -> void:
	if not is_instance_valid(loot_screen):
		return
	var trimmed := summary.strip_edges()
	if loot_screen.has_method("show_loot_collection"):
		loot_screen.call("show_loot_collection", items, trimmed, debuffs)
	elif not items.is_empty() and loot_screen.has_method("show_single_loot"):
		loot_screen.call("show_single_loot", items[0])
		if trimmed != "" and loot_screen.has_method("show_text"):
			loot_screen.call("show_text", trimmed)
	elif not debuffs.is_empty() and loot_screen.has_method("show_buffs"):
		loot_screen.call("show_buffs", debuffs)
		if trimmed != "" and loot_screen.has_method("show_text"):
			loot_screen.call("show_text", trimmed)
	if loot_screen.has_method("slide_in"):
		loot_screen.call("slide_in")


func _present_no_match_notification() -> void:
	if _no_match_notification_shown:
		return
	_no_match_notification_shown = true
	# Keep existing visible state feedback
	if info_label:
		info_label.text = "No matches found..."
	# Emit a floating combat-styled notification for visibility
	if EventBus:
		EventBus.combat_notification.emit(FW_CombatNotification.message_type.DEFAULT, "No matches found. Better luck next time!")
	# Try to use the loot screen text bubble as a fallback/extra
	if is_instance_valid(loot_screen) and loot_screen.has_method("show_text"):
		loot_screen.call("show_text", "No matches found. Better luck next time!")
		if loot_screen.has_method("slide_in"):
			loot_screen.call("slide_in")
	# Play a negative/failed sound so the player gets audio feedback
	if SoundManager:
		SoundManager._play_random_negative_sound()


func _consumable_visual_key(consumable: FW_Item) -> String:
	if consumable == null:
		return ""
	var name_key := String(consumable.name).strip_edges()
	var texture_key := ""
	if consumable.texture and consumable.texture.resource_path != "":
		texture_key = consumable.texture.resource_path
	elif consumable.texture:
		texture_key = str(consumable.texture)
	if name_key == "" and texture_key == "":
		return ""
	return "%s|%s" % [name_key, texture_key]

func _queue_debuff(buff: FW_Buff) -> void:
	FW_MinigameRewardHelper.queue_debuff_on_player(buff)

func _on_back_button_pressed() -> void:
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	ScreenRotator.change_scene("res://Scenes/level_select2.tscn")

func _on_loot_screen_back_button() -> void:
	_on_back_button_pressed()
