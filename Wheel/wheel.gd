@tool
extends CanvasLayer

signal back_button
signal spin_started
signal spin_finished(result)

const KEY_COLOR := "color"
const KEY_ICON := "icon"
const KEY_VALUE := "value"
const KEY_WEIGHT := "weight"
const KEY_ICON_PATH := "icon_path"
const KEY_RESULT_DATA := "result_data"

const RESULT_TYPE_EQUIPMENT := "equipment"
const RESULT_TYPE_CONSUMABLE := "consumable"
const RESULT_TYPE_GOLD := "gold"
const RESULT_TYPE_DEBUFF := "debuff"

const DEFAULT_DEBUFF_RESOURCES := [
	preload("res://Buffs/Resources/stabbed_debuff.tres"),
	preload("res://Buffs/Resources/poison_debuff.tres"),
	preload("res://Buffs/Resources/hamstrung_debuff.tres"),
	preload("res://Buffs/Resources/discouraged_debuff.tres"),
	preload("res://Buffs/Resources/cursed_luck_debuff.tres"),
	preload("res://Buffs/Resources/clumsy_debuff.tres"),
	preload("res://Buffs/Resources/butterpaws_debuff.tres"),
	preload("res://Buffs/Resources/bruised_debuff.tres"),
	preload("res://Buffs/Resources/fatigued_debuff.tres"),
]

@export var slices: Array[Dictionary] = [
	{
		KEY_COLOR: FW_Colors.bark,
		KEY_VALUE: "stab",
		KEY_ICON: "res://Abilities/Images/Bleed.png",
		KEY_WEIGHT: 1.0,
	},
	{
		KEY_COLOR: FW_Colors.alertness,
		KEY_VALUE: "potion",
		KEY_ICON: "res://Inventory/ConsumableSlot.png",
		KEY_WEIGHT: 1.0,
	},
	{
		KEY_COLOR: FW_Colors.reflex,
		KEY_VALUE: "gold",
		KEY_ICON: "res://Item/Junk/Images/gold_coins.png",
		KEY_WEIGHT: 1.0,
	},
	{
		KEY_COLOR: FW_Colors.vigor,
		KEY_VALUE: "equipment",
		KEY_ICON: "res://Equipment/Images/harness_armor.png",
		KEY_WEIGHT: 1.0,
	},
	{
		KEY_COLOR: FW_Colors.enthusiasm,
		KEY_VALUE: "discouraged",
		KEY_ICON: "res://Buffs/Images/demoralized.png",
		KEY_WEIGHT: 1.0,
	},
]
@export_range(0.5, 10.0, 0.1) var spin_duration := 4.0
@export_range(0.0, 10.0, 0.1) var min_extra_turns := 2.0
@export_range(0.0, 10.0, 0.1) var max_extra_turns := 4.0
@export var wheel_position := Vector2(640, 360)
@export_range(64.0, 1024.0, 1.0, "suffix:px") var radius := 360.0
@export_range(0.0, 1024.0, 1.0, "suffix:px") var icon_radius := 280.0
@export var icon_scale := Vector2.ONE
@export_range(8.0, 256.0, 1.0, "suffix:px") var max_icon_size := 64.0
@export_range(-TAU, TAU, 0.01, "radians") var pointer_angle_radians := -PI * 0.5
@export var show_pointer := true
@export var pointer_color := Color.YELLOW
@export_range(20.0, 200.0, 1.0, "suffix:px") var pointer_size := 60.0
@export_range(0.0, 200.0, 1.0, "suffix:px") var pointer_offset := 20.0
@export var highlight_modulate := Color(1.25, 1.25, 1.25, 1.0)
@export_range(0.05, 2.0, 0.05) var highlight_duration := 0.4
@export var spin_transition := Tween.TRANS_QUART
@export var spin_ease := Tween.EASE_OUT

