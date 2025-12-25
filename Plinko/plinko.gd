extends CanvasLayer

signal drop_started
signal drop_finished(result: Dictionary)

const RESULT_TYPE_EQUIPMENT := "equipment"
const RESULT_TYPE_CONSUMABLE := "consumable"
const RESULT_TYPE_GOLD := "gold"
const RESULT_TYPE_DEBUFF := "debuff"

const KEY_SLOT_ID := "id"
const KEY_LABEL := "label"
const KEY_WEIGHT := "weight"
const KEY_REWARD_TYPE := "reward_type"
const KEY_REWARD_DATA := "reward_data"
const KEY_ICON := "icon"
const KEY_ICON_PATH := "icon_path"
const KEY_TEXTURE := "texture"
const PREVIEW_COLOR_DEFAULT := Color(0.914, 0.773, 0.569, 1.0)
const PREVIEW_COLOR_CONSUMABLE := Color(0.78, 0.93, 1.0, 1.0)
const PREVIEW_COLOR_GOLD := Color(1.0, 0.87, 0.35, 1.0)
const PREVIEW_COLOR_DEBUFF := Color(1.0, 0.58, 0.58, 1.0)


const PEG_PATTERN_IDLE := "idle_wobble"
const PEG_PATTERN_STATIC := "static"
const PEG_PATTERN_SWAY_HORIZONTAL := "sway_horizontal"
const PEG_PATTERN_SWAY_VERTICAL := "sway_vertical"
const PEG_PATTERN_ORBIT := "orbit"
const PEG_PATTERN_FLOAT_DIAGONAL := "float_diagonal"
const PEG_PATTERN_DRIFT := "drift"
const PEG_ACTIVE_PATTERNS := [
	PEG_PATTERN_SWAY_HORIZONTAL,
	PEG_PATTERN_SWAY_VERTICAL,
	PEG_PATTERN_ORBIT,
	PEG_PATTERN_FLOAT_DIAGONAL,
	PEG_PATTERN_DRIFT,
]
const PEG_PATTERN_DISPLAY_NAMES := {
	PEG_PATTERN_STATIC: "Stillness",
	PEG_PATTERN_SWAY_HORIZONTAL: "Side Sway",
	PEG_PATTERN_SWAY_VERTICAL: "Sky Bounce",
	PEG_PATTERN_ORBIT: "Orbit",
	PEG_PATTERN_FLOAT_DIAGONAL: "Drift Tilt",
	PEG_PATTERN_DRIFT: "Lazy Drift",
}

const LAYER_PEG := 1
const LAYER_BALL := 1 << 1
const LAYER_SLOT := 1 << 2

@export_range(0, 500, 1) var drop_gold_cost := 10
@export var require_player_gold := true
@export_range(0.0, 3.0, 0.05, "seconds") var drop_result_delay := 0.65
@export_range(1, 5, 1) var balls_per_round := 1
@export var slot_definitions: Array[Dictionary] = []
@export var shuffle_slots_on_ready := true
@export var debuff_pool: Array[FW_Buff] = []
@export var enable_autoplay := false
@export var spawn_position := Vector2(320, 32)
@export var spawn_scatter := Vector2(32, 0)
@export var spawn_motion_enabled := true
@export_range(0.5, 8.0, 0.1, "seconds") var spawn_motion_cycle := 2.8
@export_range(0.0, 160.0, 1.0, "suffix:px") var spawn_motion_padding := 64.0
@export_range(0.0, 240.0, 1.0, "suffix:px") var peg_top_clearance := 56.0
@export_range(0.0, 2.0, 0.05) var spawn_momentum_inertia := 0.4
@export_range(10.0, 600.0, 5.0, "suffix:px/s") var spawn_momentum_max_speed := 200.0
@export_range(3, 10, 1) var peg_rows := 6
@export_range(3, 10, 1) var peg_columns := 7
@export var board_padding := Vector2(48, 48)
@export_range(4.0, 48.0, 0.5) var peg_radius := 14.0
@export var peg_texture: Texture2D = preload("res://tile_images/ball.png")
@export var peg_motion_enabled := true
@export_range(0.0, 24.0, 1.0, "suffix:px") var peg_idle_wobble_distance := 6.0
@export_range(0.05, 4.0, 0.05, "speed") var peg_motion_speed := 1.2
@export_range(0.0, 72.0, 1.0, "suffix:px") var peg_motion_sway_distance := 18.0
@export_range(0.0, 72.0, 1.0, "suffix:px") var peg_motion_vertical_distance := 16.0
@export_range(0.0, 64.0, 1.0, "suffix:px") var peg_motion_orbit_radius := 12.0
@export_range(0.0, 1.0, 0.01) var board_glow_strength := 0.3
@export var ball_texture: Texture2D = preload("res://Sinkers/Sinker.png")
@export_range(6.0, 48.0, 0.5) var ball_radius := 18.0
@export_range(0.1, 5.0, 0.05) var ball_gravity_scale := 1.0
@export_range(0.05, 1.0, 0.05) var ball_bounciness := 0.65
@export_range(0.0, 1.0, 0.05) var ball_friction := 0.1
@export_range(32.0, 200.0, 1.0) var slot_capture_height := 72.0
@export_range(0.0, 200.0, 1.0, "suffix:px") var board_bottom_gap := 48.0
@export_range(0.05, 2.0, 0.05) var slot_preview_flash_duration := 0.25
@export_range(0.0, 1.5, 0.05) var shader_bounce_contrast_boost := 0.4
@export_range(0.0, 0.5, 0.01) var shader_bounce_spin_boost := 0.06
@export_range(0.05, 1.5, 0.05, "seconds") var shader_bounce_duration := 0.35
@export_range(0.0, 0.5, 0.01, "seconds") var shader_bounce_cooldown := 0.12

@onready var status_label: Label = %StatusLabel
@onready var helper_label: Label = %HelperLabel
@onready var drop_button: Button = %DropButton
@onready var gold_label: Label = %GoldLabel
@onready var board_background: ColorRect = %BoardBackground
@onready var shader_bg: ColorRect = %ShaderBG
@onready var slot_preview_container: HBoxContainer = %SlotPreviewContainer
@onready var slot_preview_template: PanelContainer = %SlotPreviewTemplate
@onready var board_root: Node2D = %BoardRoot
@onready var peg_layer: Node2D = board_root.get_node("PegLayer")
@onready var slot_layer: Node2D = board_root.get_node("SlotLayer")
@onready var wall_layer: Node2D = board_root.get_node("WallLayer")
@onready var ball_layer: Node2D = board_root.get_node("BallLayer")
@onready var spawn_marker: Node2D = %BallSpawn
@onready var loot_screen: CanvasLayer = %LootScreen

