extends "res://Scripts/base_menu_panel.gd"

signal back_button_pressed

@export var tooltip_prefab: PackedScene
@export var floating_numbers_prefab: PackedScene
@export var tooltip_root: CanvasItem

const TOOLTIP_WIDTH := 350.0
const TOOLTIP_MARGIN := 20.0
const TRANSMOG_SLOT_COUNT := 5
#const TRANSMOG_SLOT_SCRIPT := preload("res://Transmogrify/FW_TransmogInventorySlot.gd")
const INVENTORY_GRID_SCRIPT := preload("res://UI/InventoryGrid/inventory_grid.gd")
const SWIRL_EFFECT_SCENE := preload("res://Transmogrify/FW_TransmogSwirlEffect.tscn")
const TRANSMOG_COSTS := {
	2: 500,
	3: 1000,
	4: 1500,
	5: 2000,
}
const TRANSMOG_FAILURE_THRESHOLD := 35
const TRANSMOG_SUCCESS_THRESHOLD := 65
const TRANSMOG_CRIT_FAILURE_THRESHOLD := 10
const TRANSMOG_CRIT_SUCCESS_THRESHOLD := 90
const TRANSMOG_NAME_SUFFIX := " of Transmogrification"
const TRANSMOG_FLAVOR_APPEND := "\nTempered by the art of transmogrification."

var tooltip_timer: Timer

@onready var back_button: TextureButton = %back_button

@onready var dice_viewport: SubViewport = %dice_viewport
@onready var viewport_display: TextureRect = %viewport_display

@onready var roll_gear_button: Button = %roll_gear_button

@onready var transmog_items: GridContainer = %transmog_items

@onready var vendor_image: TextureRect = %VendorImage
@onready var vendor_label: RichTextLabel = %VendorLabel
@onready var vendor_name: Label = %vendor_name
@onready var player_gold: Label = %player_gold
@onready var luck_value_label: Label = %luck_value_label

@onready var inventory_node: GridContainer = %inventory
@onready var roll_result_label: Label = %roll_result_label
@onready var luck_modifier_label: Label = %luck_modifier_label
@onready var final_result_label: Label = %final_result_label
@onready var loot_screen: CanvasLayer = $CanvasLayer/LootScreen

var transmog_slots: Array[FW_InventorySlot] = []
const INVENTORY_ALLOWED_TYPES := [FW_Item.ITEM_TYPE.EQUIPMENT]
var inventory_grid
const ROLL_FOR_TRANSMOG := "transmog"
const DIE_TYPE_ONES := 0
const DIE_TYPE_TENS := 1
var dice_results := {}
var dice_nodes: Array = []
var pending_selection: Array[FW_Item] = []
var pending_cost: int = 0
var is_waiting_for_roll: bool = false
var last_roll_value: int = 0
var luck_modifier_amount: int = 0
var final_roll_value: int = 0
var roll_label_origin: Vector2
var luck_label_origin: Vector2
var final_label_origin: Vector2
var roll_result_color: Color = Color.WHITE
var luck_modifier_color: Color = Color.WHITE
var final_result_color: Color = Color.WHITE
var loot_manager := FW_LootManager.new()
var equipment_config := FW_EquipmentConfig.new()

func _ready() -> void:
	viewport_display.texture = dice_viewport.get_texture()
	dice_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_init_tooltip_support()
	if not EventBus.gain_gold.is_connected(_on_gain_gold):
		EventBus.gain_gold.connect(_on_gain_gold)
	if not is_connected("slide_in_started", Callable(self, "_on_panel_slide_in")):
		connect("slide_in_started", Callable(self, "_on_panel_slide_in"))
	var c = ResourceLoader.load("res://Characters/MagicShop_ElizabethFirerose.tres")
	setup(c)
	#slide_in()
	_update_roll_button()
	EventBus.hide_dice.connect(hide_dice_viewport)
	EventBus.show_dice.connect(show_dice_viewport)
	dice_results.clear()
	roll_label_origin = roll_result_label.position
	luck_label_origin = luck_modifier_label.position
	final_label_origin = final_result_label.position
	roll_result_color = roll_result_label.modulate
	luck_modifier_color = luck_modifier_label.modulate
	final_result_color = final_result_label.modulate
	_reset_result_labels()
	_connect_dice_signals()
	if not is_instance_valid(loot_screen):
		var canvas_layer := get_node_or_null("CanvasLayer")
		if canvas_layer and canvas_layer.has_node("LootScreen"):
			loot_screen = canvas_layer.get_node("LootScreen")
		else:
			FW_Debug.debug_log(["[Transmogrify] Fallback lookup failed - no LootScreen under CanvasLayer"])
	if is_instance_valid(loot_screen) and not loot_screen.back_button.is_connected(_on_transmog_loot_back_pressed):
		loot_screen.back_button.connect(_on_transmog_loot_back_pressed)
	_set_back_button_enabled(true)