@export var loot_prefab: PackedScene
@export_range(1, 100000, 1) var min_gold_reward := 100
@export_range(1, 100000, 1) var max_gold_reward := 200
@export var debuff_pool: Array[FW_Buff] = []
@export var buff_tooltip_scene: PackedScene = preload("res://Buffs/FW_BuffViewerPrefab.tscn")
@export var tooltip_offset := Vector2(24, 24)

@onready var roll_button: Button = %roll_button
@onready var wheel_root: Node2D = %WheelRoot
@onready var pointer_root: Node2D = %PointerRoot
@onready var vendor_image: TextureRect = %VendorImage
@onready var vendor_name: Label = %vendor_name
@onready var vendor_label: RichTextLabel = %VendorLabel
@onready var loot_screen: Node = %LootScreen
@onready var tooltip_layer: Control = %TooltipLayer

var _slice_cache: Array = []
var _is_spinning := false
var _active_spin_tween: Tween
var _highlight_tween: Tween
var _reported_missing_icons := {}
var _pointer_node: Polygon2D = null
var _loot_manager: FW_LootManager
var _rng := RandomNumberGenerator.new()
var _item_tooltip_panel: Control
var _buff_tooltip_panel: Control
var _active_tooltip_slice: Dictionary = {}
var prize_wheel_id: int = 0

func _ready() -> void:
	_rng.randomize()
	if debuff_pool.is_empty():
		debuff_pool = _build_default_debuff_pool()
	set_process_unhandled_input(true)
	if is_instance_valid(tooltip_layer):
		tooltip_layer.z_as_relative = false
		tooltip_layer.z_index = 1000
	SoundManager.wire_up_all_buttons()
	var c = ResourceLoader.load("res://Characters/PrizeWheelWorker_BartlebyHiggins.tres")
	setup(c)
	if roll_button:
		roll_button.pressed.connect(_on_roll_button_pressed)

	if loot_screen and loot_screen.has_signal("back_button"):
		loot_screen.back_button.connect(_on_loot_screen_back_button)

	if GDM.current_prize_wheel_hash != 0:
		setup_prize_wheel(GDM.current_prize_wheel_hash)
		GDM.current_prize_wheel_hash = 0

	_ensure_turn_order()
	_apply_wheel_position()
	_build_wheel()

func setup_prize_wheel(id: int) -> void:
	prize_wheel_id = id

func _on_loot_screen_back_button() -> void:
	ScreenRotator.change_scene("res://WorldMap/world_map.tscn")

func setup(character: FW_Character) -> void:
	vendor_image.texture = character.texture
	vendor_name.text = character.name
	vendor_label.text = character.description

func _notification(what: int) -> void:
	if Engine.is_editor_hint() and what == NOTIFICATION_ENTER_TREE:
		_apply_wheel_position()


func _set(property: StringName, _value) -> bool:
	if Engine.is_editor_hint():
		match property:
			&"slices", &"radius", &"icon_radius", &"icon_scale", &"pointer_angle_radians", &"wheel_position", &"min_extra_turns", &"max_extra_turns", &"max_icon_size", &"show_pointer", &"pointer_color", &"pointer_size", &"pointer_offset", &"min_gold_reward", &"max_gold_reward", &"debuff_pool", &"tooltip_offset":
				call_deferred("_editor_refresh")
			_:
				pass
	return false


func _editor_refresh() -> void:
	_ensure_turn_order()
	_apply_wheel_position()
	_build_wheel()


func _apply_wheel_position() -> void:
	if is_instance_valid(wheel_root):
		wheel_root.position = wheel_position
	if is_instance_valid(pointer_root):
		pointer_root.position = wheel_position


func _ensure_turn_order() -> void:
	if min_extra_turns > max_extra_turns:
		var temp := min_extra_turns
		min_extra_turns = max_extra_turns
		max_extra_turns = temp
	if max_extra_turns <= min_extra_turns:
		max_extra_turns = min_extra_turns + 0.5
	_ensure_reward_bounds()

func _ensure_reward_bounds() -> void:
	if min_gold_reward > max_gold_reward:
		var temp := min_gold_reward
		min_gold_reward = max_gold_reward
		max_gold_reward = temp

