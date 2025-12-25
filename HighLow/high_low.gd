extends CanvasLayer

const CARD_BACK_TEXTURE: Texture2D = preload("res://Solitaire/CardBack.png")
const EMOJI_FONT: Font = preload("res://fonts/emoji_font.tres")

const RESULT_TYPE_EQUIPMENT := "equipment"
const RESULT_TYPE_CONSUMABLE := "consumable"
const RESULT_TYPE_GOLD := "gold"
const RESULT_TYPE_DEBUFF := "debuff"
const GUESS_HIGHER := "higher"
const GUESS_LOWER := "lower"

## Inner class for rendering playing cards with proper visuals
class HighLowCard:
	extends Control

	var card: FW_Card
	var _card_size := Vector2(220, 320)
	var _flip_duration := 0.25
	var _emoji_font: Font
	var _back_panel: Panel
	var _back_texture: TextureRect
	var _front_panel: Panel
	var _rank_top: Label
	var _suit_top: Label
	var _center_pip: Label
	var _rank_bottom: Label
	var _suit_bottom: Label
	var _flip_tween: Tween

	func _init(card_size: Vector2 = Vector2(220, 320), flip_time: float = 0.25, emoji_font: Font = null) -> void:
		_card_size = card_size
		_flip_duration = flip_time
		_emoji_font = emoji_font
		custom_minimum_size = card_size
		self.size = card_size
		pivot_offset = card_size * 0.5
		_build_card_visuals()

	func _build_card_visuals() -> void:
		# Back panel (blue card back)
		_back_panel = Panel.new()
		_back_panel.name = "BackPanel"
		_back_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_back_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var back_style := StyleBoxFlat.new()
		back_style.bg_color = Color(0x62 / 255.0, 0x72 / 255.0, 0xa4 / 255.0, 1.0)
		back_style.set_corner_radius_all(16)
		back_style.border_color = Color(0.1, 0.1, 0.2, 1.0)
		back_style.set_border_width_all(3)
		back_style.shadow_color = Color(0, 0, 0, 0.25)
		back_style.shadow_size = 6
		back_style.shadow_offset = Vector2(0, 4)
		_back_panel.add_theme_stylebox_override("panel", back_style)
		add_child(_back_panel)

		# Card back texture
		_back_texture = TextureRect.new()
		_back_texture.name = "BackTexture"
		_back_texture.texture = CARD_BACK_TEXTURE
		_back_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		_back_texture.offset_left = 12
		_back_texture.offset_top = 12
		_back_texture.offset_right = -12
		_back_texture.offset_bottom = -12
		_back_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_back_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_back_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_back_panel.add_child(_back_texture)

		# Front panel (white card face)
		_front_panel = Panel.new()
		_front_panel.name = "FrontPanel"
		_front_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_front_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_front_panel.visible = false
		var front_style := StyleBoxFlat.new()
		front_style.bg_color = Color(0.96, 0.96, 0.96, 1.0)
		front_style.set_corner_radius_all(16)
		front_style.border_color = Color(0.15, 0.15, 0.15, 1.0)
		front_style.set_border_width_all(3)
		front_style.shadow_color = Color(0, 0, 0, 0.25)
		front_style.shadow_size = 6
		front_style.shadow_offset = Vector2(0, 4)
		_front_panel.add_theme_stylebox_override("panel", front_style)
		add_child(_front_panel)

		# Top-left corner: rank + suit
		var top_left := VBoxContainer.new()
		top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
		top_left.offset_left = 10
		top_left.offset_top = 8
		top_left.add_theme_constant_override("separation", -6)
		_front_panel.add_child(top_left)

		_rank_top = Label.new()
		_rank_top.add_theme_font_size_override("font_size", 42)
		_rank_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		top_left.add_child(_rank_top)

		_suit_top = Label.new()
		_suit_top.add_theme_font_size_override("font_size", 36)
		_suit_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		top_left.add_child(_suit_top)

		# Center pip/emoji
		_center_pip = Label.new()
		_center_pip.set_anchors_preset(Control.PRESET_CENTER)
		_center_pip.offset_left = -60
		_center_pip.offset_top = -50
		_center_pip.offset_right = 60
		_center_pip.offset_bottom = 50
		_center_pip.add_theme_font_size_override("font_size", 80)
		if _emoji_font:
			_center_pip.add_theme_font_override("font", _emoji_font)
		_center_pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_center_pip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_front_panel.add_child(_center_pip)

		# Bottom-right corner: suit + rank (rotated 180)
		var bottom_right := VBoxContainer.new()
		bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		bottom_right.offset_left = -50
		bottom_right.offset_top = -90
		bottom_right.offset_right = -10
		bottom_right.offset_bottom = -8
		bottom_right.add_theme_constant_override("separation", -6)
		bottom_right.pivot_offset = Vector2(20, 40)
		bottom_right.rotation_degrees = 180
		_front_panel.add_child(bottom_right)

		_rank_bottom = Label.new()
		_rank_bottom.add_theme_font_size_override("font_size", 42)
		_rank_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bottom_right.add_child(_rank_bottom)

		_suit_bottom = Label.new()
		_suit_bottom.add_theme_font_size_override("font_size", 36)
		_suit_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bottom_right.add_child(_suit_bottom)

	func set_card(new_card: FW_Card, face_up: bool) -> void:
		card = new_card
		if card:
			card.face_up = face_up
		_update_display()

	func set_face_up(face_up: bool) -> void:
		if card:
			card.face_up = face_up
		_update_display()

	func _update_display() -> void:
		if card == null:
			_back_panel.visible = true
			_front_panel.visible = false
			return

		var show_front := card.face_up
		_back_panel.visible = not show_front
		_front_panel.visible = show_front

		if show_front:
			var rank_text := _get_rank_text(card.rank)
			var suit_emoji := _get_suit_emoji(card.suit)
			var text_color := Color(0.85, 0, 0, 1) if card.get_color() == "red" else Color(0, 0, 0, 1)

			_rank_top.text = rank_text
			_rank_top.add_theme_color_override("font_color", text_color)
			_suit_top.text = suit_emoji
			_suit_top.add_theme_color_override("font_color", text_color)
			_center_pip.text = _get_center_text(card.rank, suit_emoji)
			_center_pip.add_theme_color_override("font_color", text_color)
			_rank_bottom.text = rank_text
			_rank_bottom.add_theme_color_override("font_color", text_color)
			_suit_bottom.text = suit_emoji
			_suit_bottom.add_theme_color_override("font_color", text_color)

	func flip_to_face_up() -> void:
		if card:
			card.face_up = true
		_animate_flip(true)

	func flip_to_face_down() -> void:
		if card:
			card.face_up = false
		_animate_flip(false)

	func _animate_flip(to_face_up: bool) -> void:
		if _flip_tween and _flip_tween.is_valid():
			_flip_tween.kill()
		_flip_tween = create_tween()
		_flip_tween.set_trans(Tween.TRANS_QUAD)
		_flip_tween.set_ease(Tween.EASE_IN_OUT)
		_flip_tween.tween_property(self, "scale", Vector2(0.0, 1.0), _flip_duration * 0.5)
		_flip_tween.tween_callback(Callable(self, "_swap_faces").bind(to_face_up))
		_flip_tween.tween_property(self, "scale", Vector2(1.0, 1.0), _flip_duration * 0.5)

	func _swap_faces(show_front: bool) -> void:
		_back_panel.visible = not show_front
		_front_panel.visible = show_front
		if show_front and card:
			_update_display()

	func _get_rank_text(rank: int) -> String:
		match rank:
			FW_Card.Rank.ACE: return "A"
			FW_Card.Rank.TWO: return "2"
			FW_Card.Rank.THREE: return "3"
			FW_Card.Rank.FOUR: return "4"
			FW_Card.Rank.FIVE: return "5"
			FW_Card.Rank.SIX: return "6"
			FW_Card.Rank.SEVEN: return "7"
			FW_Card.Rank.EIGHT: return "8"
			FW_Card.Rank.NINE: return "9"
			FW_Card.Rank.TEN: return "10"
			FW_Card.Rank.JACK: return "J"
			FW_Card.Rank.QUEEN: return "Q"
			FW_Card.Rank.KING: return "K"
		return "?"

	func _get_suit_emoji(suit: int) -> String:
		match suit:
			FW_Card.Suit.HEARTS: return "♥"
			FW_Card.Suit.DIAMONDS: return "♦"
			FW_Card.Suit.CLUBS: return "♣"
			FW_Card.Suit.SPADES: return "♠"
		return "?"

	func _get_center_text(rank: int, suit_emoji: String) -> String:
		match rank:
			FW_Card.Rank.JACK: return "🤴"
			FW_Card.Rank.QUEEN: return "👸"
			FW_Card.Rank.KING: return "👑"
		return suit_emoji