var _loot_manager: FW_LootManager
var _debuff_queue: Array[FW_Buff] = []
var _rng := RandomNumberGenerator.new()
var _pending_rewards: Array[Dictionary] = []
var _slot_reward_cache: Dictionary = {}
var _slot_preview_nodes: Dictionary = {}
var _slot_preview_tweens: Dictionary = {}
var _active_balls: Array[RigidBody2D] = []
var _helper_idle_text := ""
var _board_size := Vector2.ZERO
var _balls_in_play := 0
var _spawn_motion_bounds := Vector2.ZERO
var _spawn_motion_tween: Tween
var _spawn_indicator: Sprite2D
var _spawn_marker_velocity := 0.0
var _previous_spawn_marker_x := NAN
var _board_pulse_tween: Tween
var _peg_nodes: Array[StaticBody2D] = []
var _peg_base_positions: Dictionary = {}
var _peg_pattern_id := PEG_PATTERN_STATIC
var _peg_pattern_time := 0.0
var _peg_drop_pattern_active := false
var _shader_material: ShaderMaterial
var _shader_base_contrast := 3.5
var _shader_base_spin := 0.25
var _shader_param_tweens: Dictionary = {}


func _ready() -> void:
	set_physics_process(true)
	_rng.randomize()
	await get_tree().process_frame
	_board_size = board_background.size
	_initialize_shader_feedback()
	SoundManager.wire_up_all_buttons()
	_helper_idle_text = helper_label.text if helper_label else ""
	_prepare_slot_config()
	_preroll_slot_rewards()
	_connect_ui()
	_listen_for_player_updates()
	_connect_loot_screen()
	_align_spawn_marker()
	_build_board_geometry()
	_activate_idle_peg_motion()
	_populate_slot_previews()
	_refresh_gold_label()
	_refresh_drop_button_state()
	if enable_autoplay:
		_autoplay_when_ready()



func _prepare_slot_config() -> void:
	if slot_definitions.is_empty():
		slot_definitions = _build_default_slots()
	if shuffle_slots_on_ready:
		_shuffle_slot_definitions()
	for i in range(slot_definitions.size()):
		var entry: Dictionary = slot_definitions[i]
		if typeof(entry) != TYPE_DICTIONARY:
			entry = {}
		var slot_id := String(entry.get(KEY_SLOT_ID, ""))
		if slot_id == "":
			slot_id = "slot_%d" % i
			entry[KEY_SLOT_ID] = slot_id
		if not entry.has(KEY_LABEL):
			entry[KEY_LABEL] = slot_id.capitalize()
		slot_definitions[i] = entry
	shuffle_slots_on_ready = false


func _build_default_slots() -> Array[Dictionary]:
	return [
		{
			KEY_SLOT_ID: "equipment",
			KEY_LABEL: "Armory",
			KEY_WEIGHT: 2.0,
			KEY_REWARD_TYPE: RESULT_TYPE_EQUIPMENT,
			KEY_ICON_PATH: "res://Equipment/Images/harness_armor.png",
		},
		{
			KEY_SLOT_ID: "consumable",
			KEY_LABEL: "Rations",
			KEY_WEIGHT: 2.0,
			KEY_REWARD_TYPE: RESULT_TYPE_CONSUMABLE,
			KEY_ICON_PATH: "res://Inventory/ConsumableSlot.png",
		},
		{
			KEY_SLOT_ID: "gold",
			KEY_LABEL: "Gold Cache",
			KEY_WEIGHT: 1.5,
			KEY_REWARD_TYPE: RESULT_TYPE_GOLD,
			KEY_REWARD_DATA: {"min": 45, "max": 120},
			KEY_ICON_PATH: "res://Item/Junk/Images/gold_coins.png",
		},
		{
			KEY_SLOT_ID: "debuff",
			KEY_LABEL: "Mishap",
			KEY_WEIGHT: 1.0,
			KEY_REWARD_TYPE: RESULT_TYPE_DEBUFF,
			KEY_ICON_PATH: "res://Buffs/Images/demoralized.png",
		},
	]


func _shuffle_slot_definitions() -> void:
	if slot_definitions.size() <= 1:
		return
	var rng := _rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for i in range(slot_definitions.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, i)
		if swap_index == i:
			continue
		var temp := slot_definitions[i]
		slot_definitions[i] = slot_definitions[swap_index]
		slot_definitions[swap_index] = temp


func _preroll_slot_rewards() -> void:
	_slot_reward_cache.clear()
	for slot in slot_definitions:
		var slot_id := _resolve_slot_id(slot)
		if slot_id == "":
			continue
		_slot_reward_cache[slot_id] = _build_reward_payload(slot)


func _connect_ui() -> void:
	var drop_callable := Callable(self, "_on_drop_button_pressed")
	if drop_button and not drop_button.pressed.is_connected(drop_callable):
		drop_button.pressed.connect(drop_callable)
	if slot_preview_template:
		slot_preview_template.visible = false


func _listen_for_player_updates() -> void:
	if not EventBus.player_state_changed.is_connected(_on_player_state_changed):
		EventBus.player_state_changed.connect(_on_player_state_changed)


func _connect_loot_screen() -> void:
	if not is_instance_valid(loot_screen):
		return
	if loot_screen.has_signal("back_button"):
		var back_callable := Callable(self, "_on_loot_screen_back_button")
		if not loot_screen.is_connected("back_button", back_callable):
			loot_screen.connect("back_button", back_callable)


func _align_spawn_marker() -> void:
	if spawn_marker:
		spawn_marker.position = spawn_position
		_previous_spawn_marker_x = spawn_marker.position.x
	_ensure_spawn_indicator()
	_update_spawn_motion_bounds()
	_apply_spawn_marker_constraints()
	_start_spawn_marker_motion()
	_set_spawn_marker_visible(true)


func _ensure_spawn_indicator() -> void:
	if not is_instance_valid(spawn_marker):
		return
	if not is_instance_valid(_spawn_indicator):
		var indicator := Sprite2D.new()
		indicator.name = "DropIndicator"
		indicator.centered = true
		indicator.position = Vector2.ZERO
		indicator.z_index = 100
		indicator.self_modulate = Color(1.15, 1.1, 0.7, 0.92)
		spawn_marker.add_child(indicator)
		_spawn_indicator = indicator
	if is_instance_valid(_spawn_indicator):
		_spawn_indicator.texture = ball_texture
		if _spawn_indicator.texture:
			var texture_size := _spawn_indicator.texture.get_size()
			if texture_size != Vector2.ZERO:
				var target_radius: float = max(ball_radius, 8.0)
				var scale_factor: float = (target_radius * 2.0) / max(texture_size.x, texture_size.y)
				_spawn_indicator.scale = Vector2.ONE * scale_factor
		_spawn_indicator.visible = true


