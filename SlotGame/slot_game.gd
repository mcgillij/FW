extends CanvasLayer

signal spin_started
signal spin_finished(result: Dictionary)

const KEY_ID := "id"
const KEY_LABEL := "label"
const KEY_TEXTURE := "texture"
const KEY_TEXTURE_PATH := "texture_path"
const KEY_WEIGHT := "weight"
const KEY_REWARD_TYPE := "reward_type"
const KEY_REWARD_DATA := "reward_data"
const KEY_ICON_MODULATE := "icon_modulate"

const RESULT_TYPE_EQUIPMENT := "equipment"
const RESULT_TYPE_CONSUMABLE := "consumable"
const RESULT_TYPE_GOLD := "gold"
const RESULT_TYPE_DEBUFF := "debuff"
const RESULT_TYPE_TILE := "tile_piece"

const LINE_KEY_SYMBOL := "symbol"
const LINE_KEY_SLOT := "slot"

const DEFAULT_TILE_SYMBOLS := [
	{
		KEY_ID: "ember",
		KEY_LABEL: "Forge Core",
		KEY_TEXTURE_PATH: "res://tile_images/ball.png",
		KEY_WEIGHT: 1.0,
		KEY_REWARD_TYPE: RESULT_TYPE_GOLD,
		KEY_REWARD_DATA: {"min": 90, "max": 180},
	},
	{
		KEY_ID: "tide",
		KEY_LABEL: "Tide Prism",
		KEY_TEXTURE_PATH: "res://tile_images/pom.png",
		KEY_WEIGHT: 1.0,
		KEY_REWARD_TYPE: RESULT_TYPE_CONSUMABLE,
	},
	{
		KEY_ID: "bastion",
		KEY_LABEL: "Bastion Crest",
		KEY_TEXTURE_PATH: "res://tile_images/shield.png",
		KEY_WEIGHT: 0.9,
		KEY_REWARD_TYPE: RESULT_TYPE_EQUIPMENT,
	},
	{
		KEY_ID: "fossil",
		KEY_LABEL: "Fossil Rune",
		KEY_TEXTURE_PATH: "res://tile_images/orange_bone.png",
		KEY_WEIGHT: 0.8,
		KEY_REWARD_TYPE: RESULT_TYPE_TILE,
	},
	{
		KEY_ID: "starlight",
		KEY_LABEL: "Starlight Sigil",
		KEY_TEXTURE_PATH: "res://tile_images/star.png",
		KEY_WEIGHT: 0.6,
		KEY_REWARD_TYPE: RESULT_TYPE_GOLD,
	},
]

@export_range(3, 6, 1) var reel_count := 3
@export_range(3, 5, 1) var visible_rows := 3
@export_range(0.05, 0.6, 0.01, "seconds") var symbol_cycle_interval := 0.12
@export_range(0.5, 8.0, 0.1, "seconds") var reel_spin_duration := 2.4
@export_range(0.0, 1.0, 0.05, "seconds") var reel_stagger_delay := 0.2
@export_range(0.0, 4.0, 0.1, "seconds") var result_hold_delay := 0.4
@export var reels_config: Array[Dictionary] = []
@export var debuff_pool: Array[FW_Buff] = []
@export var autoplay_when_ready := false
@export var symbol_slot_size := Vector2(148, 132)
@export var symbol_inner_padding := Vector2(12, 14)
@export_range(0.0, 48.0, 1.0, "pixels") var slot_spacing := 12.0
@export_range(1.02, 1.4, 0.01) var win_pulse_scale := 1.12
@export_range(0.05, 0.6, 0.01, "seconds") var win_pulse_duration := 0.18
@export var win_highlight_color := Color(1.2, 1.2, 1.2, 1.0)
@export_range(0.0, 3.0, 0.05, "seconds") var win_reward_delay := 0.6
@export_range(0, 500, 1) var spin_gold_cost := 10
@export var require_player_gold := true
@export_range(1.0, 3.0, 0.05) var final_reel_slowdown_multiplier := 1.45
@export_range(1, 5, 1) var final_reel_slowdown_spins := 3
@export_range(0.0, 1.0, 0.05, "seconds") var near_miss_pause := 0.25
@export var near_miss_color := Color(1.35, 1.0, 0.65, 1.0)
@export_range(0.0, 96.0, 1.0, "pixels") var frame_shell_padding := 32.0

@onready var reel_container: HBoxContainer = %ReelContainer
@onready var spin_button: Button = %SpinButton
@onready var status_label: Label = %StatusLabel
@onready var helper_label: Label = %HelperLabel
@onready var loot_screen: CanvasLayer = %LootScreen
@onready var shader_bg: ColorRect = %ShaderBG
@onready var main_layout: Control = $MainLayout
@onready var reel_panel: PanelContainer = $"MainLayout/VBox/ReelPanel"
@onready var gold_label: Label = %GoldLabel

class ReelState:
	var root: Control
	var slots: Array[TextureRect] = []
	var buffer: Array[Dictionary] = []
	var symbol_pool: Array[Dictionary] = []
	var target_symbol: Dictionary = {}
	var tween: Tween

var _reel_states: Array[ReelState] = []
var _rng := RandomNumberGenerator.new()
var _loot_manager: FW_LootManager
var _debuff_queue: Array = []
var _is_spinning := false
var _completed_reels := 0
var _active_symbols: Array[Dictionary] = []
var _last_highlighted_slots: Array[TextureRect] = []
var _shader_tween: Tween
var _bg_flash_tween: Tween
var _helper_idle_text := ""
var _layout_shake_tween: Tween
var _exit_pending := false
var _round_complete := false