@export_range(1, 10, 1) var win_streak_goal := 5
@export_range(0.05, 0.8, 0.05, "seconds") var flip_animation_duration := 0.3
@export_range(0.05, 1.5, 0.05, "seconds") var reveal_pause := 0.4
@export var reward_mix: Array[String] = [RESULT_TYPE_EQUIPMENT, RESULT_TYPE_CONSUMABLE, RESULT_TYPE_GOLD]
@export var debuff_pool: Array[FW_Buff] = []
@export var card_size := Vector2(200, 290)

@onready var status_label: Label = %StatusLabel
@onready var helper_label: Label = %HelperLabel
@onready var streak_label: Label = %StreakLabel
@onready var deck_count_label: Label = %DeckCountLabel
@onready var history_rich_text: RichTextLabel = %HistoryRichText
@onready var higher_button: Button = %HigherButton
@onready var lower_button: Button = %LowerButton
@onready var current_card_container: CenterContainer = %CurrentCardContainer
@onready var next_card_container: CenterContainer = %NextCardContainer
@onready var loot_screen: CanvasLayer = %LootScreen
@onready var back_button: TextureButton = $back_button

var _deck: FW_Deck
var _current_card: FW_Card
var _next_card: FW_Card
var _current_card_display: HighLowCard
var _next_card_display: HighLowCard
var _streak := 0
var _best_streak := 0
var _turn_counter := 0
var _awaiting_guess := false
var _is_revealing := false
var _round_complete := false
var _exit_pending := false
var _loot_manager: FW_LootManager
var _debuff_queue: Array[FW_Buff] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	SoundManager.wire_up_all_buttons()
	_create_card_displays()
	_connect_ui()
	_connect_loot_screen()
	_start_new_round()