func _update_spawn_motion_bounds() -> void:
	if _board_size == Vector2.ZERO:
		return
	var min_x: float = board_padding.x + spawn_motion_padding
	var max_x: float = _board_size.x - board_padding.x - spawn_motion_padding
	if min_x > max_x:
		var midpoint: float = _board_size.x * 0.5
		min_x = midpoint
		max_x = midpoint
	_spawn_motion_bounds = Vector2(min_x, max_x)


func _apply_spawn_marker_constraints() -> void:
	if not is_instance_valid(spawn_marker):
		return
	var min_x: float = min(_spawn_motion_bounds.x, _spawn_motion_bounds.y)
	var max_x: float = max(_spawn_motion_bounds.x, _spawn_motion_bounds.y)
	if is_zero_approx(max_x - min_x):
		spawn_marker.position.x = min_x
		return
	var clamped_x: float = clampf(spawn_marker.position.x, min_x, max_x)
	spawn_marker.position.x = clamped_x


func _start_spawn_marker_motion() -> void:
	_stop_spawn_marker_motion()
	if not spawn_motion_enabled or not is_instance_valid(spawn_marker):
		return
	var min_x: float = min(_spawn_motion_bounds.x, _spawn_motion_bounds.y)
	var max_x: float = max(_spawn_motion_bounds.x, _spawn_motion_bounds.y)
	if is_zero_approx(max_x - min_x):
		return
	var duration: float = max(spawn_motion_cycle, 0.1)
	var midpoint: float = (min_x + max_x) * 0.5
	var first_target: float = max_x if spawn_marker.position.x <= midpoint else min_x
	var second_target: float = min_x if first_target == max_x else max_x
	_spawn_motion_tween = get_tree().create_tween()
	_spawn_motion_tween.set_trans(Tween.TRANS_SINE)
	_spawn_motion_tween.set_ease(Tween.EASE_IN_OUT)
	_spawn_motion_tween.set_loops()
	_spawn_motion_tween.tween_property(spawn_marker, "position:x", first_target, duration * 0.5)
	_spawn_motion_tween.tween_property(spawn_marker, "position:x", second_target, duration * 0.5)


func _stop_spawn_marker_motion() -> void:
	if _spawn_motion_tween and _spawn_motion_tween.is_running():
		_spawn_motion_tween.kill()
	_spawn_motion_tween = null


func _set_spawn_marker_visible(visible_state: bool) -> void:
	if is_instance_valid(spawn_marker):
		spawn_marker.visible = visible_state
	if is_instance_valid(_spawn_indicator):
		_spawn_indicator.visible = visible_state


#func _pulse_board_background() -> void:
	#if not is_instance_valid(board_root):
		#return
	#_stop_board_pulse()
	#board_root.scale = Vector2.ONE
	#_board_pulse_tween = get_tree().create_tween()
	#_board_pulse_tween.set_trans(Tween.TRANS_SINE)
	#_board_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	#_board_pulse_tween.set_loops()
	#_board_pulse_tween.tween_property(board_root, "scale", Vector2.ONE * 1.03, 0.22)
	#_board_pulse_tween.tween_property(board_root, "scale", Vector2.ONE, 0.28)


func _stop_board_pulse() -> void:
	if _board_pulse_tween and _board_pulse_tween.is_running():
		_board_pulse_tween.kill()
	_board_pulse_tween = null
	if is_instance_valid(board_root):
		board_root.scale = Vector2.ONE


func _build_board_geometry() -> void:
	_clear_board_layer(peg_layer)
	_clear_board_layer(wall_layer)
	_clear_board_layer(slot_layer)
	_build_pegs()
	_build_walls()
	_build_slot_triggers()


func _clear_board_layer(target_layer: Node) -> void:
	if not is_instance_valid(target_layer):
		return
	for child in target_layer.get_children():
		child.queue_free()
	if target_layer == peg_layer:
		_peg_nodes.clear()
		_peg_base_positions.clear()


func _build_pegs() -> void:
	if not is_instance_valid(peg_layer):
		return
	_peg_nodes.clear()
	_peg_base_positions.clear()
	var usable_width: float = max(_board_size.x - board_padding.x * 2.0, 0.0)
	var usable_height: float = max(_board_size.y - board_padding.y * 2.0 - slot_capture_height - peg_top_clearance - board_bottom_gap, 0.0)
	if usable_width <= 0.0 or usable_height <= 0.0:
		return
	var x_step: float = usable_width / float(max(1, peg_columns - 1))
	var y_step: float = usable_height / float(max(1, peg_rows - 1))
	var base_y: float = board_padding.y + peg_top_clearance + peg_radius
	for row in range(peg_rows):
		var y: float = base_y + row * y_step
		var row_shift: float = x_step * 0.5 if row % 2 == 1 else 0.0
		for column in range(peg_columns):
			var x: float = board_padding.x + column * x_step + row_shift
			if x < board_padding.x or x > _board_size.x - board_padding.x:
				continue
			_add_peg(Vector2(x, y))


func _add_peg(position: Vector2) -> void:
	var peg := StaticBody2D.new()
	peg.collision_layer = LAYER_PEG
	peg.collision_mask = LAYER_BALL
	peg.position = position
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = peg_radius
	collider.shape = shape
	peg.add_child(collider)
	var sprite := Sprite2D.new()
	sprite.texture = peg_texture
	sprite.modulate = Color(0.85, 0.78, 0.62)
	if sprite.texture:
		var base_size := sprite.texture.get_size()
		if base_size != Vector2.ZERO:
			var scale_factor: float = (peg_radius * 2.0) / max(base_size.x, base_size.y)
			sprite.scale = Vector2.ONE * scale_factor
	peg.add_child(sprite)
	peg_layer.add_child(peg)
	_peg_nodes.append(peg)
	_peg_base_positions[peg] = position


func _build_walls() -> void:
	_add_wall(Vector2(board_padding.x * 0.4, _board_size.y * 0.5), Vector2(board_padding.x * 0.8, _board_size.y))
	_add_wall(Vector2(_board_size.x - board_padding.x * 0.4, _board_size.y * 0.5), Vector2(board_padding.x * 0.8, _board_size.y))
	_add_wall(Vector2(_board_size.x * 0.5, _board_size.y - slot_capture_height * 0.25), Vector2(_board_size.x, slot_capture_height * 0.5))