func _ready() -> void:
	_rng.randomize()
	SoundManager.wire_up_all_buttons()
	if helper_label:
		_helper_idle_text = helper_label.text
	_exit_pending = false
	_round_complete = false
	_update_gold_label()
	_configure_dimensions()
	_build_reel_visuals()
	_prepare_symbol_pools()
	_connect_ui()
	_listen_for_player_updates()
	_refresh_spin_button_state()
	_refresh_currency_helper()
	_update_status("Pull the lever to spin for loot")
	if autoplay_when_ready:
		call_deferred("_begin_spin")

func _configure_dimensions() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO:
		return
	var outer_margin: float = 48.0 # MainLayout margins (24px each side)
	var reel_padding: float = 64.0 # ReelPadding margins (32px each side)
	var spacing: float = max(slot_spacing, 4.0)
	var horizontal_spacing: float = _get_reel_spacing()
	var usable_width: float = max(viewport_size.x - (outer_margin + reel_padding), 320.0)
	var width_without_spacing: float = usable_width - horizontal_spacing * max(reel_count - 1, 0)
	var max_frame_width: float = width_without_spacing / max(reel_count, 1)
	var chrome_width: float = frame_shell_padding + symbol_inner_padding.x * 2.0
	var computed_slot_width: float = max_frame_width - chrome_width
	if computed_slot_width < symbol_slot_size.x:
		symbol_slot_size.x = max(60.0, computed_slot_width)
	var available_panel_height: float = max(viewport_size.y * 0.52, 420.0)
	var height_chrome: float = frame_shell_padding
	var row_section: float = available_panel_height - (visible_rows - 1) * spacing - height_chrome
	var per_row: float = max(row_section / max(visible_rows, 1), 110.0)
	var computed_slot_height: float = per_row - symbol_inner_padding.y * 2.0
	if computed_slot_height < symbol_slot_size.y:
		symbol_slot_size.y = max(72.0, computed_slot_height)
	slot_spacing = spacing

func _get_reel_spacing() -> float:
	if is_instance_valid(reel_container):
		return float(reel_container.get_theme_constant("separation", "BoxContainer"))
	return 24.0

func _connect_ui() -> void:
	if spin_button and not spin_button.pressed.is_connected(_on_spin_button_pressed):
		spin_button.pressed.connect(_on_spin_button_pressed)
	if is_instance_valid(loot_screen) and loot_screen.has_signal("back_button"):
		var callable := Callable(self, "_on_loot_screen_back_button")
		if loot_screen.back_button and not loot_screen.back_button.is_connected(callable):
			loot_screen.back_button.connect(callable)

func _listen_for_player_updates() -> void:
	if not EventBus.player_state_changed.is_connected(_on_player_state_changed):
		EventBus.player_state_changed.connect(_on_player_state_changed)

func _on_player_state_changed() -> void:
	if _is_spinning:
		return
	_refresh_spin_button_state()
	if require_player_gold:
		_refresh_currency_helper()
	else:
		_update_gold_label()

func _refresh_spin_button_state() -> void:
	if not is_instance_valid(spin_button):
		return
	var can_afford := _can_afford_spin()
	spin_button.disabled = _is_spinning or (require_player_gold and not can_afford)
	if _is_spinning:
		spin_button.text = "Spinning..."
		return
	var label := "Spin"
	if require_player_gold and spin_gold_cost > 0:
		label = "Spin (-%dg)" % spin_gold_cost
	spin_button.text = label

func _refresh_currency_helper() -> void:
	if helper_label == null:
		return
	var base_text := _helper_idle_text if _helper_idle_text != "" else "Match three symbols to claim a reward"
	if require_player_gold and spin_gold_cost > 0:
		var gold := _get_player_gold()
		helper_label.text = "%s — %dg per spin (You have %dg)" % [base_text, spin_gold_cost, gold]
	else:
		helper_label.text = base_text
	_update_gold_label()

func _set_helper_insufficient_gold() -> void:
	if helper_label == null:
		return
	var gold := _get_player_gold()
	helper_label.text = "Need %dg per spin. Current gold: %dg" % [spin_gold_cost, gold]
	_update_gold_label()

func _update_gold_label() -> void:
	if gold_label == null:
		return
	gold_label.text = "Gold: %dg" % _get_player_gold()

func _get_player_resource() -> FW_Player:
	if GDM and GDM.player:
		return GDM.player
	return null

func _get_player_gold() -> int:
	var player := _get_player_resource()
	return player.gold if player else 0

func _can_afford_spin() -> bool:
	if not require_player_gold or spin_gold_cost <= 0:
		return true
	return _get_player_gold() >= spin_gold_cost

func _deduct_spin_cost() -> void:
	if not require_player_gold or spin_gold_cost <= 0:
		return
	var player := _get_player_resource()
	if player == null:
		return
	player.gold = max(player.gold - spin_gold_cost, 0)
	_update_gold_label()
	EventBus.player_state_changed.emit()

func _build_reel_visuals() -> void:
	if not is_instance_valid(reel_container):
		return
	for child in reel_container.get_children():
		child.queue_free()
	_reel_states.clear()
	for i in range(max(1, reel_count)):
		var state := _create_reel_state(i)
		_reel_states.append(state)