func _create_card_displays() -> void:
	# Create current card display
	_current_card_display = HighLowCard.new(card_size, flip_animation_duration, EMOJI_FONT)
	if current_card_container:
		current_card_container.add_child(_current_card_display)

	# Create next card display (same size as current)
	_next_card_display = HighLowCard.new(card_size, flip_animation_duration, EMOJI_FONT)
	if next_card_container:
		next_card_container.add_child(_next_card_display)

func _connect_ui() -> void:
	if higher_button and not higher_button.pressed.is_connected(Callable(self, "_on_higher_button_pressed")):
		higher_button.pressed.connect(_on_higher_button_pressed)
	if lower_button and not lower_button.pressed.is_connected(Callable(self, "_on_lower_button_pressed")):
		lower_button.pressed.connect(_on_lower_button_pressed)
	if back_button and not back_button.pressed.is_connected(Callable(self, "_on_back_button_pressed")):
		back_button.pressed.connect(_on_back_button_pressed)

func _connect_loot_screen() -> void:
	if not is_instance_valid(loot_screen):
		return
	if loot_screen.has_signal("back_button"):
		var back_signal: Signal = loot_screen.back_button
		if not back_signal.is_connected(Callable(self, "_on_loot_screen_back_button")):
			back_signal.connect(Callable(self, "_on_loot_screen_back_button"))

func _start_new_round() -> void:
	_reset_state()
	_setup_deck()
	if not _deal_initial_cards():
		status_label.text = "Could not prepare the deck"
		return
	status_label.text = "Get %d in a row to win a reward!" % win_streak_goal
	helper_label.text = "Higher or Lower?"
	_update_labels()
	_reset_history()
	_append_history_line("New deck shuffled", Color(0.7, 0.9, 1.0))
	_set_buttons_interactive(true)
	_round_complete = false
	_awaiting_guess = true

func _reset_state() -> void:
	_streak = 0
	_best_streak = 0
	_turn_counter = 0
	_awaiting_guess = false
	_is_revealing = false
	_round_complete = false
	_exit_pending = false
	helper_label.text = ""

func _setup_deck() -> void:
	if _deck == null:
		_deck = FW_Deck.new()
	else:
		_deck.reset()
	_update_deck_count_label()

func _deal_initial_cards() -> bool:
	_current_card = _draw_card()
	_next_card = _draw_card()
	if _current_card == null or _next_card == null:
		printerr("HighLow: failed to draw starting cards.")
		return false
	if _current_card_display:
		_current_card_display.set_card(_current_card, true)
	if _next_card_display:
		_next_card_display.set_card(_next_card, false)
	_awaiting_guess = true
	return true

func _draw_card() -> FW_Card:
	if _deck == null:
		_deck = FW_Deck.new()
	if _deck.is_empty():
		_deck.reset()
	if _deck.is_empty():
		return null
	var card: FW_Card = _deck.draw()
	if card:
		card.face_up = false
	_update_deck_count_label()
	return card