func _add_wall(position: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = LAYER_PEG
	wall.collision_mask = LAYER_BALL
	wall.position = position
	var collider := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	collider.shape = rect
	wall.add_child(collider)
	wall_layer.add_child(wall)


func _build_slot_triggers() -> void:
	if slot_definitions.is_empty():
		return
	var slot_count := slot_definitions.size()
	var usable_width: float = max(_board_size.x - board_padding.x * 2.0, 0.0)
	var slot_width: float = usable_width / float(max(slot_count, 1))
	var start_x := board_padding.x
	var y: float = _board_size.y - slot_capture_height * 0.5 - board_bottom_gap
	for i in range(slot_count):
		var slot: Dictionary = slot_definitions[i]
		var slot_id := _resolve_slot_id(slot, i)
		var area := Area2D.new()
		area.collision_layer = LAYER_SLOT
		area.collision_mask = LAYER_BALL
		area.monitoring = true
		area.monitorable = true
		area.position = Vector2(start_x + slot_width * i, y)
		var collider := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(max(slot_width - 12.0, 32.0), slot_capture_height)
		collider.position = Vector2(slot_width * 0.5, 0.0)
		collider.shape = rect
		area.add_child(collider)
		area.body_entered.connect(Callable(self, "_on_slot_area_body_entered").bind(slot_id))
		slot_layer.add_child(area)


func _on_player_state_changed() -> void:
	_refresh_gold_label()
	_refresh_drop_button_state()


func _get_player_resource() -> FW_Player:
	return GDM.player if GDM.player else null


func _get_player_gold() -> int:
	var player := _get_player_resource()
	return player.gold if player else 0


func _can_afford_drop() -> bool:
	if not require_player_gold:
		return true
	return _get_player_gold() >= drop_gold_cost


func _deduct_drop_cost() -> bool:
	if not require_player_gold:
		return true
	var player := _get_player_resource()
	if player == null:
		return false
	if player.gold < drop_gold_cost:
		return false
	player.gold = max(player.gold - drop_gold_cost, 0)
	_refresh_gold_label()
	EventBus.player_state_changed.emit()
	return true


func _refresh_gold_label() -> void:
	if gold_label:
		var gold_text := "Gold: %s" % _get_player_gold()
		if require_player_gold:
			gold_text += "  Drop: %sg" % drop_gold_cost
		gold_label.text = gold_text


func _refresh_drop_button_state() -> void:
	if drop_button:
		drop_button.text = _build_drop_button_label()
		drop_button.disabled = _balls_in_play > 0 or not _can_afford_drop()
		if not _can_afford_drop():
			_set_helper_insufficient_gold()
		elif helper_label and _helper_idle_text != "":
			helper_label.text = _helper_idle_text


func _build_drop_button_label() -> String:
	if require_player_gold:
		return "Drop Ball (%sg)" % drop_gold_cost
	return "Drop Ball"


func _set_helper_insufficient_gold() -> void:
	if helper_label:
		helper_label.text = "Need %s gold to drop" % drop_gold_cost


func _on_drop_button_pressed() -> void:
	if _balls_in_play > 0:
		return
	if require_player_gold and not _deduct_drop_cost():
		_set_helper_insufficient_gold()
		return
	_begin_drop_sequence()
	if SoundManager:
		SoundManager._play_spin_start_sound()


func _begin_drop_sequence() -> void:
	_balls_in_play = balls_per_round
	drop_started.emit()
	_update_status("Ball dropping...")
	#_pulse_board_background()
	_activate_drop_peg_motion()
	_stop_spawn_marker_motion()
	_set_spawn_marker_visible(false)
	_refresh_drop_button_state()
	_spawn_ball_wave()


func _spawn_ball_wave() -> void:
	for i in range(balls_per_round):
		if i > 0:
			await get_tree().create_timer(0.2).timeout
		_spawn_ball_instance()


func _spawn_ball_instance() -> void:
	if not is_instance_valid(ball_layer):
		return
	var ball := RigidBody2D.new()
	ball.collision_layer = LAYER_BALL
	ball.collision_mask = LAYER_PEG | LAYER_SLOT
	ball.gravity_scale = ball_gravity_scale
	ball.physics_material_override = PhysicsMaterial.new()
	ball.physics_material_override.bounce = ball_bounciness
	ball.physics_material_override.friction = ball_friction
	ball.contact_monitor = true
	ball.max_contacts_reported = 8
	ball.freeze = false
	var spawn_origin: Vector2 = spawn_marker.position if spawn_marker else spawn_position
	ball.position = spawn_origin + _random_spawn_scatter()
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ball_radius
	collider.shape = circle
	ball.add_child(collider)
	var sprite := Sprite2D.new()
	sprite.texture = ball_texture
	if sprite.texture:
		var size := sprite.texture.get_size()
		if size != Vector2.ZERO:
			var scale_factor: float = (ball_radius * 2.0) / max(size.x, size.y)
			sprite.scale = Vector2.ONE * scale_factor
	ball.add_child(sprite)
	ball_layer.add_child(ball)
	ball.add_to_group("plinko_ball")
	_apply_spawn_momentum(ball)
	_active_balls.append(ball)
	_register_ball_contact_listeners(ball)
	_register_ball_fail_safe(ball)
	if SoundManager:
		SoundManager._play_sinker_spawn_sound()


func _apply_spawn_momentum(ball: RigidBody2D) -> void:
	if not is_instance_valid(ball):
		return
	if spawn_momentum_inertia <= 0.0:
		return
	var raw_velocity := _spawn_marker_velocity * spawn_momentum_inertia
	var clamped_velocity := clampf(raw_velocity, -spawn_momentum_max_speed, spawn_momentum_max_speed)
	if is_zero_approx(clamped_velocity):
		return
	var current_velocity := ball.linear_velocity
	current_velocity.x = clamped_velocity
	ball.linear_velocity = current_velocity


func _random_spawn_scatter() -> Vector2:
	return Vector2(_rng.randf_range(-spawn_scatter.x, spawn_scatter.x), _rng.randf_range(-spawn_scatter.y, spawn_scatter.y))


func _on_slot_area_body_entered(body: Node, slot_id: String) -> void:
	if body == null or not body.is_in_group("plinko_ball"):
		return
	if body.has_meta("plinko_captured") and body.get_meta("plinko_captured"):
		return
	body.set_meta("plinko_captured", true)
	_active_balls.erase(body)
	if body is RigidBody2D:
		body.queue_free()
	handle_slot_capture(slot_id)


func _pick_weighted_slot() -> Dictionary:
	if slot_definitions.is_empty():
		return {}
	var total_weight := 0.0
	for entry in slot_definitions:
		total_weight += float(entry.get(KEY_WEIGHT, 1.0))
	if total_weight <= 0.0:
		return slot_definitions[0]
	var roll := _rng.randf_range(0.0, total_weight)
	var accumulator := 0.0
	for entry in slot_definitions:
		accumulator += float(entry.get(KEY_WEIGHT, 1.0))
		if roll <= accumulator:
			return entry
	return slot_definitions.back()


func _process_slot_landing(slot: Dictionary) -> void:
	var slot_id := _resolve_slot_id(slot)
	var label := String(slot.get(KEY_LABEL, "Slot"))
	_update_status("Landed in %s" % label)
	var reward: Dictionary = _slot_reward_cache.get(slot_id, _build_reward_payload(slot))
	var reward_copy: Dictionary = reward.duplicate(true)
	reward_copy["slot_id"] = slot_id
	_pending_rewards.append(reward_copy)
	_flash_slot_preview(slot_id)
	_balls_in_play = max(_balls_in_play - 1, 0)
	if _balls_in_play <= 0:
		_finalize_ball_wave()


func handle_slot_capture(slot_id: String) -> void:
	var slot: Dictionary = _find_slot_by_id(slot_id)
	if slot.is_empty():
		printerr("Plinko: Missing slot definition for id %s" % slot_id)
		return
	_process_slot_landing(slot)


func _register_ball_fail_safe(ball: RigidBody2D) -> void:
	await get_tree().create_timer(6.0).timeout
	if not is_instance_valid(ball):
		return
	if not _active_balls.has(ball):
		return
	_active_balls.erase(ball)
	ball.queue_free()
	var fallback_slot := _pick_weighted_slot()
	if fallback_slot.is_empty():
		_reset_after_drop([])
		return
	handle_slot_capture(String(fallback_slot.get(KEY_SLOT_ID, "")))


func _register_ball_contact_listeners(ball: RigidBody2D) -> void:
	if not is_instance_valid(ball):
		return
	var callable := Callable(self, "_on_ball_body_contact").bind(ball)
	if not ball.body_entered.is_connected(callable):
		ball.body_entered.connect(callable)


func _on_ball_body_contact(_other: Node, ball: RigidBody2D) -> void:
	if not is_instance_valid(ball):
		return
	if shader_bounce_duration <= 0.0:
		return
	var cooldown_ms := int(shader_bounce_cooldown * 1000.0)
	var now_ms := Time.get_ticks_msec()
	var last_ms_variant: Variant = ball.get_meta("shader_pulse_ms") if ball.has_meta("shader_pulse_ms") else null
	var last_ms := int(last_ms_variant) if typeof(last_ms_variant) in [TYPE_INT, TYPE_FLOAT] else -cooldown_ms * 2
	if cooldown_ms > 0 and now_ms - last_ms < cooldown_ms:
		return
	ball.set_meta("shader_pulse_ms", now_ms)
	var velocity := ball.linear_velocity.length()
	# Peg / contact hit
	if SoundManager:
		SoundManager._play_peg_hit_sound()
	var strength := clampf(velocity / 320.0, 0.25, 1.2)
	_pulse_shader_for_bounce(strength)


func _find_slot_by_id(slot_id: String) -> Dictionary:
	for slot in slot_definitions:
		if String(slot.get(KEY_SLOT_ID, "")) == slot_id:
			return slot
	return {}


func _finalize_ball_wave() -> void:
	if _pending_rewards.is_empty():
		_reset_after_drop([])
		return
	var resolved: Array = _pending_rewards.duplicate()
	for reward in resolved:
		await _process_reward(reward)
	_pending_rewards.clear()
	_reset_after_drop(resolved)


func _reset_after_drop(resolved_rewards: Array) -> void:
	_balls_in_play = 0
	_stop_board_pulse()
	_cleanup_active_balls()
	_set_spawn_marker_visible(true)
	_start_spawn_marker_motion()
	_activate_idle_peg_motion()
	drop_finished.emit({"rewards": resolved_rewards})
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	if helper_label:
		helper_label.text = _helper_idle_text
	_refresh_drop_button_state()


func _build_reward_payload(slot: Dictionary) -> Dictionary:
	var reward_type := String(slot.get(KEY_REWARD_TYPE, RESULT_TYPE_EQUIPMENT))
	match reward_type:
		RESULT_TYPE_CONSUMABLE:
			return _prepare_consumable_reward(slot)
		RESULT_TYPE_GOLD:
			return _prepare_gold_reward(slot)
		RESULT_TYPE_DEBUFF:
			return _prepare_debuff_reward()
		_:
			return _prepare_equipment_reward(slot)


func _ensure_loot_manager() -> FW_LootManager:
	_loot_manager = FW_MinigameRewardHelper.ensure_loot_manager(_loot_manager)
	return _loot_manager


func _prepare_equipment_reward(slot: Dictionary) -> Dictionary:
	var generator := FW_EquipmentGeneratorV2.new()
	var item: FW_Item = generator.generate_random_equipment()
	var items: Array = []
	if item:
		items.append(item)
	var description := "Found scrap"
	if item:
		description = "Recovered %s" % _item_display_name(item)
	var rarity_color: Color = PREVIEW_COLOR_DEFAULT
	if item and item.has_method("get_rarity_color"):
		rarity_color = item.get_rarity_color(item.rarity)
	var icon_texture: Texture2D = null
	if item:
		icon_texture = item.texture
	var preview_label := "Equipment"
	if item:
		preview_label = _item_display_name(item)
	return {
		"type": RESULT_TYPE_EQUIPMENT,
		"items": items,
		"buffs": [],
		"icon": icon_texture,
		"description": description,
		"metadata": {"slot_label": slot.get(KEY_LABEL, "")},
		"preview_label": preview_label,
		"icon_modulate": rarity_color,
		"detail_color": rarity_color,
	}


func _prepare_consumable_reward(slot: Dictionary) -> Dictionary:
	var manager := _ensure_loot_manager()
	var item: FW_Item = manager.generate_random_consumable()
	var items: Array = []
	if item:
		items.append(item)
	var description := "Empty cache"
	if item:
		description = "Stocked %s" % _item_display_name(item)
	var icon_texture: Texture2D = null
	if item:
		icon_texture = item.texture
	var preview_label := "Consumable"
	if item:
		preview_label = _item_display_name(item)
	return {
		"type": RESULT_TYPE_CONSUMABLE,
		"items": items,
		"buffs": [],
		"icon": icon_texture,
		"description": description,
		"metadata": {"slot_label": slot.get(KEY_LABEL, "")},
		"preview_label": preview_label,
		"icon_modulate": Color.WHITE,
		"detail_color": PREVIEW_COLOR_CONSUMABLE,
	}


func _prepare_gold_reward(slot: Dictionary) -> Dictionary:
	var data: Dictionary = slot.get(KEY_REWARD_DATA, {}) if typeof(slot.get(KEY_REWARD_DATA, {})) == TYPE_DICTIONARY else {}
	var min_gold := int(data.get("min", 25))
	var max_gold := int(data.get("max", max(min_gold, 25)))
	if min_gold > max_gold:
		var tmp := min_gold
		min_gold = max_gold
		max_gold = tmp
	var amount := _rng.randi_range(min_gold, max_gold)
	var manager := _ensure_loot_manager()
	var gold_item: FW_Item = manager.create_gold_item(amount)
	var icon_texture: Texture2D = _resolve_slot_icon(slot, {})
	if gold_item and gold_item.texture:
		icon_texture = gold_item.texture
	var items: Array = []
	if gold_item:
		items.append(gold_item)
	return {
		"type": RESULT_TYPE_GOLD,
		"items": items,
		"buffs": [],
		"icon": icon_texture,
		"description": "Hoarded %s gold" % amount,
		"amount": amount,
		"metadata": {"gold": amount},
		"preview_label": "+%sg" % amount,
		"icon_modulate": PREVIEW_COLOR_GOLD,
		"detail_color": PREVIEW_COLOR_GOLD,
	}


func _prepare_debuff_reward() -> Dictionary:
	if _debuff_queue.is_empty():
		_debuff_queue = _build_debuff_queue()
	var buff: FW_Buff = FW_MinigameRewardHelper.draw_buff_from_queue(_debuff_queue)
	if buff == null:
		return {
			"type": RESULT_TYPE_DEBUFF,
			"items": [],
			"buffs": [],
			"description": "No debuffs configured",
		}
	return {
		"type": RESULT_TYPE_DEBUFF,
		"items": [],
		"buffs": [buff],
		"icon": buff.texture,
		"description": "Hazard suffered: %s" % buff.name,
		"preview_label": buff.name,
		"icon_modulate": PREVIEW_COLOR_DEBUFF,
		"detail_color": PREVIEW_COLOR_DEBUFF,
	}


func _item_display_name(item_variant: Variant) -> String:
	if item_variant == null:
		return "Reward"
	var typed: FW_Item = item_variant if item_variant is FW_Item else null
	if typed == null:
		return String(item_variant)
	if typed.has_method("get_display_name"):
		var custom: Variant = typed.call("get_display_name")
		if typeof(custom) == TYPE_STRING:
			var custom_text := String(custom)
			if custom_text.strip_edges() != "":
				return custom_text
	var display_property: Variant = typed.get("display_name")
	if typeof(display_property) == TYPE_STRING:
		var property_text := String(display_property)
		if property_text.strip_edges() != "":
			return property_text
	var name_text := String(typed.name)
	if name_text.strip_edges() != "":
		return name_text
	var resource_label := String(typed.resource_name)
	if resource_label.strip_edges() != "":
		return resource_label
	return "Reward"



func _build_debuff_queue() -> Array[FW_Buff]:
	return FW_MinigameRewardHelper.build_debuff_queue(debuff_pool)


func _process_reward(result: Dictionary) -> void:
	_apply_reward_effects(result)
	var description := str(result.get("description", "Plinko reward"))
	var items_variant: Variant = result.get("items", [])
	var buffs_variant: Variant = result.get("buffs", [])
	var metadata_variant: Variant = result.get("metadata", {})
	var items: Array = items_variant if typeof(items_variant) == TYPE_ARRAY else []
	var buffs: Array = buffs_variant if typeof(buffs_variant) == TYPE_ARRAY else []
	var metadata: Dictionary = metadata_variant if typeof(metadata_variant) == TYPE_DICTIONARY else {}
	if helper_label and description != "":
		helper_label.text = description
	_play_reward_stinger(result)
	if drop_result_delay > 0.0:
		await get_tree().create_timer(drop_result_delay).timeout
	_present_loot(items, description, buffs, metadata)


func _apply_reward_effects(result: Dictionary) -> void:
	var result_type := String(result.get("type", ""))
	match result_type:
		RESULT_TYPE_GOLD:
			var amount := int(result.get("amount", 0))
			var player := _get_player_resource()
			if player and amount != 0:
				player.gold += amount
				_refresh_gold_label()
				EventBus.player_state_changed.emit()
		RESULT_TYPE_CONSUMABLE, RESULT_TYPE_EQUIPMENT:
			_grant_item_rewards(result)
		RESULT_TYPE_DEBUFF:
			var buffs_variant: Variant = result.get("buffs", [])
			if typeof(buffs_variant) == TYPE_ARRAY:
				for buff in buffs_variant:
					if buff is FW_Buff:
						_queue_debuff(buff)
		_:
			_grant_item_rewards(result)


func _grant_item_rewards(result: Dictionary) -> void:
	var items_variant: Variant = result.get("items", [])
	if typeof(items_variant) != TYPE_ARRAY:
		return
	for item in items_variant:
		if item is FW_Item:
			GDM.add_item_to_player(item)


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
	if metadata.has("gold"):
		return "Gold stash: %s" % metadata.get("gold")
	return "Reward data available"


func _resolve_slot_icon(slot: Dictionary, reward: Dictionary) -> Texture2D:
	var reward_icon: Variant = reward.get("icon", null)
	if reward_icon and reward_icon is Texture2D:
		return reward_icon
	var reward_items: Variant = reward.get("items", [])
	if reward_items is Array:
		for reward_item in reward_items:
			if reward_item is FW_Item and reward_item.texture:
				return reward_item.texture
	var reward_buffs: Variant = reward.get("buffs", [])
	if reward_buffs is Array:
		for reward_buff in reward_buffs:
			if reward_buff is FW_Buff and reward_buff.texture:
				return reward_buff.texture
	var slot_icon: Variant = slot.get(KEY_ICON, null)
	if slot_icon and slot_icon is Texture2D:
		return slot_icon
	var icon_path: Variant = slot.get(KEY_ICON_PATH, "")
	if icon_path is String and icon_path != "" and ResourceLoader.exists(icon_path, "Texture2D"):
		return ResourceLoader.load(icon_path)
	var texture_value: Variant = slot.get(KEY_TEXTURE, null)
	if texture_value and texture_value is Texture2D:
		return texture_value
	return ball_texture


func _queue_debuff(buff: FW_Buff) -> void:
	FW_MinigameRewardHelper.queue_debuff_on_player(buff)


func _play_reward_stinger(result: Dictionary) -> void:
	var result_type := String(result.get("type", ""))
	match result_type:
		RESULT_TYPE_GOLD:
			SoundManager._player_random_money_sound()
		RESULT_TYPE_DEBUFF:
			SoundManager._play_random_negative_sound()
		_:
			SoundManager._play_random_positive_sound()


func _reroll_slot_reward(slot_id: String) -> void:
	if slot_id == "":
		return
	var slot := _find_slot_by_id(slot_id)
	if slot.is_empty():
		return
	_slot_reward_cache[slot_id] = _build_reward_payload(slot)
	_update_slot_preview_entry(slot_id)



func _populate_slot_previews() -> void:
	if not is_instance_valid(slot_preview_container) or slot_definitions.is_empty() or slot_preview_template == null:
		return
	for child in slot_preview_container.get_children():
		if child != slot_preview_template:
			child.queue_free()
	_slot_preview_nodes.clear()
	for slot in slot_definitions:
		var slot_id := _resolve_slot_id(slot)
		if slot_id == "":
			continue
		var preview := slot_preview_template.duplicate()
		preview.visible = true
		preview.name = "SlotPreview_%s" % slot_id
		slot_preview_container.add_child(preview)
		_slot_preview_nodes[slot_id] = preview
		preview.mouse_entered.connect(Callable(self, "_on_slot_preview_hovered").bind(slot_id))
		preview.mouse_exited.connect(Callable(self, "_on_slot_preview_unhovered"))
		_update_slot_preview_entry(slot_id)


func _update_slot_preview_entry(slot_id: String) -> void:
	var preview: Control = _slot_preview_nodes.get(slot_id, null)
	if preview == null:
		return
	var slot: Dictionary = _find_slot_by_id(slot_id)
	var reward: Dictionary = _slot_reward_cache.get(slot_id, {})
	var icon_rect: TextureRect = preview.get_node("PreviewVBox/PreviewIcon")
	var title_label: Label = preview.get_node("PreviewVBox/PreviewTitle")
	var detail_label: Label = preview.get_node("PreviewVBox/PreviewDetail")
	if title_label:
		title_label.visible = false
	if detail_label:
		detail_label.text = _preview_detail_text(reward)
		detail_label.modulate = reward.get("detail_color", PREVIEW_COLOR_DEFAULT)
		detail_label.visible = detail_label.text.strip_edges() != ""
	if icon_rect:
		icon_rect.texture = _resolve_slot_icon(slot, reward)
		icon_rect.modulate = reward.get("icon_modulate", Color.WHITE)
		icon_rect.visible = icon_rect.texture != null


func _preview_detail_text(reward: Dictionary) -> String:
	var preview_label := str(reward.get("preview_label", "")).strip_edges()
	if preview_label != "":
		return preview_label
	var result_type := String(reward.get("type", ""))
	match result_type:
		RESULT_TYPE_GOLD:
			return "+%sg" % reward.get("amount", 0)
		RESULT_TYPE_CONSUMABLE:
			var items: Array = reward.get("items", []) if reward.has("items") else []
			if not items.is_empty():
				return _item_display_name(items[0])
			return "Consumable"
		RESULT_TYPE_EQUIPMENT:
			var equipment: Array = reward.get("items", [])
			if equipment is Array and not equipment.is_empty():
				return _item_display_name(equipment[0])
			return "Equipment"
		RESULT_TYPE_DEBUFF:
			var buffs: Array = reward.get("buffs", [])
			if buffs is Array and not buffs.is_empty():
				return buffs[0].name
			return "Debuff"
		_:
			return "Mystery"


func _flash_slot_preview(slot_id: String) -> void:
	var preview: Control = _slot_preview_nodes.get(slot_id, null)
	if preview == null or slot_preview_flash_duration <= 0.0:
		return
	if _slot_preview_tweens.has(slot_id):
		var tween: Tween = _slot_preview_tweens[slot_id]
		if tween and tween.is_running():
			tween.kill()
	var new_tween := get_tree().create_tween()
	new_tween.tween_property(preview, "scale", Vector2.ONE * 1.08, slot_preview_flash_duration * 0.5)
	new_tween.tween_property(preview, "scale", Vector2.ONE, slot_preview_flash_duration * 0.5)
	_slot_preview_tweens[slot_id] = new_tween


func _on_slot_preview_hovered(slot_id: String) -> void:
	var reward: Dictionary = _slot_reward_cache.get(slot_id, {})
	if helper_label:
		helper_label.text = str(reward.get("description", "Awaiting reward"))


func _on_slot_preview_unhovered() -> void:
	if helper_label:
		helper_label.text = _helper_idle_text


func _resolve_slot_id(slot: Dictionary, fallback_index: int = -1) -> String:
	var slot_id := String(slot.get(KEY_SLOT_ID, ""))
	if slot_id == "" and fallback_index >= 0:
		slot_id = "slot_%d" % fallback_index
	return slot_id


func _cleanup_active_balls() -> void:
	for ball in _active_balls:
		if is_instance_valid(ball):
			ball.queue_free()
	_active_balls.clear()


func _physics_process(delta: float) -> void:
	_update_spawn_marker_velocity(delta)
	_update_peg_motion(delta)


func _update_spawn_marker_velocity(delta: float) -> void:
	if not is_instance_valid(spawn_marker) or delta <= 0.0:
		_spawn_marker_velocity = 0.0
		return
	if is_nan(_previous_spawn_marker_x):
		_previous_spawn_marker_x = spawn_marker.position.x
		_spawn_marker_velocity = 0.0
		return
	var current_x := spawn_marker.position.x
	_spawn_marker_velocity = (current_x - _previous_spawn_marker_x) / delta
	_previous_spawn_marker_x = current_x


func _update_peg_motion(delta: float) -> void:
	if _peg_nodes.is_empty():
		_update_board_background_glow()
		return
	if not peg_motion_enabled or peg_motion_speed <= 0.0:
		_peg_drop_pattern_active = false
		_reset_pegs_to_base()
		_update_board_background_glow()
		return
	_peg_pattern_time += delta * peg_motion_speed
	for i in range(_peg_nodes.size()):
		var peg: StaticBody2D = _peg_nodes[i]
		if not is_instance_valid(peg):
			continue
		var base_pos: Vector2 = _peg_base_positions.get(peg, peg.position)
		peg.position = base_pos + _peg_offset_for_index(i)
	_update_board_background_glow()


func _peg_offset_for_index(index: int) -> Vector2:
	var t := _peg_pattern_time
	var phase := float(index) * 0.28
	match _peg_pattern_id:
		PEG_PATTERN_IDLE:
			var wobble := peg_idle_wobble_distance
			if wobble <= 0.0:
				return Vector2.ZERO
			return Vector2(sin(t + phase) * wobble, sin(t * 0.65 + phase * 0.5) * wobble * 0.6)
		PEG_PATTERN_SWAY_HORIZONTAL:
			return Vector2(sin(t + phase) * peg_motion_sway_distance, 0.0)
		PEG_PATTERN_SWAY_VERTICAL:
			return Vector2(0.0, sin(t + phase) * peg_motion_vertical_distance)
		PEG_PATTERN_ORBIT:
			var radius := peg_motion_orbit_radius
			return Vector2(cos(t + phase), sin(t + phase)) * radius
		PEG_PATTERN_FLOAT_DIAGONAL:
			var sway := peg_motion_sway_distance * 0.75
			return Vector2(sin(t + phase) * sway, cos(t * 0.9 + phase) * sway * 0.6)
		PEG_PATTERN_DRIFT:
			var drift := peg_motion_sway_distance * 0.45
			return Vector2(sin(t * 0.8 + phase) * drift, sin(t * 1.15 + phase * 0.5) * drift)
		_:
			return Vector2.ZERO


func _reset_pegs_to_base() -> void:
	for peg in _peg_nodes:
		if not is_instance_valid(peg):
			continue
		var base_pos: Vector2 = _peg_base_positions.get(peg, peg.position)
		peg.position = base_pos


func _update_board_background_glow() -> void:
	if not is_instance_valid(board_background):
		return
	if board_glow_strength <= 0.0 or not peg_motion_enabled:
		board_background.color = Color(1, 1, 1, 0)
		return
	var pulse := (sin(_peg_pattern_time * 1.2) + 1.0) * 0.5
	var tint := Color(0.28, 0.45, 0.72, 1.0)
	var glow_strength := board_glow_strength
	if not _peg_drop_pattern_active:
		glow_strength *= 0.35
	var lerp_amount := clampf(glow_strength * pulse, 0.0, 1.0)
	var blended := Color(1, 1, 1, 0).lerp(tint, lerp_amount)
	blended.a = clampf(lerp_amount, 0.0, 0.4)
	board_background.color = blended


func _initialize_shader_feedback() -> void:
	if not is_instance_valid(shader_bg):
		return
	_shader_material = shader_bg.material as ShaderMaterial
	if _shader_material == null:
		return
	var contrast_variant: Variant = _shader_material.get_shader_parameter("contrast")
	if typeof(contrast_variant) in [TYPE_FLOAT, TYPE_INT]:
		_shader_base_contrast = float(contrast_variant)
	var spin_variant: Variant = _shader_material.get_shader_parameter("spin_amount")
	if typeof(spin_variant) in [TYPE_FLOAT, TYPE_INT]:
		_shader_base_spin = float(spin_variant)


func _pulse_shader_for_bounce(strength: float) -> void:
	if _shader_material == null:
		return
	if shader_bounce_duration <= 0.0:
		return
	var clamped_strength := clampf(strength, 0.0, 1.5)
	if shader_bounce_contrast_boost > 0.0:
		var contrast_peak := _shader_base_contrast + shader_bounce_contrast_boost * clamped_strength
		_drive_shader_parameter("contrast", contrast_peak, shader_bounce_duration, _shader_base_contrast)
	if shader_bounce_spin_boost > 0.0:
		var spin_peak := _shader_base_spin + shader_bounce_spin_boost * clamped_strength
		_drive_shader_parameter("spin_amount", spin_peak, shader_bounce_duration * 0.8, _shader_base_spin)


func _drive_shader_parameter(param: StringName, peak_value: float, duration: float, base_value: float) -> void:
	if _shader_material == null:
		return
	if duration <= 0.0:
		_set_shader_param_value(base_value, param)
		return
	var current_variant: Variant = _shader_material.get_shader_parameter(param)
	var current_value: float = float(current_variant) if typeof(current_variant) in [TYPE_FLOAT, TYPE_INT] else base_value
	if _shader_param_tweens.has(param):
		var existing: Tween = _shader_param_tweens[param]
		if existing and existing.is_running():
			existing.kill()
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(Callable(self, "_set_shader_param_value").bind(param), current_value, peak_value, duration * 0.35)
	tween.tween_method(Callable(self, "_set_shader_param_value").bind(param), peak_value, base_value, duration * 0.65)
	_shader_param_tweens[param] = tween


func _set_shader_param_value(value: float, param: StringName) -> void:
	if _shader_material == null:
		return
	_shader_material.set_shader_parameter(param, value)


func _pick_random_active_peg_pattern() -> String:
	if PEG_ACTIVE_PATTERNS.is_empty():
		return PEG_PATTERN_STATIC
	var pool: Array = PEG_ACTIVE_PATTERNS.duplicate()
	if pool.size() > 1 and pool.has(_peg_pattern_id):
		pool.erase(_peg_pattern_id)
	var index := _rng.randi_range(0, pool.size() - 1)
	return pool[index]


func _activate_idle_peg_motion() -> void:
	_peg_drop_pattern_active = false
	if not peg_motion_enabled:
		_peg_pattern_id = PEG_PATTERN_STATIC
		_peg_pattern_time = 0.0
		_reset_pegs_to_base()
		_update_board_background_glow()
		return
	_peg_pattern_id = PEG_PATTERN_IDLE
	_peg_pattern_time = 0.0
	_update_board_background_glow()


func _activate_drop_peg_motion() -> void:
	if not peg_motion_enabled:
		_peg_drop_pattern_active = false
		_peg_pattern_id = PEG_PATTERN_STATIC
		_peg_pattern_time = 0.0
		_reset_pegs_to_base()
		_update_board_background_glow()
		return
	_peg_drop_pattern_active = true
	_peg_pattern_id = _pick_random_active_peg_pattern()
	_peg_pattern_time = 0.0
	_update_board_background_glow()


func _autoplay_when_ready() -> void:
	if not drop_button or drop_button.disabled:
		return
	_begin_drop_sequence()


func _update_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _on_loot_screen_back_button() -> void:
	_on_back_button_pressed()


func _on_back_button_pressed() -> void:
	FW_MinigameRewardHelper.mark_minigame_completed(true)
	ScreenRotator.change_scene("res://Scenes/level_select2.tscn")


func _exit_tree() -> void:
	_stop_spawn_marker_motion()
	_stop_board_pulse()
	if EventBus.player_state_changed.is_connected(_on_player_state_changed):
		EventBus.player_state_changed.disconnect(_on_player_state_changed)