func _init_tooltip_support() -> void:
	if tooltip_root:
		tooltip_root.hide()
	if not tooltip_timer:
		tooltip_timer = Timer.new()
		tooltip_timer.wait_time = 15.0
		tooltip_timer.one_shot = true
		tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
		add_child(tooltip_timer)

func setup(character: FW_Character) -> void:
	vendor_image.texture = character.texture
	vendor_name.text = character.name
	vendor_label.text = character.description
	luck_value_label.text = str(int(GDM.player.stats.luck))
	luck_value_label.modulate = Color.WEB_GREEN
	luck_modifier_amount = int(GDM.player.stats.luck)
	_update_result_labels_text()
	_update_gold_display()

func setup_transmog_slots() -> void:
	for child in transmog_items.get_children():
		child.queue_free()
	transmog_slots.clear()
	for i in TRANSMOG_SLOT_COUNT:
		var slot:= FW_TransmogInventorySlot.new()
		slot.init(GDM.inventory_item_size, [FW_Item.ITEM_TYPE.EQUIPMENT], i)
		transmog_items.add_child(slot)
		transmog_slots.append(slot)
		if slot is FW_TransmogInventorySlot:
			slot.slot_changed.connect(_on_transmog_slot_changed)

func load_gear() -> void:
	if inventory_grid and is_instance_valid(inventory_grid):
		inventory_grid.refresh_from_player()

func _on_item_mouse_entered(item: FW_InventoryItem) -> void:
	FW_Debug.debug_log(["DEBUG: _on_item_mouse_entered called for item: ", item.data.name if item and item.data else "null"])
	# Null safety check
	if not item or not item.data:
		FW_Debug.debug_log(["DEBUG: FW_Item or item.data is null"])
		return
	if not tooltip_root:
		FW_Debug.debug_log(["DEBUG: tooltip_root is null"])
		return

	FW_Debug.debug_log(["DEBUG: All required nodes found, proceeding"])

	# Hide any existing tooltip before showing the new one
	if tooltip_root.visible:
		FW_Debug.debug_log(["DEBUG: Hiding existing tooltip"])
		tooltip_root.hide()
		# Safe cleanup of previous tooltip content
		for i in tooltip_root.get_children():
			if is_instance_valid(i):
				i.queue_free()

	FW_Debug.debug_log(["DEBUG: Showing tooltip"])
	tooltip_root.show()

	# Position tooltip at top-right of the screen
	var viewport_size = get_viewport().get_visible_rect().size
	var new_pos = Vector2(max(0, viewport_size.x - TOOLTIP_WIDTH - TOOLTIP_MARGIN), TOOLTIP_MARGIN)
	FW_Debug.debug_log(["DEBUG: Setting tooltip position to: ", new_pos, " (viewport size: ", viewport_size, ")"])
	tooltip_root.global_position = new_pos

	# Add the loot prefab to show item details
	if tooltip_prefab:
		FW_Debug.debug_log(["DEBUG: Instantiating loot prefab"])
		var loot = tooltip_prefab.instantiate()
		loot.populate_fields(item.data)
		tooltip_root.add_child(loot)
	else:
		FW_Debug.debug_log(["DEBUG: tooltip_prefab missing"])

	# Start/restart the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		FW_Debug.debug_log(["DEBUG: Starting tooltip timer"])
		tooltip_timer.start()
	else:
		FW_Debug.debug_log(["DEBUG: tooltip_timer is null or invalid"])