func _set_buttons_interactive(enabled: bool) -> void:
	if higher_button:
		higher_button.disabled = not enabled or _round_complete
	if lower_button:
		lower_button.disabled = not enabled or _round_complete

func _update_labels() -> void:
	if streak_label:
		streak_label.text = "Streak: %d / %d" % [_streak, win_streak_goal]
	_update_deck_count_label()

func _update_deck_count_label() -> void:
	if deck_count_label == null:
		return
	var remaining := 0
	if _deck:
		remaining = _deck.size()
	deck_count_label.text = "Deck: %d cards" % remaining

func _reset_history() -> void:
	if history_rich_text:
		history_rich_text.clear()

func _append_history_line(text: String, color: Color = Color.WHITE) -> void:
	if history_rich_text == null:
		return
	var hex := color.to_html(false)
	var entry := "[color=#%s]%s[/color]\n" % [hex, text]
	history_rich_text.append_text(entry)
	if history_rich_text.has_method("scroll_to_line"):
		history_rich_text.scroll_to_line(history_rich_text.get_line_count())

func _on_higher_button_pressed() -> void:
	_handle_guess(GUESS_HIGHER)

func _on_lower_button_pressed() -> void:
	_handle_guess(GUESS_LOWER)

func _handle_guess(guess: String) -> void:
	if _round_complete or not _awaiting_guess or _is_revealing:
		return
	if _current_card == null or _next_card == null:
		return
	_awaiting_guess = false
	_is_revealing = true
	_set_buttons_interactive(false)
	await _reveal_next_card()
	await get_tree().create_timer(reveal_pause).timeout
	_resolve_guess(guess)
	_is_revealing = false
	if not _round_complete:
		_set_buttons_interactive(true)
		_awaiting_guess = true

func _reveal_next_card() -> void:
	if _next_card_display == null or _next_card == null:
		return
	_next_card_display.flip_to_face_up()
	if SoundManager:
		SoundManager._play_random_card_sound()
	await get_tree().create_timer(flip_animation_duration).timeout

func _resolve_guess(guess: String) -> void:
	if _current_card == null or _next_card == null:
		return
	var comparison := _next_card.rank - _current_card.rank
	var outcome_color := Color(0.9, 0.9, 0.9)
	if comparison == 0:
		status_label.text = "Tie! Your streak holds"
		helper_label.text = "Same rank drawn. No penalty."
		outcome_color = Color(0.9, 0.9, 0.3)
		_append_history_line("Draw: %s vs %s" % [_describe_card(_current_card), _describe_card(_next_card)], outcome_color)
		_pass_cards_forward()
		return
	var is_higher := comparison > 0
	var guessed_correctly := (guess == GUESS_HIGHER and is_higher) or (guess == GUESS_LOWER and not is_higher)
	if guessed_correctly:
		_handle_correct_guess(guess, comparison)
		outcome_color = Color(0.55, 0.9, 0.6)
	else:
		_handle_incorrect_guess(guess, comparison)
		outcome_color = Color(0.95, 0.35, 0.35)
	_append_history_line(_build_history_text(guess, guessed_correctly), outcome_color)
	_pass_cards_forward()

func _handle_correct_guess(_guess: String, _comparison: int) -> void:
	_streak += 1
	_best_streak = maxi(_best_streak, _streak)
	_turn_counter += 1
	status_label.text = "Correct!"
	helper_label.text = "%d more to win!" % (win_streak_goal - _streak) if _streak < win_streak_goal else "You did it!"
	_update_labels()
	# Check for win condition
	if _streak >= win_streak_goal:
		_award_streak_reward()
	# Correct guess sfx
	if SoundManager:
		SoundManager._play_random_positive_sound()

func _handle_incorrect_guess(_guess: String, _comparison: int) -> void:
	_streak = 0
	_turn_counter += 1
	status_label.text = "Wrong!"
	helper_label.text = "Streak reset. Try again!"
	_append_history_line("Streak lost!", Color(0.95, 0.5, 0.5))
	_update_labels()
	# Incorrect guess sfx
	if SoundManager:
		SoundManager._play_random_negative_sound()