func _build_default_debuff_pool() -> Array[FW_Buff]:
	var defaults: Array[FW_Buff] = []
	for resource in DEFAULT_DEBUFF_RESOURCES:
		if resource is FW_Buff:
			defaults.append(resource)
	return defaults


func _resolve_slice_icon(entry: Dictionary) -> Texture2D:
	var icon_value: Variant = entry.get(KEY_ICON, null)
	if icon_value is Texture2D:
		return icon_value
	if icon_value is Resource and icon_value is Texture2D:
		return icon_value
	var icon_path: Variant = entry.get(KEY_ICON_PATH, "")
	if icon_path is String and icon_path != "":
		if ResourceLoader.exists(icon_path, "Texture2D"):
			var loaded := ResourceLoader.load(icon_path, "Texture2D")
			if loaded is Texture2D:
				entry[KEY_ICON] = loaded
				return loaded
		elif not _reported_missing_icons.has(icon_path):
			_reported_missing_icons[icon_path] = true
	if icon_value is String and icon_value != "":
		if ResourceLoader.exists(icon_value, "Texture2D"):
			var loaded_from_icon := ResourceLoader.load(icon_value, "Texture2D")
			if loaded_from_icon is Texture2D:
				entry[KEY_ICON] = loaded_from_icon
				return loaded_from_icon
		elif not _reported_missing_icons.has(icon_value):
			_reported_missing_icons[icon_value] = true
	return null

func _prepare_slice_rewards() -> void:
	if Engine.is_editor_hint():
		return
	if slices.is_empty():
		return
	var debuff_queue := _build_debuff_queue()
	for idx in range(slices.size()):
		var entry := slices[idx]
		if typeof(entry) != TYPE_DICTIONARY:
			entry = {}
		var value := String(entry.get(KEY_VALUE, ""))
		var reward := {}
		match value:
			"equipment":
				reward = _prepare_equipment_reward()
			"potion":
				reward = _prepare_consumable_reward()
			"gold":
				reward = _prepare_gold_reward()
			_:
				if value == "stab" or value == "discouraged":
					reward = _prepare_debuff_reward(debuff_queue)
		if reward.is_empty():
			entry.erase(KEY_RESULT_DATA)
		else:
			entry[KEY_RESULT_DATA] = reward
			var reward_icon: Texture2D = reward.get("icon", null)
			if reward_icon:
				entry[KEY_ICON] = reward_icon
		slices[idx] = entry

func _build_debuff_queue() -> Array:
	var pool: Array[FW_Buff] = []
	for debuff in debuff_pool:
		if debuff and debuff is FW_Buff:
			pool.append(debuff)
	if pool.is_empty():
		for fallback in DEFAULT_DEBUFF_RESOURCES:
			if fallback is FW_Buff:
				pool.append(fallback)
	if pool.is_empty():
		return []
	var queue: Array = []
	for entry in pool:
		queue.append(entry)
	queue.shuffle()
	return queue

func _ensure_loot_manager() -> FW_LootManager:
	if _loot_manager == null:
		_loot_manager = FW_LootManager.new()
	return _loot_manager

func _prepare_equipment_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var equipment: FW_Item = manager.sweet_loot()
	if equipment == null:
		return {}
	var icon: Texture2D = equipment.texture
	return {
		"type": RESULT_TYPE_EQUIPMENT,
		"item": equipment,
		"icon": icon,
		"description": "You obtained %s" % equipment.name,
	}

func _prepare_consumable_reward() -> Dictionary:
	var manager := _ensure_loot_manager()
	var consumable: FW_Item = manager.generate_random_consumable()
	if consumable == null:
		return {}
	var icon: Texture2D = consumable.texture
	return {
		"type": RESULT_TYPE_CONSUMABLE,
		"item": consumable,
		"icon": icon,
		"description": "You received %s" % consumable.name,
	}