func _on_item_mouse_exited(_item: FW_InventoryItem) -> void:
	# Tooltip persists until timer expires or replaced
	pass

func _on_tooltip_timer_timeout() -> void:
	if tooltip_root:
		tooltip_root.hide()
		for i in tooltip_root.get_children():
			if is_instance_valid(i):
				i.queue_free()

func _on_inventory_items_changed(_items: Array[FW_Item]) -> void:
	_update_roll_button()

func _configure_inventory_grid() -> void:
	if not is_instance_valid(inventory_node):
		return
	if not inventory_node.has_method("refresh_from_player"):
		return
	if inventory_grid and inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
		inventory_grid.items_changed.disconnect(_on_inventory_items_changed)
	inventory_grid = inventory_node
	inventory_grid.slot_count = GDM.inventory_size if GDM else inventory_grid.slot_count
	inventory_grid.allowed_item_types = INVENTORY_ALLOWED_TYPES.duplicate()
	inventory_grid.exclude_equipped = true
	inventory_grid.exclude_quest_items = true
	inventory_grid.set_tooltip_callbacks(_on_item_mouse_entered, _on_item_mouse_exited)
	if not inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
		inventory_grid.items_changed.connect(_on_inventory_items_changed)
	FW_Debug.debug_log(["[Transmogrify] inventory grid configured, items:", inventory_grid.get_displayed_items().size()])

func _calculate_transmog_cost(count: int) -> int:
	return TRANSMOG_COSTS.get(count, 0)

func _set_transmog_slots_locked(locked: bool) -> void:
	for slot in transmog_slots:
		if slot is FW_TransmogInventorySlot:
			slot.set_locked(locked)

func _set_back_button_enabled(enabled: bool) -> void:
	if is_instance_valid(back_button):
		back_button.disabled = not enabled

func _summarize_transmog_materials(selection: Array[FW_Item]) -> Dictionary:
	var summary := {
		"count": selection.size(),
		"valid_count": 0,
		"total_gold": 0,
		"type_counts": {},
		"rarity_counts": {},
		"highest_rarity": FW_Equipment.equipment_rarity.TERRIBLE,
		"primary_type": null,
		"average_score": 0.0
	}
	if selection.is_empty():
		return summary
	var type_counts: Dictionary = summary["type_counts"]
	var rarity_counts: Dictionary = summary["rarity_counts"]
	var score_total := 0.0
	for item in selection:
		if not (item is FW_Equipment):
			continue
		summary["valid_count"] += 1
		var equipment := item as FW_Equipment
		summary["total_gold"] += equipment.gold_value
		var type_id := equipment.type
		type_counts[type_id] = type_counts.get(type_id, 0) + 1
		rarity_counts[equipment.rarity] = rarity_counts.get(equipment.rarity, 0) + 1
		if equipment.rarity > summary["highest_rarity"]:
			summary["highest_rarity"] = equipment.rarity
		score_total += equipment_config.calculate_effect_score(equipment.effects)
	if summary["valid_count"] > 0:
		summary["average_score"] = score_total / float(summary["valid_count"])
	var max_type_count := -1
	for type_id in type_counts.keys():
		var count: int = int(type_counts[type_id])
		if count > max_type_count:
			max_type_count = count
			summary["primary_type"] = type_id
	return summary

func _evaluate_transmog_roll(roll_value: int) -> Dictionary:
	var evaluation := {
		"roll": roll_value,
		"power_scalar": clampf(float(roll_value) / 100.0, 0.0, 1.0),
		"is_critical_failure": roll_value <= TRANSMOG_CRIT_FAILURE_THRESHOLD,
		"is_critical_success": roll_value >= TRANSMOG_CRIT_SUCCESS_THRESHOLD,
		"quality_delta": 0
	}
	if evaluation["is_critical_failure"]:
		evaluation["quality_delta"] = -2
	elif evaluation["is_critical_success"]:
		evaluation["quality_delta"] = 2
	elif roll_value >= TRANSMOG_SUCCESS_THRESHOLD:
		evaluation["quality_delta"] = 1
	elif roll_value <= TRANSMOG_FAILURE_THRESHOLD:
		evaluation["quality_delta"] = -1
	return evaluation