func _create_reel_state(index: int) -> ReelState:
	var frame := PanelContainer.new()
	frame.name = "Reel_%d" % index
	var row_height := symbol_slot_size.y + symbol_inner_padding.y * 2.0
	var frame_height: float = row_height * visible_rows + slot_spacing * max(visible_rows - 1, 0) + frame_shell_padding
	var frame_width: float = symbol_slot_size.x + symbol_inner_padding.x * 2.0 + frame_shell_padding
	frame.custom_minimum_size = Vector2(frame_width, frame_height)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	frame_style.set_corner_radius_all(32)
	frame_style.shadow_color = Color(0, 0, 0, 0.45)
	frame_style.shadow_size = 18
	frame.add_theme_stylebox_override("panel", frame_style)
	reel_container.add_child(frame)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", int(slot_spacing))
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(inner)
	var state := ReelState.new()
	state.root = frame
	for row in range(max(1, visible_rows)):
		var slot_panel := PanelContainer.new()
		var slot_panel_size := Vector2(
			symbol_slot_size.x + symbol_inner_padding.x * 2.0,
			symbol_slot_size.y + symbol_inner_padding.y * 2.0
		)
		slot_panel.custom_minimum_size = slot_panel_size
		slot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.09, 0.09, 0.15, 0.96)
		slot_style.set_corner_radius_all(24)
		slot_style.shadow_size = 10
		slot_style.shadow_color = Color(0, 0, 0, 0.35)
		slot_panel.add_theme_stylebox_override("panel", slot_style)
		inner.add_child(slot_panel)
		var tex := TextureRect.new()
		tex.name = "Symbol_%d_%d" % [index, row]
		tex.custom_minimum_size = symbol_slot_size
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex.pivot_offset = symbol_slot_size * 0.5
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.scale = Vector2.ONE
		slot_panel.add_child(tex)
		state.slots.append(tex)
		state.buffer.append({})
	return state