func _prepare_gold_reward() -> Dictionary:
	if max_gold_reward <= 0:
		return {}
	var manager := _ensure_loot_manager()
	var amount := _rng.randi_range(min_gold_reward, max_gold_reward)
	var gold_item: FW_Item = manager.create_gold_item(amount)
	if gold_item == null:
		return {}
	gold_item.name = "%d gp" % amount
	if gold_item.flavor_text == null or gold_item.flavor_text.strip_edges() == "":
		gold_item.flavor_text = "A tidy sack of %d gold coins." % amount
	var icon: Texture2D = gold_item.texture
	return {
		"type": RESULT_TYPE_GOLD,
		"item": gold_item,
		"amount": amount,
		"icon": icon,
		"description": "You scoop up %d gold coins" % amount,
	}

func _prepare_debuff_reward(debuff_queue: Array) -> Dictionary:
	if debuff_queue.is_empty():
		debuff_queue.append_array(_build_debuff_queue())
	if debuff_queue.is_empty():
		return {}
	var template: FW_Buff = debuff_queue[0]
	debuff_queue.remove_at(0)
	if template == null:
		return {}
	var buff: FW_Buff = template.duplicate(true)
	if buff.duration > 0 and buff.duration_left <= 0:
		buff.duration_left = buff.duration
	buff.owner_type = "player"
	var icon: Texture2D = buff.texture
	return {
		"type": RESULT_TYPE_DEBUFF,
		"buff": buff,
		"icon": icon,
		"description": "Afflicted with %s" % buff.name,
	}


func rebuild_wheel() -> void:
	_build_wheel()


func _clear_children(node: Node) -> void:
	if not is_instance_valid(node):
		return
	for child in node.get_children():
		child.queue_free()


func _calculate_alignment_rotation(slice_mid_angle: float) -> float:
	var base_rotation := pointer_angle_radians - slice_mid_angle
	var rotations_needed: float = ceil((wheel_root.rotation - base_rotation) / TAU)
	if rotations_needed < 0.0:
		rotations_needed = 0.0
	var aligned_rotation: float = base_rotation + rotations_needed * TAU
	while aligned_rotation <= wheel_root.rotation:
		aligned_rotation += TAU
	return aligned_rotation


func _pick_extra_turns_count() -> int:
	var min_turns_int := int(ceil(min_extra_turns))
	var max_turns_int := int(floor(max_extra_turns))
	if max_turns_int < min_turns_int:
		max_turns_int = min_turns_int
	if max_turns_int <= 0:
		return 0
	var choice := randi_range(min_turns_int, max_turns_int)
	return choice