func _build_transmog_recipe(summary: Dictionary, roll_eval: Dictionary) -> Dictionary:
	var rarity_keys := FW_Equipment.equipment_rarity.keys()
	var rarity_max := rarity_keys.size() - 1
	var base_rarity := int(summary.get("highest_rarity", FW_Equipment.equipment_rarity.TERRIBLE))
	var quality_delta: int = int(roll_eval.get("quality_delta", 0))
	var target_rarity := clampi(base_rarity + quality_delta, 0, rarity_max)
	return {
		"target_rarity": target_rarity,
		"preferred_type": summary.get("primary_type", null),
		"roll_eval": roll_eval,
		"materials": summary
	}

func _resolve_transmog_outcome(recipe: Dictionary) -> Dictionary:
	var desired_type = recipe.get("preferred_type", null)
	var target_rarity = recipe.get("target_rarity", FW_Equipment.equipment_rarity.COMMON)
	var generator := FW_EquipmentGeneratorV2.new()
	var item: FW_Equipment = null
	if desired_type != null:
		item = generator.generate_equipment_of_type(desired_type, target_rarity)
	else:
		item = generator.generate_equipment(target_rarity)
	if not item:
		FW_Debug.debug_log(["[Transmogrify] Equipment generation failed", recipe])
		return {
			"item": null,
			"status": "generation_failed",
			"recipe": recipe
		}
	_tag_transmog_item(item, recipe)
	FW_Debug.debug_log(["[Transmogrify] Generated equipment:", item.name, "rarity:", item.rarity])
	return {
		"item": item,
		"status": "success",
		"recipe": recipe
	}

func _generate_transmog_outcome(selection: Array[FW_Item], roll_value: int) -> Dictionary:
	var summary := _summarize_transmog_materials(selection)
	if summary.get("valid_count", 0) < 2:
		FW_Debug.debug_log(["[Transmogrify] Outcome generation failed: insufficient materials", summary])
		return {
			"item": null,
			"status": "insufficient_materials",
			"summary": summary
		}
	var roll_eval := _evaluate_transmog_roll(roll_value)
	FW_Debug.debug_log(["[Transmogrify] Roll evaluation:", roll_eval])
	var recipe := _build_transmog_recipe(summary, roll_eval)
	FW_Debug.debug_log(["[Transmogrify] Built recipe:", recipe])
	var outcome := _resolve_transmog_outcome(recipe)
	FW_Debug.debug_log(["[Transmogrify] Resolved outcome:", outcome])
	outcome["summary"] = summary
	return outcome

func _tag_transmog_item(item: FW_Equipment, recipe: Dictionary) -> void:
	if not item:
		return
	var current_name := item.name if item.name else ""
	if not current_name.ends_with(TRANSMOG_NAME_SUFFIX):
		item.name = current_name.strip_edges() + TRANSMOG_NAME_SUFFIX
	item.set_meta("transmogrified", true)
	item.set_meta("transmog_recipe", recipe)
	var extra_text := TRANSMOG_FLAVOR_APPEND
	if item.flavor_text:
		item.flavor_text += extra_text
	else:
		if extra_text.begins_with("\n"):
			item.flavor_text = extra_text.substr(1, extra_text.length() - 1)
		else:
			item.flavor_text = extra_text