func _pass_cards_forward() -> void:
	if _round_complete:
		return
	_current_card = _next_card
	if _current_card:
		_current_card.face_up = true
	if _current_card_display:
		_current_card_display.set_card(_current_card, true)
	_next_card = _draw_card()
	if _next_card_display:
		_next_card_display.set_card(_next_card, false)
	if _next_card == null:
		status_label.text = "Deck exhausted - reshuffling"
		_setup_deck()
		_next_card = _draw_card()
		if _next_card_display:
			_next_card_display.set_card(_next_card, false)

func _build_history_text(guess: String, success: bool) -> String:
	var verdict := "Win" if success else "Lose"
	return "%s - %s between %s and %s" % [verdict, guess.capitalize(), _describe_card(_current_card), _describe_card(_next_card)]

func _describe_card(card: FW_Card) -> String:
	if card == null:
		return "?"
	return "%s of %s" % [card.get_rank_name().capitalize(), card.get_suit_name().capitalize()]

func _award_streak_reward() -> void:
	_round_complete = true
	_set_buttons_interactive(false)
	var reward := _build_reward_entry()
	if reward.is_empty():
		status_label.text = "You win! (No reward available)"
		return
	var item: FW_Item = reward.get("item", null)
	if item:
		var manager := _ensure_loot_manager()
		if manager:
			manager.grant_loot_to_player([item])
		_present_loot_results([item], [], "You got %d in a row!" % win_streak_goal)
	if SoundManager:
		SoundManager._play_random_win_sound()
	_append_history_line("Victory! Won: %s" % reward.get("description", "a reward"), Color(0.6, 1.0, 0.6))
	FW_MinigameRewardHelper.mark_minigame_completed(true)

func _build_reward_entry() -> Dictionary:
	var reward_type := _pick_reward_type()
	match reward_type:
		RESULT_TYPE_EQUIPMENT:
			return _prepare_equipment_reward()
		RESULT_TYPE_CONSUMABLE:
			return _prepare_consumable_reward()
		RESULT_TYPE_GOLD:
			return _prepare_gold_reward()
		_:
			return _prepare_gold_reward()

func _pick_reward_type() -> String:
	if reward_mix.is_empty():
		return RESULT_TYPE_GOLD
	return reward_mix[_rng.randi() % reward_mix.size()]

func _ensure_loot_manager() -> FW_LootManager:
	_loot_manager = FW_MinigameRewardHelper.ensure_loot_manager(_loot_manager)
	return _loot_manager

func _prepare_equipment_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var item: FW_Item = manager.sweet_loot()
	if item == null:
		return {}
	return {
		"type": RESULT_TYPE_EQUIPMENT,
		"item": item,
		"description": "Banked %s" % item.name,
	}

func _prepare_consumable_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var item: FW_Item = manager.generate_random_consumable()
	if item == null:
		return {}
	return {
		"type": RESULT_TYPE_CONSUMABLE,
		"item": item,
		"description": "Grabbed %s" % item.name,
	}

func _prepare_gold_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var amount := _rng.randi_range(60, 160)
	var gold_item: FW_Item = manager.create_gold_item(amount)
	if gold_item == null:
		return {}
	gold_item.name = "%d gp" % amount
	return {
		"type": RESULT_TYPE_GOLD,
		"item": gold_item,
		"description": "Pocketed %d gold" % amount,
	}

func _queue_debuff(buff: FW_Buff) -> void:
	FW_MinigameRewardHelper.queue_debuff_on_player(buff)

func _draw_random_debuff() -> FW_Buff:
	if _debuff_queue.is_empty():
		_debuff_queue = FW_MinigameRewardHelper.build_debuff_queue(debuff_pool)
	return FW_MinigameRewardHelper.draw_buff_from_queue(_debuff_queue)

func _apply_forfeit_penalty() -> bool:
	var buff := _draw_random_debuff()
	if buff == null:
		return false
	_queue_debuff(buff)
	if helper_label and not _round_complete:
		helper_label.text = "Walking away brings bad luck..."
	_present_loot_results([], [buff], "Fortune frowns upon you.")
	return true

func _present_loot_results(items: Array, debuffs: Array, summary: String) -> void:
	if not is_instance_valid(loot_screen):
		return
	var trimmed := summary.strip_edges()
	if loot_screen.has_method("show_loot_collection") and not items.is_empty():
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

func _on_loot_screen_back_button() -> void:
	_on_back_button_pressed()

func _on_back_button_pressed() -> void:
	if not _round_complete:
		if _exit_pending:
			_exit_pending = false
		else:
			_exit_pending = _apply_forfeit_penalty()
			if _exit_pending:
				return
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	ScreenRotator.change_scene("res://Scenes/level_select2.tscn")