func _prepare_symbol_pools() -> void:
	if reels_config.is_empty():
		reels_config = _build_default_reel_config()
	for i in range(_reel_states.size()):
		var pool := _resolve_symbols_for_reel(i)
		var state := _reel_states[i]
		state.symbol_pool = pool
		state.buffer.clear()
		for _j in range(state.slots.size()):
			var filler := pool[_rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else {}
			state.buffer.append(filler)
		_update_reel_visual(state)

func _build_default_reel_config() -> Array[Dictionary]:
	var config: Array[Dictionary] = []
	for _i in range(max(1, reel_count)):
		config.append({"symbols": DEFAULT_TILE_SYMBOLS.duplicate(true)})
	return config

func _resolve_symbols_for_reel(reel_index: int) -> Array[Dictionary]:
	if reel_index < reels_config.size():
		var entry_variant := reels_config[reel_index]
		if typeof(entry_variant) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_variant
			var symbols: Array = entry.get("symbols", []) if entry.has("symbols") else []
			return _inflate_symbol_entries(symbols)
	return _inflate_symbol_entries(DEFAULT_TILE_SYMBOLS)

func _inflate_symbol_entries(source: Array) -> Array[Dictionary]:
	var inflated: Array[Dictionary] = []
	for raw_entry in source:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry.duplicate(true)
		if not entry.has(KEY_ID):
			entry[KEY_ID] = entry.get(KEY_LABEL, "symbol_%d" % inflated.size())
		entry[KEY_WEIGHT] = max(0.01, float(entry.get(KEY_WEIGHT, 1.0)))
		var texture: Texture2D = entry.get(KEY_TEXTURE, null)
		if texture == null:
			var path: String = String(entry.get(KEY_TEXTURE_PATH, ""))
			if path is String and path != "" and ResourceLoader.exists(path, "Texture2D"):
				texture = ResourceLoader.load(path, "Texture2D")
				entry[KEY_TEXTURE] = texture
		entry[KEY_LABEL] = String(entry.get(KEY_LABEL, entry[KEY_ID])).strip_edges()
		inflated.append(entry)
	return inflated

func _on_spin_button_pressed() -> void:
	_begin_spin()

func _begin_spin() -> void:
	if _is_spinning:
		return
	if _reel_states.is_empty():
		return
	if not _can_afford_spin():
		_update_status("Need %dg to spin" % spin_gold_cost)
		_set_helper_insufficient_gold()
		_refresh_spin_button_state()
		return
	for state in _reel_states:
		if state.symbol_pool.is_empty():
			_update_status("Slot machine needs symbols configured")
			return
	_deduct_spin_cost()
	_reset_highlights()
	_animate_spin_start()
	if SoundManager:
		SoundManager._play_spin_start_sound()
	_update_status("Spinning...")
	if is_instance_valid(spin_button):
		spin_button.text = "Spinning..."
	if helper_label:
		helper_label.text = "Reels whirring..."
	_is_spinning = true
	_completed_reels = 0
	_refresh_spin_button_state()
	_active_symbols.clear()
	var final_symbols: Array[Dictionary] = []
	for state in _reel_states:
		var pick := _pick_symbol(state.symbol_pool)
		state.target_symbol = pick
		final_symbols.append(pick)
	_active_symbols = final_symbols
	spin_started.emit()
	_round_complete = false
	for i in range(_reel_states.size()):
		_spin_single_reel(_reel_states[i], i)

func _spin_single_reel(state: ReelState, reel_index: int) -> void:
	if state == null:
		return
	if state.tween and state.tween.is_valid():
		state.tween.kill()
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	if reel_index > 0 and reel_stagger_delay > 0.0:
		tween.tween_interval(reel_index * reel_stagger_delay)
	var iterations := int(ceil(reel_spin_duration / max(symbol_cycle_interval, 0.05)))
	var slow_spins := clampi(final_reel_slowdown_spins, 1, iterations)
	var is_final_reel := reel_index == _reel_states.size() - 1
	for i in range(iterations):
		var spin_symbol := _pick_symbol(state.symbol_pool)
		tween.tween_callback(Callable(self, "_advance_reel").bind(state, spin_symbol))
		var interval := symbol_cycle_interval
		if is_final_reel and final_reel_slowdown_multiplier > 1.0 and i >= iterations - slow_spins:
			interval *= final_reel_slowdown_multiplier
		tween.tween_interval(interval)
	tween.tween_callback(Callable(self, "_advance_reel").bind(state, state.target_symbol))
	tween.tween_interval(result_hold_delay)
	tween.finished.connect(Callable(self, "_on_reel_tween_finished").bind(state, reel_index), CONNECT_ONE_SHOT)
	state.tween = tween

func _reset_highlights() -> void:
	for slot in _last_highlighted_slots:
		if is_instance_valid(slot):
			slot.scale = Vector2.ONE
			slot.self_modulate = Color.WHITE
	_last_highlighted_slots.clear()

func _animate_spin_start() -> void:
	if is_instance_valid(spin_button):
		spin_button.scale = Vector2.ONE
		var spin_tween := create_tween()
		spin_tween.tween_property(spin_button, "scale", Vector2(0.94, 0.94), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		spin_tween.tween_property(spin_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_reel_panel()
	_jolt_layout(10.0)
	for i in range(_reel_states.size()):
		var state := _reel_states[i]
		if state == null or state.root == null:
			continue
		state.root.self_modulate = Color.WHITE
		var reel_tween := create_tween()
		var delay := i * 0.04
		if delay > 0.0:
			reel_tween.tween_interval(delay)
		reel_tween.tween_property(state.root, "self_modulate", Color(1.08, 1.08, 1.08, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		reel_tween.tween_property(state.root, "self_modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flash_shader_contrast(true)
	_set_shader_rotation(true)

func _set_shader_rotation(active: bool) -> void:
	if not is_instance_valid(shader_bg):
		return
	var mat := shader_bg.material
	if mat == null:
		return
	if mat.has_method("set_shader_parameter"):
		mat.set_shader_parameter("is_rotating", active)
	var shader_material := mat as ShaderMaterial
	if shader_material == null:
		return
	var spin_param: Variant = shader_material.get_shader_parameter("spin_amount")
	var current_spin: float = spin_param if typeof(spin_param) in [TYPE_FLOAT, TYPE_INT] else 0.25
	var target_spin := 0.42 if active else 0.25
	if is_instance_valid(_shader_tween):
		_shader_tween.kill()
	_shader_tween = create_tween()
	_shader_tween.tween_method(Callable(self, "_set_shader_spin_amount"), current_spin, target_spin, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_shader_spin_amount(value: float) -> void:
	if not is_instance_valid(shader_bg):
		return
	var mat := shader_bg.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("spin_amount", value)

func _flash_shader_contrast(boost: bool) -> void:
	var target := 4.2 if boost else 3.5
	_drive_shader_parameter("contrast", target, 0.38)

func _burst_background_for_win() -> void:
	_drive_shader_parameter("contrast", 4.9, 0.32)

func _drive_shader_parameter(param: StringName, target: float, duration: float) -> void:
	if not is_instance_valid(shader_bg):
		return
	var shader_material := shader_bg.material as ShaderMaterial
	if shader_material == null:
		return
	var current_variant: Variant = shader_material.get_shader_parameter(param)
	var current: float = float(current_variant) if typeof(current_variant) in [TYPE_INT, TYPE_FLOAT] else target
	if is_instance_valid(_bg_flash_tween):
		_bg_flash_tween.kill()
	_bg_flash_tween = create_tween()
	_bg_flash_tween.tween_method(Callable(self, "_set_shader_param_value").bind(param, shader_material), current, target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_shader_param_value(value: float, param: StringName, shader_material: ShaderMaterial) -> void:
	if shader_material == null:
		return
	shader_material.set_shader_parameter(param, value)

func _pulse_reel_panel() -> void:
	if not is_instance_valid(reel_panel):
		return
	reel_panel.scale = Vector2.ONE
	var pulse := create_tween()
	pulse.tween_property(reel_panel, "scale", Vector2(1.04, 1.04), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(reel_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _jolt_layout(intensity: float) -> void:
	if not is_instance_valid(main_layout):
		return
	var base_position := main_layout.position
	if is_instance_valid(_layout_shake_tween):
		_layout_shake_tween.kill()
	var shake_offset := Vector2(_rng.randf_range(-intensity, intensity), _rng.randf_range(-intensity * 0.5, intensity * 0.5))
	_layout_shake_tween = create_tween()
	_layout_shake_tween.tween_property(main_layout, "position", base_position + shake_offset, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_layout_shake_tween.tween_property(main_layout, "position", base_position, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _advance_reel(state: ReelState, symbol: Dictionary) -> void:
	if state == null:
		return
	if symbol == null or symbol.is_empty():
		return
	state.buffer.append(symbol)
	while state.buffer.size() > state.slots.size():
		state.buffer.remove_at(0)
	_update_reel_visual(state)

func _update_reel_visual(state: ReelState) -> void:
	for i in range(state.slots.size()):
		var slot := state.slots[i]
		if slot == null:
			continue
		var symbol_entry: Dictionary = {}
		if i < state.buffer.size():
			var buffered_value := state.buffer[i]
			if typeof(buffered_value) == TYPE_DICTIONARY:
				symbol_entry = buffered_value
		_set_slot_texture(slot, symbol_entry)

func _set_slot_texture(slot: TextureRect, entry: Dictionary) -> void:
	if slot == null:
		return
	var icon: Texture2D = null
	if entry and entry.has(KEY_TEXTURE):
		icon = entry[KEY_TEXTURE]
	if icon == null:
		var texture_path: String = String(entry.get(KEY_TEXTURE_PATH, ""))
		if texture_path is String and texture_path != "" and ResourceLoader.exists(texture_path, "Texture2D"):
			icon = ResourceLoader.load(texture_path, "Texture2D")
			entry[KEY_TEXTURE] = icon
	var previous_texture: Texture2D = slot.texture
	slot.texture = icon
	if icon == null:
		slot.self_modulate = Color(1, 1, 1, 0.25)
		return
	var target_modulate: Color = entry.get(KEY_ICON_MODULATE, Color.WHITE)
	if previous_texture != icon:
		slot.self_modulate = target_modulate * Color(1, 1, 1, 0.6)
		var fade := create_tween()
		fade.tween_property(slot, "self_modulate", target_modulate, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		slot.self_modulate = target_modulate

func _on_reel_tween_finished(_state: ReelState, _index: int) -> void:
	_completed_reels += 1
	if SoundManager:
		SoundManager._play_reel_tick_sound()
	if _completed_reels >= _reel_states.size():
		_finish_spin()


func _finish_spin() -> void:
	_is_spinning = false
	_refresh_spin_button_state()
	var row_matrix := _build_row_matrix()
	var result := _evaluate_spin(row_matrix)
	var tease: Dictionary = {}
	if result.get("did_win", false):
		_apply_line_description(result)
		_burst_background_for_win()
		_jolt_layout(18.0)
		# Win stinger/reward sfx
		if SoundManager:
			SoundManager._play_random_win_sound()
			if String(result.get("type", "")) == RESULT_TYPE_GOLD:
				SoundManager._player_random_money_sound()
		await _process_reward(result)
		if helper_label:
			helper_label.text = "Line hit! Collecting reward..."
	else:
		tease = _detect_near_miss(row_matrix)
		if not tease.is_empty():
			await _tease_near_miss(tease)
		else:
			_update_status(result.get("description", "No luck this time"))
			if helper_label:
				helper_label.text = "No luck. Spin again for %dg" % spin_gold_cost
	_set_shader_rotation(false)
	_flash_shader_contrast(false)
	spin_finished.emit(result)

func _build_row_matrix() -> Array:
	var rows: Array = []
	var row_count: int = max(1, visible_rows)
	for row in range(row_count):
		var row_symbols: Array[Dictionary] = []
		for state in _reel_states:
			var symbol: Dictionary = {}
			if row < state.buffer.size():
				symbol = state.buffer[row]
			var slot_ref: TextureRect = null
			if row < state.slots.size():
				slot_ref = state.slots[row]
			row_symbols.append({
				LINE_KEY_SYMBOL: symbol,
				LINE_KEY_SLOT: slot_ref,
				"row": row,
			})
		rows.append(row_symbols)
	return rows

func _evaluate_spin(row_matrix: Array) -> Dictionary:
	var row_result := _evaluate_rows(row_matrix)
	if row_result.get("did_win", false):
		return row_result
	var diag_result := _evaluate_diagonals(row_matrix)
	if diag_result.get("did_win", false):
		return diag_result
	return {"did_win": false, "description": "No matching line"}

func _evaluate_rows(row_matrix: Array) -> Dictionary:
	for row_index in range(row_matrix.size()):
		var line_variant: Variant = row_matrix[row_index]
		if typeof(line_variant) != TYPE_ARRAY:
			continue
		var line_symbols: Array = line_variant
		var evaluation := _evaluate_symbol_line(line_symbols)
		if evaluation.get("did_win", false):
			evaluation["line_type"] = "row"
			evaluation["line_index"] = row_index
			return evaluation
	return {"did_win": false}

func _evaluate_diagonals(row_matrix: Array) -> Dictionary:
	if row_matrix.is_empty():
		return {"did_win": false}
	var row_count := row_matrix.size()
	var column_count := _reel_states.size()
	if column_count == 0:
		return {"did_win": false}
	var diag_length: int = min(row_count, column_count)
	var primary_symbols: Array[Dictionary] = []
	for i in range(diag_length):
		var row_variant: Variant = row_matrix[i]
		if typeof(row_variant) != TYPE_ARRAY:
			continue
		var row_symbols: Array = row_variant
		if i < row_symbols.size():
			var entry_variant: Variant = row_symbols[i]
			if typeof(entry_variant) == TYPE_DICTIONARY:
				primary_symbols.append(entry_variant)
	if primary_symbols.size() == diag_length:
		var primary_eval := _evaluate_symbol_line(primary_symbols)
		if primary_eval.get("did_win", false):
			primary_eval["line_type"] = "diag_primary"
			return primary_eval
	var secondary_symbols: Array[Dictionary] = []
	for i in range(diag_length):
		var row_idx := row_count - 1 - i
		if row_idx < 0 or row_idx >= row_matrix.size():
			continue
		var secondary_row_variant: Variant = row_matrix[row_idx]
		if typeof(secondary_row_variant) != TYPE_ARRAY:
			continue
		var secondary_row: Array = secondary_row_variant
		if i < secondary_row.size():
			var secondary_entry_variant: Variant = secondary_row[i]
			if typeof(secondary_entry_variant) == TYPE_DICTIONARY:
				secondary_symbols.append(secondary_entry_variant)
	if secondary_symbols.size() == diag_length:
		var secondary_eval := _evaluate_symbol_line(secondary_symbols)
		if secondary_eval.get("did_win", false):
			secondary_eval["line_type"] = "diag_secondary"
			return secondary_eval
	return {"did_win": false}

func _evaluate_symbol_line(line_symbols: Array) -> Dictionary:
	if line_symbols.is_empty():
		return {"did_win": false}
	var first_entry_variant: Variant = line_symbols[0]
	if typeof(first_entry_variant) != TYPE_DICTIONARY:
		return {"did_win": false}
	var first_entry: Dictionary = first_entry_variant
	var base_symbol_variant: Variant = first_entry.get(LINE_KEY_SYMBOL, {})
	if typeof(base_symbol_variant) != TYPE_DICTIONARY:
		return {"did_win": false}
	var base_symbol: Dictionary = base_symbol_variant
	if base_symbol.is_empty():
		return {"did_win": false}
	var base_id := String(base_symbol.get(KEY_ID, ""))
	if base_id == "":
		return {"did_win": false}
	for entry_variant in line_symbols:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			return {"did_win": false}
		var entry: Dictionary = entry_variant
		var symbol_variant: Variant = entry.get(LINE_KEY_SYMBOL, {})
		if typeof(symbol_variant) != TYPE_DICTIONARY:
			return {"did_win": false}
		var symbol: Dictionary = symbol_variant
		if symbol.is_empty():
			return {"did_win": false}
		var symbol_id := String(symbol.get(KEY_ID, ""))
		if symbol_id != base_id:
			return {"did_win": false}
	var reward := _generate_reward_for_symbol(base_symbol)
	reward["did_win"] = true
	reward["symbol"] = base_symbol
	reward["line_entries"] = line_symbols
	return reward

func _apply_line_description(result: Dictionary) -> void:
	var line_type := String(result.get("line_type", ""))
	if line_type == "":
		return
	var desc := String(result.get("description", "Jackpot!"))
	match line_type:
		"row":
			var line_index := int(result.get("line_index", 0))
			result["description"] = "%s (Row %d)" % [desc, line_index + 1]
		"diag_primary":
			result["description"] = "%s (Diagonal ↘)" % desc
		"diag_secondary":
			result["description"] = "%s (Diagonal ↗)" % desc
		_:
			result["description"] = desc

func _detect_near_miss(row_matrix: Array) -> Dictionary:
	var lines := _gather_all_lines(row_matrix)
	for line in lines:
		var entries_variant: Variant = line.get("entries", [])
		if typeof(entries_variant) != TYPE_ARRAY:
			continue
		var entries: Array = entries_variant
		if entries.size() <= 1:
			continue
		var counts := {}
		var best_symbol := ""
		var best_count := 0
		var matched_symbol: Dictionary = {}
		for entry_variant in entries:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var symbol_variant: Variant = entry_variant.get(LINE_KEY_SYMBOL, {})
			if typeof(symbol_variant) != TYPE_DICTIONARY:
				continue
			var symbol: Dictionary = symbol_variant
			if symbol.is_empty():
				continue
			var symbol_id := String(symbol.get(KEY_ID, ""))
			if symbol_id == "":
				continue
			var tally := int(counts.get(symbol_id, 0)) + 1
			counts[symbol_id] = tally
			if tally > best_count:
				best_count = tally
				best_symbol = symbol_id
				matched_symbol = symbol
		var needed := entries.size() - 1
		if best_symbol == "" or best_count != needed:
			continue
		var miss_entry: Dictionary = {}
		for entry_variant in entries:
			if typeof(entry_variant) != TYPE_DICTIONARY:
				continue
			var symbol_variant: Variant = entry_variant.get(LINE_KEY_SYMBOL, {})
			if typeof(symbol_variant) != TYPE_DICTIONARY:
				continue
			var symbol: Dictionary = symbol_variant
			var symbol_id := String(symbol.get(KEY_ID, ""))
			if symbol_id != best_symbol:
				miss_entry = entry_variant
				break
		if miss_entry.is_empty():
			continue
		var label := String(matched_symbol.get(KEY_LABEL, best_symbol)).strip_edges()
		return {
			"line_entries": entries,
			"line_type": line.get("line_type", ""),
			"line_index": line.get("line_index", -1),
			"symbol_id": best_symbol,
			"symbol_label": label,
			"miss_entry": miss_entry,
		}
	return {}

func _gather_all_lines(row_matrix: Array) -> Array:
	var lines: Array = []
	for row_index in range(row_matrix.size()):
		var row_variant: Variant = row_matrix[row_index]
		if typeof(row_variant) != TYPE_ARRAY:
			continue
		lines.append({"line_type": "row", "line_index": row_index, "entries": row_variant})
	if row_matrix.is_empty():
		return lines
	var row_count := row_matrix.size()
	var column_count := _reel_states.size()
	if column_count == 0:
		return lines
	var diag_length: int = min(row_count, column_count)
	var primary: Array = []
	for i in range(diag_length):
		var row_variant: Variant = row_matrix[i]
		if typeof(row_variant) != TYPE_ARRAY:
			continue
		var row_symbols: Array = row_variant
		if i < row_symbols.size():
			var entry_variant: Variant = row_symbols[i]
			if typeof(entry_variant) == TYPE_DICTIONARY:
				primary.append(entry_variant)
	if primary.size() == diag_length:
		lines.append({"line_type": "diag_primary", "entries": primary})
	var secondary: Array = []
	for i in range(diag_length):
		var row_idx := row_count - 1 - i
		if row_idx < 0 or row_idx >= row_matrix.size():
			continue
		var row_variant: Variant = row_matrix[row_idx]
		if typeof(row_variant) != TYPE_ARRAY:
			continue
		var row_symbols: Array = row_variant
		if i < row_symbols.size():
			var entry_variant: Variant = row_symbols[i]
			if typeof(entry_variant) == TYPE_DICTIONARY:
				secondary.append(entry_variant)
	if secondary.size() == diag_length:
		lines.append({"line_type": "diag_secondary", "entries": secondary})
	return lines

func _tease_near_miss(tease: Dictionary) -> void:
	var symbol_label := String(tease.get("symbol_label", ""))
	var line_type := String(tease.get("line_type", ""))
	var descriptor := symbol_label if symbol_label != "" else "that line"
	var message := "So close! One more %s" % descriptor
	if line_type == "row" and tease.has("line_index"):
		message += " on Row %d" % (int(tease.get("line_index", 0)) + 1)
	_update_status(message)
	if helper_label:
		helper_label.text = "Almost hit %s — try again!" % descriptor
	_jolt_layout(14.0)
	# Near-miss sfx
	if SoundManager:
		SoundManager._play_random_negative_sound()
	var entries_variant: Variant = tease.get("line_entries", [])
	if typeof(entries_variant) == TYPE_ARRAY:
		_flash_near_miss_slots(entries_variant, String(tease.get("symbol_id", "")), tease.get("miss_entry", {}))
	if near_miss_pause > 0.0:
		await get_tree().create_timer(near_miss_pause).timeout

func _flash_near_miss_slots(entries: Array, matched_id: String, miss_entry: Variant) -> void:
	_reset_highlights()
	for entry_variant in entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var slot_variant: Variant = entry.get(LINE_KEY_SLOT, null)
		var slot: TextureRect = slot_variant if slot_variant is TextureRect else null
		if slot == null:
			continue
		_last_highlighted_slots.append(slot)
		var symbol_variant: Variant = entry.get(LINE_KEY_SYMBOL, {})
		var symbol_id := ""
		if typeof(symbol_variant) == TYPE_DICTIONARY:
			var symbol: Dictionary = symbol_variant
			symbol_id = String(symbol.get(KEY_ID, ""))
		if symbol_id == matched_id:
			var glow := create_tween()
			glow.tween_property(slot, "self_modulate", near_miss_color, win_pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			glow.tween_property(slot, "self_modulate", Color.WHITE, win_pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			glow.parallel().tween_property(slot, "scale", Vector2(win_pulse_scale, win_pulse_scale), win_pulse_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			glow.parallel().tween_property(slot, "scale", Vector2.ONE, win_pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			_shake_slot(slot)
	if typeof(miss_entry) == TYPE_DICTIONARY:
		var miss_slot_variant: Variant = miss_entry.get(LINE_KEY_SLOT, null)
		var miss_slot: TextureRect = miss_slot_variant if miss_slot_variant is TextureRect else null
		if miss_slot:
			_shake_slot(miss_slot)

func _shake_slot(slot: TextureRect) -> void:
	if slot == null:
		return
	var shake := create_tween()
	shake.tween_property(slot, "rotation_degrees", 4.5, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shake.tween_property(slot, "rotation_degrees", -4.5, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake.tween_property(slot, "rotation_degrees", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shake.parallel().tween_property(slot, "scale", Vector2(0.92, 0.92), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	shake.parallel().tween_property(slot, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _highlight_line(line_entries: Array) -> void:
	if line_entries.is_empty():
		return
	for entry_variant in line_entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var slot_variant: Variant = entry.get(LINE_KEY_SLOT, null)
		var slot: TextureRect = slot_variant if slot_variant is TextureRect else null
		if slot == null:
			continue
		_last_highlighted_slots.append(slot)
		slot.scale = Vector2.ONE
		slot.self_modulate = Color.WHITE
		var highlight := create_tween()
		highlight.tween_property(slot, "self_modulate", win_highlight_color, win_pulse_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		highlight.parallel().tween_property(slot, "scale", Vector2(win_pulse_scale, win_pulse_scale), win_pulse_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		highlight.tween_property(slot, "self_modulate", Color.WHITE, win_pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		highlight.parallel().tween_property(slot, "scale", Vector2.ONE, win_pulse_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _pick_symbol(pool: Array[Dictionary]) -> Dictionary:
	if pool.is_empty():
		return {}
	var total_weight := 0.0
	for entry in pool:
		total_weight += max(entry.get(KEY_WEIGHT, 0.0), 0.0)
	if total_weight <= 0.0:
		return pool[_rng.randi_range(0, pool.size() - 1)]
	var roll := _rng.randf_range(0.0, total_weight)
	var accumulator := 0.0
	for entry in pool:
		accumulator += max(entry.get(KEY_WEIGHT, 0.0), 0.0)
		if roll <= accumulator:
			return entry
	return pool.back()

func _generate_reward_for_symbol(symbol: Dictionary) -> Dictionary:
	var reward_type := String(symbol.get(KEY_REWARD_TYPE, RESULT_TYPE_EQUIPMENT))
	match reward_type:
		RESULT_TYPE_EQUIPMENT:
			return _prepare_equipment_reward(symbol)
		RESULT_TYPE_CONSUMABLE:
			return _prepare_consumable_reward(symbol)
		RESULT_TYPE_GOLD:
			return _prepare_gold_reward(symbol)
		RESULT_TYPE_TILE:
			return _prepare_tile_reward(symbol)
		_:
			return _prepare_equipment_reward(symbol)

func _ensure_loot_manager() -> FW_LootManager:
	_loot_manager = FW_MinigameRewardHelper.ensure_loot_manager(_loot_manager)
	return _loot_manager

func _prepare_equipment_reward(_symbol: Dictionary) -> Dictionary:
	var manager := _ensure_loot_manager()
	var equipment: FW_Item = manager.sweet_loot()
	if equipment == null:
		return {"did_win": false, "description": "No equipment available", "items": [], "buffs": []}
	return {
		"items": [equipment],
		"buffs": [],
		"description": "You pulled %s" % equipment.name,
	}

func _prepare_consumable_reward(_symbol: Dictionary) -> Dictionary:
	var manager := _ensure_loot_manager()
	var consumable: FW_Item = manager.generate_random_consumable()
	if consumable == null:
		return {"did_win": false, "description": "Consumable pool empty", "items": [], "buffs": []}
	return {
		"items": [consumable],
		"buffs": [],
		"description": "Consumable score: %s" % consumable.name,
	}


func _prepare_gold_reward(symbol: Dictionary) -> Dictionary:
	var manager := _ensure_loot_manager()
	var meta_variant: Variant = symbol.get(KEY_REWARD_DATA, {})
	var meta: Dictionary = meta_variant if typeof(meta_variant) == TYPE_DICTIONARY else {}
	var min_amount := int(meta.get("min", 100))
	var max_amount := int(meta.get("max", 240))
	if min_amount > max_amount:
		var temp := min_amount
		min_amount = max_amount
		max_amount = temp
	var amount := _rng.randi_range(min_amount, max_amount)
	var gold_item: FW_Item = manager.create_gold_item(amount)
	if gold_item == null:
		return {"items": [], "buffs": [], "description": "Gold mint offline"}
	gold_item.name = "%d gp" % amount
	if gold_item.flavor_text == null or gold_item.flavor_text.strip_edges() == "":
		gold_item.flavor_text = "Fresh coins straight from the vault."
	return {
		"items": [gold_item],
		"buffs": [],
		"description": "Scooped %d gold" % amount,
	}

func _prepare_tile_reward(symbol: Dictionary) -> Dictionary:
	var color_id := String(symbol.get(KEY_ID, "tile"))
	var label := String(symbol.get(KEY_LABEL, color_id))
	return {
		"items": [],
		"buffs": [],
		"metadata": {"tile_id": color_id, "symbol": symbol},
		"description": "Captured tile blueprint: %s" % label,
	}

func _build_debuff_queue() -> Array:
	return FW_MinigameRewardHelper.build_debuff_queue(debuff_pool)

func _draw_random_debuff() -> FW_Buff:
	if _debuff_queue.is_empty():
		_debuff_queue = _build_debuff_queue()
	return FW_MinigameRewardHelper.draw_buff_from_queue(_debuff_queue)

func _process_reward(result: Dictionary) -> void:
	var description := String(result.get("description", "Jackpot!"))
	var items_variant: Variant = result.get("items", [])
	var buffs_variant: Variant = result.get("buffs", [])
	var items: Array = items_variant if typeof(items_variant) == TYPE_ARRAY else []
	var buffs: Array = buffs_variant if typeof(buffs_variant) == TYPE_ARRAY else []
	var metadata_variant: Variant = result.get("metadata", {})
	var metadata: Dictionary = metadata_variant if typeof(metadata_variant) == TYPE_DICTIONARY else {}
	_update_status(description)
	var highlight_entries_variant: Variant = result.get("line_entries", [])
	if typeof(highlight_entries_variant) == TYPE_ARRAY:
		var highlight_entries: Array = highlight_entries_variant
		_highlight_line(highlight_entries)
	if helper_label and not metadata.is_empty():
		helper_label.text = "Metadata: %s" % str(metadata)
	if win_reward_delay > 0.0:
		await get_tree().create_timer(win_reward_delay).timeout
	_present_loot(items, description, buffs, metadata)
	if result.get("did_win", false) and not items.is_empty():
		_round_complete = true
		FW_MinigameRewardHelper.mark_minigame_completed(true)

func _exit_tree() -> void:
	if EventBus.player_state_changed.is_connected(_on_player_state_changed):
		EventBus.player_state_changed.disconnect(_on_player_state_changed)

func _present_loot(items: Array, description: String, buffs: Array, metadata: Dictionary = {}) -> void:
	if not is_instance_valid(loot_screen):
		return
	var trimmed := description.strip_edges()
	if trimmed == "" and not metadata.is_empty():
		trimmed = _format_metadata_description(metadata)
	if loot_screen.has_method("show_loot_collection"):
		loot_screen.call("show_loot_collection", items, trimmed, buffs)
	elif not items.is_empty() and loot_screen.has_method("show_single_loot"):
		loot_screen.call("show_single_loot", items[0])
		if trimmed != "" and loot_screen.has_method("show_text"):
			loot_screen.call("show_text", trimmed)
	elif not buffs.is_empty() and loot_screen.has_method("show_buffs"):
		loot_screen.call("show_buffs", buffs)
		if trimmed != "" and loot_screen.has_method("show_text"):
			loot_screen.call("show_text", trimmed)
	elif trimmed != "" and loot_screen.has_method("show_text"):
		loot_screen.call("show_text", trimmed)
	else:
		return
	if loot_screen.has_method("slide_in"):
		loot_screen.call("slide_in")

func _format_metadata_description(metadata: Dictionary) -> String:
	var tile_id := String(metadata.get("tile_id", "")).strip_edges()
	var symbol_variant: Variant = metadata.get("symbol", {})
	var symbol_label := ""
	if typeof(symbol_variant) == TYPE_DICTIONARY:
		symbol_label = String(symbol_variant.get(KEY_LABEL, "")).strip_edges()
	if symbol_label != "":
		return "Blueprint unlocked: %s" % symbol_label
	if tile_id != "":
		return "Blueprint unlocked: %s" % tile_id.capitalize()
	return "Blueprint data secured"

func _queue_debuff(buff: FW_Buff) -> void:
	FW_MinigameRewardHelper.queue_debuff_on_player(buff)

func _apply_forfeit_penalty() -> bool:
	var buff := _draw_random_debuff()
	if buff == null:
		return false
	_queue_debuff(buff)
	_present_loot([], "Walking away angers the machine.", [buff])
	if helper_label:
		helper_label.text = "Debuff applied! Dismiss to leave."
	return true

func _update_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _on_loot_screen_back_button() -> void:
	_on_back_button_pressed()

func _on_back_button_pressed() -> void:
	if _is_spinning:
		return
	if _round_complete:
		_exit_pending = false
		FW_MinigameRewardHelper.mark_minigame_completed(true)
		ScreenRotator.change_scene("res://Scenes/level_select2.tscn")
		return
	if not _exit_pending:
		_exit_pending = _apply_forfeit_penalty()
		if _exit_pending:
			return
	else:
		_exit_pending = false
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	ScreenRotator.change_scene("res://Scenes/level_select2.tscn")