func _award_transmog_loot(item: FW_Item) -> bool:
	if not item:
		FW_Debug.debug_log(["[Transmogrify] _award_transmog_loot: no item"])
		return false
	var loot: Array = [item]
	if loot_manager:
		FW_Debug.debug_log(["[Transmogrify] Granting loot to player:", item.name])
		loot_manager.grant_loot_to_player(loot)
	else:
		FW_Debug.debug_log(["[Transmogrify] Loot manager missing"])
	if not is_instance_valid(loot_screen):
		FW_Debug.debug_log(["[Transmogrify] loot_screen invalid at award time"])
	var displayed := false
	if is_instance_valid(loot_screen):
		var tree_visible := loot_screen.is_inside_tree()
		FW_Debug.debug_log(["[Transmogrify] Loot screen valid, node:", loot_screen.name, " visible:", loot_screen.visible, " in_tree:", tree_visible, " offset:", loot_screen.offset])
		if loot_screen.has_method("show_single_loot"):
			FW_Debug.debug_log(["[Transmogrify] Invoking show_single_loot"])
			loot_screen.show_single_loot(item)
		else:
			FW_Debug.debug_log(["[Transmogrify] show_single_loot missing on loot_screen"])
		if loot_screen.has_method("slide_in"):
			FW_Debug.debug_log(["[Transmogrify] Awaiting loot_screen slide_in"])
			await loot_screen.slide_in()
			FW_Debug.debug_log(["[Transmogrify] loot_screen slide_in finished offset:", loot_screen.offset, " visible:", loot_screen.visible, " in_tree:", loot_screen.is_inside_tree()])
			displayed = true
		else:
			FW_Debug.debug_log(["[Transmogrify] slide_in missing on loot_screen"])
	else:
		FW_Debug.debug_log(["[Transmogrify] Loot screen invalid, cannot display loot"])
	return displayed

func _handle_transmog_failure(outcome: Dictionary) -> void:
	var reason: String = str(outcome.get("status", "unknown"))
	push_warning("Transmogrify failed: " + reason)

func _on_transmog_loot_back_pressed() -> void:
	if not is_instance_valid(loot_screen):
		return
	FW_Debug.debug_log(["[Transmogrify] Loot screen back pressed, sliding out"])
	loot_screen.back_button.disconnect(_on_transmog_loot_back_pressed)
	await loot_screen.slide_out()
	loot_screen.back_button.connect(_on_transmog_loot_back_pressed)
	_set_back_button_enabled(true)

func _update_roll_button() -> void:
	var selection := _gather_transmog_selection()
	var count := selection.size()
	var cost := _calculate_transmog_cost(count)
	var has_required_items := count >= 2
	var has_gold := has_required_items and GDM.player.gold >= cost
	if has_required_items:
		roll_gear_button.text = "Transmogrify! (" + str(cost) + " gp)"
	else:
		roll_gear_button.text = "Transmogrify! (Need 2 items)"
	roll_gear_button.disabled = not (has_required_items and has_gold)
	_update_gold_display(cost)

func _update_gold_display(required_cost: int = 0) -> void:
	if not is_instance_valid(player_gold):
		return
	player_gold.text = str(GDM.player.gold) + " gp"
	if required_cost > 0 and GDM.player.gold < required_cost:
		player_gold.modulate = Color.RED
	else:
		player_gold.modulate = Color.YELLOW

func _on_transmog_slot_changed() -> void:
	call_deferred("_refresh_transmog_selection_state")

func _refresh_transmog_selection_state() -> void:
	_update_roll_button()

func _gather_transmog_selection() -> Array[FW_Item]:
	var selected: Array[FW_Item] = []
	for slot in transmog_slots:
		if slot.get_child_count() == 0:
			continue
		var child: Node = slot.get_child(0)
		if child is FW_InventoryItem and child.data:
			selected.append(child.data)
	return selected

func _on_back_button_pressed() -> void:
	if is_waiting_for_roll:
		return
	var returned := _return_unspent_items()
	load_gear()
	_clear_pending_selection()
	_reset_result_labels()
	_update_roll_button()
	if returned:
		EventBus.inventory_changed.emit()
	GDM.vs_save()
	emit_signal("back_button_pressed")