func _make_slice_polygon(start_angle: float, span_angle: float, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.antialiased = true
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	points.append(Vector2.RIGHT.rotated(start_angle) * radius)
	points.append(Vector2.RIGHT.rotated(start_angle + span_angle) * radius)
	polygon.polygon = points
	polygon.color = color
	return polygon


func _make_slice_icon(texture: Texture2D, angle: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.z_index = 1
	sprite.position = Vector2.RIGHT.rotated(angle) * icon_radius
	var texture_size := texture.get_size()
	var scale_factor := 1.0
	if texture_size.x > max_icon_size or texture_size.y > max_icon_size:
		var x_scale: float = max_icon_size / max(texture_size.x, 1.0)
		var y_scale: float = max_icon_size / max(texture_size.y, 1.0)
		scale_factor = min(x_scale, y_scale)
	sprite.scale = icon_scale * scale_factor
	sprite.modulate = Color.WHITE
	return sprite


func _build_wheel() -> void:
	if not is_instance_valid(wheel_root):
		return
	_clear_children(wheel_root)
	_slice_cache.clear()
	_reported_missing_icons.clear()
	_hide_tooltip()
	if not Engine.is_editor_hint():
		_prepare_slice_rewards()
	if slices.is_empty():
		return
	var slice_count := slices.size()
	if slice_count == 0:
		return
	var slice_angle := TAU / float(slice_count)
	var current_angle := 0.0
	for idx in range(slice_count):
		var entry := slices[idx]
		if typeof(entry) != TYPE_DICTIONARY:
			entry = {}
		var slice = entry.duplicate(true)
		var base_color: Color = entry.get(KEY_COLOR, Color.from_hsv(float(idx) / slice_count, 0.8, 0.95))
		var weight := float(entry.get(KEY_WEIGHT, 1.0))
		if weight <= 0.0:
			weight = 0.01
		var polygon := _make_slice_polygon(current_angle, slice_angle, base_color)
		wheel_root.add_child(polygon)
		var icon_node: CanvasItem = null
		var icon_texture := _resolve_slice_icon(entry)
		if icon_texture:
			var sprite := _make_slice_icon(icon_texture, current_angle + slice_angle * 0.5)
			sprite.visible = true
			wheel_root.add_child(sprite)
			icon_node = sprite
			var result_icon_variant: Variant = entry.get(KEY_RESULT_DATA, {}).get("icon", null)
			if result_icon_variant and result_icon_variant is Texture2D:
				var result_icon := result_icon_variant as Texture2D
				(sprite as Sprite2D).texture = result_icon
		var mid_angle := current_angle + slice_angle * 0.5
		var result_payload: Dictionary = slice.get(KEY_RESULT_DATA, {})
		var slice_info := {
			"mid_angle": mid_angle,
			"weight": weight,
			"data": entry,
			"polygon": polygon,
			"icon_node": icon_node,
			"base_color": base_color,
			"index": idx,
			"result": result_payload,
		}
		_slice_cache.append(slice_info)
		current_angle += slice_angle
	_clear_highlight()
	_build_pointer()


func _build_pointer() -> void:
	if _pointer_node and is_instance_valid(_pointer_node):
		_pointer_node.queue_free()
		_pointer_node = null
	if not show_pointer:
		return
	if not is_instance_valid(pointer_root):
		return
	_pointer_node = Polygon2D.new()
	_pointer_node.antialiased = true
	_pointer_node.color = pointer_color
	_pointer_node.z_index = 10
	var pointer_tip := Vector2.RIGHT.rotated(pointer_angle_radians) * radius
	var pointer_base := Vector2.RIGHT.rotated(pointer_angle_radians) * (radius + pointer_offset + pointer_size)
	var perpendicular := Vector2.RIGHT.rotated(pointer_angle_radians + PI * 0.5)
	var pointer_base_offset := pointer_size * 0.5
	var pointer_base_left := pointer_base + perpendicular * pointer_base_offset
	var pointer_base_right := pointer_base - perpendicular * pointer_base_offset
	var points := PackedVector2Array()
	points.append(pointer_tip)
	points.append(pointer_base_left)
	points.append(pointer_base_right)
	_pointer_node.polygon = points
	pointer_root.add_child(_pointer_node)

func _show_tooltip_for_slice(slice_info: Dictionary) -> void:
	if Engine.is_editor_hint():
		return
	_ensure_tooltip_instances()
	if not is_instance_valid(tooltip_layer):
		return
	var result: Dictionary = slice_info.get("result", {})
	if result.is_empty():
		return
	_active_tooltip_slice = slice_info
	var result_type := String(result.get("type", ""))
	var mouse_position := get_viewport().get_mouse_position()
	var any_visible := false
	if result_type == RESULT_TYPE_DEBUFF:
		var buff: FW_Buff = result.get("buff", null)
		if buff and _buff_tooltip_panel:
			if _buff_tooltip_panel.has_method("setup"):
				var template_vars := _build_buff_template_vars()
				_buff_tooltip_panel.call("setup", buff, template_vars)
			_buff_tooltip_panel.visible = true
			any_visible = true
		if _item_tooltip_panel:
			_item_tooltip_panel.visible = false
	else:
		var item: FW_Item = result.get("item", null)
		if item and _item_tooltip_panel:
			if _item_tooltip_panel.has_method("populate_fields"):
				_item_tooltip_panel.call("populate_fields", item)
			_item_tooltip_panel.visible = true
			any_visible = true
		if _buff_tooltip_panel:
			_buff_tooltip_panel.visible = false
	if any_visible:
		tooltip_layer.visible = true
		_update_tooltip_position(mouse_position)
	else:
		_hide_tooltip()

func _hide_tooltip() -> void:
	_active_tooltip_slice = {}
	if _item_tooltip_panel:
		_item_tooltip_panel.visible = false
	if _buff_tooltip_panel:
		_buff_tooltip_panel.visible = false
	if is_instance_valid(tooltip_layer):
		tooltip_layer.visible = false

func _ensure_tooltip_instances() -> void:
	if is_instance_valid(tooltip_layer):
		if _item_tooltip_panel == null and loot_prefab:
			var loot_panel := loot_prefab.instantiate()
			if loot_panel is Control:
				var loot_control := loot_panel as Control
				loot_control.visible = false
				loot_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
				loot_control.z_as_relative = false
				loot_control.z_index = 1001
				tooltip_layer.add_child(loot_control)
				_item_tooltip_panel = loot_control
		if _buff_tooltip_panel == null and buff_tooltip_scene:
			var buff_panel := buff_tooltip_scene.instantiate()
			if buff_panel is Control:
				var buff_control := buff_panel as Control
				buff_control.visible = false
				buff_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
				buff_control.z_as_relative = false
				buff_control.z_index = 1001
				tooltip_layer.add_child(buff_control)
				_buff_tooltip_panel = buff_control

func _update_tooltip_position(mouse_position: Vector2) -> void:
	if not is_instance_valid(tooltip_layer):
		return
	if not tooltip_layer.visible:
		return
	if _item_tooltip_panel and _item_tooltip_panel.visible:
		_position_panel(_item_tooltip_panel, mouse_position)
	if _buff_tooltip_panel and _buff_tooltip_panel.visible:
		_position_panel(_buff_tooltip_panel, mouse_position)

func _position_panel(panel: Control, mouse_position: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := panel.size
	if panel_size == Vector2.ZERO:
		panel_size = panel.get_combined_minimum_size()
	var target_position := mouse_position + tooltip_offset
	var max_x: float = float(max(0.0, viewport_size.x - panel_size.x))
	var max_y: float = float(max(0.0, viewport_size.y - panel_size.y))
	target_position.x = clamp(target_position.x, 0.0, max_x)
	target_position.y = clamp(target_position.y, 0.0, max_y)
	panel.position = target_position

func _build_buff_template_vars() -> Dictionary:
	var target_name := "Player"
	if GDM.player and GDM.player.character and GDM.player.character.name:
		target_name = GDM.player.character.name
	return {"target": target_name}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _is_spinning:
			return
		var hovered_slice := _get_slice_under_position(event.position)
		if hovered_slice.is_empty():
			if not _active_tooltip_slice.is_empty():
				_hide_tooltip()
			return
		var current_icon: CanvasItem = hovered_slice.get("icon_node")
		var active_icon: CanvasItem = null
		if not _active_tooltip_slice.is_empty():
			active_icon = _active_tooltip_slice.get("icon_node")
		if current_icon != active_icon:
			_show_tooltip_for_slice(hovered_slice)
		elif is_instance_valid(tooltip_layer) and tooltip_layer.visible:
			_update_tooltip_position(event.position)

func _get_slice_under_position(position: Vector2) -> Dictionary:
	for slice_info in _slice_cache:
		var icon_node: CanvasItem = slice_info.get("icon_node")
		if not is_instance_valid(icon_node):
			continue
		if not icon_node.visible:
			continue
		if icon_node is Sprite2D:
			var sprite := icon_node as Sprite2D
			var local_pos := sprite.to_local(position)
			var rect := sprite.get_rect()
			if rect.has_point(local_pos):
				return slice_info
	return {}


func start_spin(force_index: int = -1) -> void:
	if Engine.is_editor_hint():
		return
	_hide_tooltip()
	if _is_spinning:
		return
	if slices.is_empty():
		return
	if _slice_cache.is_empty():
		_build_wheel()
		if _slice_cache.is_empty():
			return
	var index := force_index
	if index < 0 or index >= _slice_cache.size():
		index = _pick_weighted_index()
	var slice_info: Dictionary = _slice_cache[index]
	_is_spinning = true
	if roll_button:
		roll_button.disabled = true
	emit_signal("spin_started")
	_kill_active_tweens()
	_clear_highlight()
	var target_slice_mid_angle: float = slice_info.get("mid_angle", 0.0)

	var aligned_rotation := _calculate_alignment_rotation(target_slice_mid_angle)
	var extra_turns_count := _pick_extra_turns_count()
	var target_rotation: float = aligned_rotation + float(extra_turns_count) * TAU

	_active_spin_tween = get_tree().create_tween()
	_active_spin_tween.set_trans(spin_transition)
	_active_spin_tween.set_ease(spin_ease)
	_active_spin_tween.tween_property(wheel_root, "rotation", target_rotation, spin_duration)
	_active_spin_tween.finished.connect(func() -> void:
		_is_spinning = false
		if roll_button:
			roll_button.disabled = false
		_highlight_slice(slice_info)
		emit_signal("spin_finished", slice_info)
		_active_spin_tween = null
	)


func force_spin(index: int) -> void:
	start_spin(index)


func _pick_weighted_index() -> int:
	if _slice_cache.is_empty():
		return 0
	var total_weight := 0.0
	for slice_info in _slice_cache:
		total_weight += float(slice_info.get("weight", 1.0))
	if total_weight <= 0.0:
		return 0
	var roll := randf() * total_weight
	for slice_info in _slice_cache:
		roll -= float(slice_info.get("weight", 1.0))
		if roll <= 0.0:
			return int(slice_info.get("index", 0))
	return int(_slice_cache.back().get("index", _slice_cache.size() - 1))


func _get_slice_at_pointer() -> Dictionary:
	if _slice_cache.is_empty():
		return {}
	var slice_count := _slice_cache.size()
	var current_wheel_rotation := fposmod(wheel_root.rotation, TAU)
	for slice_info in _slice_cache:
		var slice_mid_angle: float = slice_info.get("mid_angle", 0.0)
		var slice_world_angle := fposmod(slice_mid_angle + current_wheel_rotation, TAU)
		var pointer_norm := fposmod(pointer_angle_radians, TAU)
		var slice_angle := TAU / float(slice_count)
		var half_slice := slice_angle * 0.5
		var angle_diff: float = abs(slice_world_angle - pointer_norm)
		if angle_diff > PI:
			angle_diff = TAU - angle_diff
		if angle_diff <= half_slice:
			return slice_info
	return {}


func _highlight_slice(slice_info: Dictionary) -> void:
	_clear_highlight()
	var polygon: Polygon2D = slice_info.get("polygon")
	if not is_instance_valid(polygon):
		return
	var icon_node: CanvasItem = slice_info.get("icon_node")
	_kill_highlight_tween()
	_highlight_tween = get_tree().create_tween()
	_highlight_tween.set_trans(Tween.TRANS_SINE)
	_highlight_tween.set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(polygon, "modulate", highlight_modulate, highlight_duration * 0.5)
	if is_instance_valid(icon_node):
		_highlight_tween.parallel().tween_property(icon_node, "modulate", highlight_modulate, highlight_duration * 0.5)
	_highlight_tween.tween_property(polygon, "modulate", Color.WHITE, highlight_duration * 0.5)
	if is_instance_valid(icon_node):
		_highlight_tween.parallel().tween_property(icon_node, "modulate", Color.WHITE, highlight_duration * 0.5)


func _clear_highlight() -> void:
	for slice_info in _slice_cache:
		var polygon: Polygon2D = slice_info.get("polygon")
		if is_instance_valid(polygon):
			polygon.modulate = Color.WHITE
		var icon_node: CanvasItem = slice_info.get("icon_node")
		if is_instance_valid(icon_node):
			icon_node.modulate = Color.WHITE


func _kill_active_tweens() -> void:
	if _active_spin_tween and _active_spin_tween.is_running():
		_active_spin_tween.kill()
	_active_spin_tween = null
	_kill_highlight_tween()


func _kill_highlight_tween() -> void:
	if _highlight_tween and _highlight_tween.is_running():
		_highlight_tween.kill()
	_highlight_tween = null


func _exit_tree() -> void:
	_kill_active_tweens()
	_hide_tooltip()


func _on_roll_button_pressed() -> void:
	start_spin()


func _on_back_button_pressed() -> void:
	ScreenRotator.change_scene("res://WorldMap/world_map.tscn")


func _on_spin_finished(result: Variant) -> void:
	if prize_wheel_id != 0:
		GDM.world_state.mark_prize_wheel_collected(prize_wheel_id)
		GDM.vs_save()
	var result_data: Dictionary = result.get("result", {})
	if result_data.is_empty():
		FW_Debug.debug_log(["wheel spin finished without reward payload", result])
		return
	_present_spin_result(result_data)

func _present_spin_result(result_data: Dictionary) -> void:
	var result_type := String(result_data.get("type", ""))
	match result_type:
		RESULT_TYPE_GOLD:
			var amount = result_data.get("amount", 0)
			GDM.player.gold += amount
			var item: FW_Item = result_data.get("item", null)
			if item:
				_present_item_reward(item, result_data.get("description", ""))
			else:
				FW_Debug.debug_log(["wheel result missing item payload", result_data])
		RESULT_TYPE_CONSUMABLE:
			var item: FW_Item = result_data.get("item", null)
			if item:
				GDM.add_item_to_player(item)
				_present_item_reward(item, result_data.get("description", ""))
			else:
				FW_Debug.debug_log(["wheel result missing item payload", result_data])
		RESULT_TYPE_EQUIPMENT:
			var item: FW_Item = result_data.get("item", null)
			if item:
				GDM.add_item_to_player(item)
				_present_item_reward(item, result_data.get("description", ""))
			else:
				FW_Debug.debug_log(["wheel result missing item payload", result_data])
		RESULT_TYPE_DEBUFF:
			var buff: FW_Buff = result_data.get("buff", null)
			if buff:
				_present_debuff_reward(buff, result_data.get("description", ""))
			else:
				FW_Debug.debug_log(["wheel result missing buff payload", result_data])
		_:
			FW_Debug.debug_log(["wheel encountered unknown result type", result_type, result_data])

func _present_item_reward(item: FW_Item, message: String) -> void:
	if not is_instance_valid(loot_screen):
		return
	if loot_screen.has_method("show_single_loot"):
		loot_screen.call("show_single_loot", item)
	var trimmed := String(message).strip_edges()
	if trimmed != "" and loot_screen.has_method("show_text"):
		loot_screen.call("show_text", trimmed)
	if loot_screen.has_method("slide_in"):
		loot_screen.call("slide_in")

func _present_debuff_reward(buff: FW_Buff, message: String) -> void:
	_queue_debuff(buff)
	if not is_instance_valid(loot_screen):
		return
	if loot_screen.has_method("show_buffs"):
		loot_screen.call("show_buffs", [buff])
	var trimmed := String(message).strip_edges()
	if trimmed != "" and loot_screen.has_method("show_text"):
		loot_screen.call("show_text", trimmed)
	if loot_screen.has_method("slide_in"):
		loot_screen.call("slide_in")

func _queue_debuff(buff: FW_Buff) -> void:
	if buff == null:
		return
	var pending: Array = []
	if GDM.has_meta("pending_combat_buffs"):
		var existing = GDM.get_meta("pending_combat_buffs")
		if existing is Array:
			pending = existing.duplicate()
	if pending.is_empty():
		pending = []
	pending.append(buff)
	GDM.set_meta("pending_combat_buffs", pending)