func _on_roll_gear_button_pressed() -> void:
	if is_waiting_for_roll:
		return
	roll_gear_button.disabled = true
	roll_gear_button.text = "Rolling..."
	var selection := _gather_transmog_selection()
	var item_count := selection.size()
	var cost := _calculate_transmog_cost(item_count)
	if item_count < 2:
		FW_Debug.debug_log(["roll gear pressed - insufficient items"])
		_update_roll_button()
		return
	if GDM.player.gold < cost:
		FW_Debug.debug_log(["roll gear pressed - insufficient gold"])
		_update_roll_button()
		return
	pending_selection.clear()
	for item in selection:
		pending_selection.append(item)
	pending_cost = cost
	is_waiting_for_roll = true
	_set_transmog_slots_locked(true)
	_set_back_button_enabled(false)
	luck_modifier_amount = int(GDM.player.stats.luck)
	dice_results.clear()
	last_roll_value = 0
	final_roll_value = 0
	_prepare_result_labels_for_roll()
	var selection_names: Array[String] = []
	for item in pending_selection:
		selection_names.append(item.name)
	FW_Debug.debug_log(["roll gear pressed", selection_names, "cost:", cost])
	EventBus.show_dice.emit()
	EventBus.trigger_roll.emit(ROLL_FOR_TRANSMOG)

func _exit_tree() -> void:
	var returned := _return_unspent_items()
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.stop()
		tooltip_timer.queue_free()
	if EventBus.gain_gold.is_connected(_on_gain_gold):
		EventBus.gain_gold.disconnect(_on_gain_gold)
	if inventory_grid and is_instance_valid(inventory_grid):
		if inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
			inventory_grid.items_changed.disconnect(_on_inventory_items_changed)
	inventory_grid = null
	if returned:
		EventBus.inventory_changed.emit()
	_disconnect_dice_signals()
	_clear_pending_selection()
	if is_connected("slide_in_started", Callable(self, "_on_panel_slide_in")):
		disconnect("slide_in_started", Callable(self, "_on_panel_slide_in"))

func _on_gain_gold(_amount: int) -> void:
	_update_roll_button()

func _consume_transmog_items(selection: Array[FW_Item]) -> void:
	var removed := false
	for slot in transmog_slots:
		if slot.get_child_count() == 0:
			continue
		var child: Node = slot.get_child(0)
		if child is FW_InventoryItem and child.data and selection.has(child.data):
			GDM.player.inventory.erase(child.data)
			removed = true
			slot.remove_child(child)
			child.queue_free()
	if removed:
		EventBus.inventory_changed.emit()

func _show_gold_change(amount: int) -> void:
	if not floating_numbers_prefab:
		return
	var current = floating_numbers_prefab.instantiate()
	if current.has_method("_gain_gold"):
		current._gain_gold(amount)
	current.position = Vector2(700, 550)
	add_child(current)

func _on_panel_slide_in() -> void:
	_configure_inventory_grid()
	var returned := _return_unspent_items()
	setup_transmog_slots()
	load_gear()
	luck_modifier_amount = int(GDM.player.stats.luck)
	_update_result_labels_text()
	_reset_result_labels()
	if returned:
		EventBus.inventory_changed.emit()

func _play_transmog_swirl(selection: Array[FW_Item]):
	if not SWIRL_EFFECT_SCENE:
		return null
	var textures: Array[Texture2D] = []
	for item in selection:
		if item and item.texture:
			textures.append(item.texture)
	if textures.size() < 2:
		return null
	var effect = SWIRL_EFFECT_SCENE.instantiate()
	if effect is Control:
		effect.z_index = 999
	add_child(effect)
	if effect.has_method("play_effect"):
		effect.play_effect(textures)
	return effect

func _prepare_result_labels_for_roll() -> void:
	if not is_instance_valid(roll_result_label):
		return
	roll_result_label.text = "..."
	luck_modifier_label.text = _format_luck_modifier_text()
	final_result_label.text = ""
	_reset_result_labels(false)

func _reset_result_labels(should_hide: bool = true) -> void:
	if not is_instance_valid(roll_result_label):
		return
	roll_result_label.position = roll_label_origin
	roll_result_label.scale = Vector2.ONE
	luck_modifier_label.position = luck_label_origin
	luck_modifier_label.scale = Vector2.ONE
	final_result_label.position = final_label_origin
	final_result_label.scale = Vector2.ONE
	var roll_color := Color(roll_result_color.r, roll_result_color.g, roll_result_color.b, 0.0)
	var luck_color := Color(luck_modifier_color.r, luck_modifier_color.g, luck_modifier_color.b, 0.0)
	var final_color := Color(final_result_color.r, final_result_color.g, final_result_color.b, 0.0)
	roll_result_label.modulate = roll_color
	luck_modifier_label.modulate = luck_color
	final_result_label.modulate = final_color
	roll_result_label.visible = not should_hide
	luck_modifier_label.visible = not should_hide
	final_result_label.visible = not should_hide

func _update_result_labels_text() -> void:
	if not is_instance_valid(roll_result_label):
		return
	roll_result_label.text = str(last_roll_value)
	luck_modifier_label.text = _format_luck_modifier_text()
	final_result_label.text = str(final_roll_value)

func _format_luck_modifier_text() -> String:
	var modifier_sign := "+" if luck_modifier_amount >= 0 else "-"
	return modifier_sign + " " + str(abs(luck_modifier_amount))

func _play_roll_result_animation() -> void:
	if not is_instance_valid(roll_result_label):
		return
	var roll_tween := create_tween()
	roll_tween.tween_property(roll_result_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	roll_tween.parallel().tween_property(roll_result_label, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_BACK)
	roll_tween.parallel().tween_property(roll_result_label, "scale", Vector2.ONE, 0.15).set_delay(0.25).set_trans(Tween.TRANS_BACK)
	await roll_tween.finished
	var luck_tween := create_tween()
	luck_tween.tween_property(luck_modifier_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	luck_tween.parallel().tween_property(luck_modifier_label, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_BACK)
	luck_tween.parallel().tween_property(luck_modifier_label, "scale", Vector2.ONE, 0.15).set_delay(0.25).set_trans(Tween.TRANS_BACK)
	await luck_tween.finished
	var combine_tween := create_tween()
	combine_tween.tween_property(roll_result_label, "position", final_label_origin, 0.3).set_trans(Tween.TRANS_BACK)
	combine_tween.parallel().tween_property(luck_modifier_label, "position", final_label_origin, 0.3).set_trans(Tween.TRANS_BACK)
	combine_tween.parallel().tween_property(roll_result_label, "modulate:a", 0.0, 0.3)
	combine_tween.parallel().tween_property(luck_modifier_label, "modulate:a", 0.0, 0.3)
	combine_tween.parallel().tween_property(final_result_label, "modulate:a", 1.0, 0.2).set_delay(0.1).set_trans(Tween.TRANS_SINE)
	combine_tween.parallel().tween_property(final_result_label, "scale", Vector2(1.35, 1.35), 0.2).set_delay(0.1).set_trans(Tween.TRANS_BACK)
	combine_tween.parallel().tween_property(final_result_label, "scale", Vector2.ONE, 0.15).set_delay(0.3).set_trans(Tween.TRANS_BACK)
	await combine_tween.finished
	roll_result_label.position = roll_label_origin
	luck_modifier_label.position = luck_label_origin
	roll_result_label.visible = false
	luck_modifier_label.visible = false
	final_result_label.modulate = Color(final_result_color.r, final_result_color.g, final_result_color.b, 1.0)
	final_result_label.visible = true

func _handle_transmog_roll_result(result: int) -> void:
	last_roll_value = result
	final_roll_value = last_roll_value + luck_modifier_amount
	_update_result_labels_text()
	_reset_result_labels(false)
	await _play_roll_result_animation()
	await get_tree().create_timer(0.8).timeout
	EventBus.hide_dice.emit()
	await _resolve_pending_transmog_roll()

func _resolve_pending_transmog_roll() -> void:
	if pending_selection.is_empty():
		_clear_pending_selection()
		_update_roll_button()
		return
	var selection_names: Array[String] = []
	for item in pending_selection:
		selection_names.append(item.name)
	FW_Debug.debug_log(["[Transmogrify] resolving roll", selection_names, "roll:", final_roll_value])
	var swirl_effect = _play_transmog_swirl(pending_selection)
	if swirl_effect and swirl_effect.has_signal("effect_finished"):
		await swirl_effect.effect_finished
	var outcome := _generate_transmog_outcome(pending_selection, final_roll_value)
	_reset_result_labels()
	if outcome.get("status", "") != "success":
		FW_Debug.debug_log(["[Transmogrify] Outcome not success:", outcome])
		_handle_transmog_failure(outcome)
		_clear_pending_selection()
		_update_roll_button()
		return
	var generated_item: FW_Item = outcome.get("item", null)
	FW_Debug.debug_log(["[Transmogrify] Generated item:", generated_item])
	_consume_transmog_items(pending_selection)
	if pending_cost > 0:
		GDM.player.gold -= pending_cost
	EventBus.inventory_changed.emit()
	if pending_cost != 0:
		_show_gold_change(-pending_cost)
	FW_Debug.debug_log(["[Transmogrify] Awaiting loot award for:", generated_item.name if generated_item else "null"])
	var loot_screen_displayed := await _award_transmog_loot(generated_item)
	FW_Debug.debug_log(["[Transmogrify] Loot award completed"])
	var should_enable_back_button := not loot_screen_displayed
	load_gear()
	_update_roll_button()
	FW_Debug.debug_log(["[Transmogrify] post-consume inventory size:", GDM.player.inventory.size()])
	_clear_pending_selection(should_enable_back_button)

func _clear_pending_selection(enable_back_button: bool = true) -> void:
	pending_selection.clear()
	pending_cost = 0
	is_waiting_for_roll = false
	dice_results.clear()
	_set_transmog_slots_locked(false)
	if enable_back_button:
		_set_back_button_enabled(true)

func _connect_dice_signals() -> void:
	dice_nodes.clear()
	if not is_instance_valid(dice_viewport):
		return
	_find_dice_nodes(dice_viewport, dice_nodes)
	var callback := Callable(self, "_on_die_roll_finished")
	for die in dice_nodes:
		if not is_instance_valid(die):
			continue
		if die.is_connected("roll_finished", callback):
			continue
		die.connect("roll_finished", callback)

func _disconnect_dice_signals() -> void:
	var callback := Callable(self, "_on_die_roll_finished")
	for die in dice_nodes:
		if is_instance_valid(die) and die.is_connected("roll_finished", callback):
			die.disconnect("roll_finished", callback)
	dice_nodes.clear()

func _find_dice_nodes(node: Node, out_nodes: Array) -> void:
	if node.has_method("trigger_roll") and node.has_signal("roll_finished"):
		out_nodes.append(node)
	for child in node.get_children():
		_find_dice_nodes(child, out_nodes)

func _on_die_roll_finished(value: int, die_type, roll_for: String) -> void:
	if roll_for != ROLL_FOR_TRANSMOG:
		return
	if not is_waiting_for_roll:
		return
	dice_results[die_type] = value
	if dice_results.size() < 2:
		return
	var percentile: int = int(dice_results.get(DIE_TYPE_TENS, 0))
	var ones: int = int(dice_results.get(DIE_TYPE_ONES, 0))
	dice_results.clear()
	var combined := FW_Utils._combine_percentile_dice(percentile, ones)
	await _handle_transmog_roll_result(combined)

func _return_unspent_items() -> bool:
	var returned := false
	for slot in transmog_slots:
		if slot.get_child_count() == 0:
			continue
		var child: Node = slot.get_child(0)
		if child is FW_InventoryItem and child.data:
			returned = true
			if not GDM.player.inventory.has(child.data):
				GDM.player.inventory.append(child.data)
			slot.remove_child(child)
			child.queue_free()
	return returned

func show_dice_viewport() -> void:
	# Prevent redundant activation
	if viewport_display.visible:
		return
	# Enable viewport updates only when needed during the roll
	dice_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Prime the texture before showing to avoid a blank frame
	viewport_display.texture = dice_viewport.get_texture()
	await get_tree().process_frame
	viewport_display.show()

func hide_dice_viewport() -> void:
	# Fast-path: if already hidden, ensure viewport is disabled
	if not viewport_display.visible:
		dice_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# Disable rendering first to stop GPU work immediately
	dice_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Hide and release the texture reference to avoid unnecessary updates
	viewport_display.hide()
	viewport_display.texture = null
