extends "res://Scripts/base_menu_panel.gd"

signal back_button

@export var tooltip_prefab: PackedScene
@onready var equipment_stats_label: RichTextLabel = %equipment_stats_label
@onready var gear_slots: Array = [%hat_slot, %tail_slot, %collar_slot, %harness_slot, %bracers_slot, %weapon_slot]
@onready var equipment_inventory: GridContainer = %equipment_inventory

# Tooltip system
@export var tooltip_root: CanvasItem

const TOOLTIP_WIDTH := 350.0
const TOOLTIP_MARGIN := 20.0

var tooltip_timer: Timer

func _ready() -> void:
	if tooltip_root:
		tooltip_root.hide()

	# Create and configure the tooltip timer
	tooltip_timer = Timer.new()
	tooltip_timer.wait_time = 15.0
	tooltip_timer.one_shot = true
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	add_child(tooltip_timer)

	if not EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.connect(_on_inventory_changed)

func setup() -> void:
	_refresh_inventory_from_state()

func setup_equipment_slots() -> void:
	_clear_equipment_slots()
	_create_equipment_slot(%hat_slot, FW_Equipment.equipment_types.HAT)
	_create_equipment_slot(%tail_slot, FW_Equipment.equipment_types.TAIL)
	_create_equipment_slot(%collar_slot, FW_Equipment.equipment_types.COLLAR)
	_create_equipment_slot(%harness_slot, FW_Equipment.equipment_types.HARNESS)
	_create_equipment_slot(%bracers_slot, FW_Equipment.equipment_types.BRACERS)
	_create_equipment_slot(%weapon_slot, FW_Equipment.equipment_types.WEAPON)

func _clear_equipment_slots() -> void:
	for slot in gear_slots:
		for child in slot.get_children():
			slot.remove_child(child)
			child.free()

func _create_equipment_slot(container: Control, equipment_type: FW_Equipment.equipment_types) -> void:
	var slot := FW_EquipmentInventorySlot.new()
	slot.init(GDM.inventory_item_size, [equipment_type])
	container.add_child(slot)

func _reset_inventory_grid() -> void:
	for child in equipment_inventory.get_children():
		equipment_inventory.remove_child(child)
		child.free()
	for i in GDM.inventory_size:
		var slot := FW_InventorySlot.new()
		slot.init(GDM.inventory_item_size, [FW_Item.ITEM_TYPE.EQUIPMENT])
		equipment_inventory.add_child(slot)

func _populate_inventory_items() -> void:
	var slot_count := 0
	for e in GDM.player.inventory:
		var found := false
		for eq in GDM.player.equipment:
			if eq != null and eq == e:
				found = true
				break
		if not found and e.item_type == FW_Item.ITEM_TYPE.EQUIPMENT:
			if slot_count >= equipment_inventory.get_child_count():
				break
			var item := FW_EquipmentInventoryItem.new()
			item.init(e)
			item.tooltip_text = ""  # Disable built-in tooltip
			item.mouse_entered.connect(_on_item_mouse_entered.bind(item))
			item.mouse_exited.connect(_on_item_mouse_exited.bind(item))
			equipment_inventory.get_child(slot_count).add_child(item)
			slot_count += 1
	FW_Debug.debug_log(["[EquipmentPanel] populated inventory items:", slot_count])

func _populate_equipped_items() -> void:
	for j in GDM.player.equipment.size():
		if GDM.player.equipment[j]:
			var item := FW_EquipmentInventoryItem.new()
			item.init(GDM.player.equipment[j])
			item.tooltip_text = ""  # Disable built-in tooltip
			item.mouse_entered.connect(_on_item_mouse_entered.bind(item))
			item.mouse_exited.connect(_on_item_mouse_exited.bind(item))
			match GDM.player.equipment[j].type:
				FW_Equipment.equipment_types.WEAPON:
					%weapon_slot.get_child(0).add_child(item)
				FW_Equipment.equipment_types.HAT:
					%hat_slot.get_child(0).add_child(item)
				FW_Equipment.equipment_types.TAIL:
					%tail_slot.get_child(0).add_child(item)
				FW_Equipment.equipment_types.COLLAR:
					%collar_slot.get_child(0).add_child(item)
				FW_Equipment.equipment_types.HARNESS:
					%harness_slot.get_child(0).add_child(item)
				FW_Equipment.equipment_types.BRACERS:
					%bracers_slot.get_child(0).add_child(item)
					FW_Debug.debug_log(["[EquipmentPanel] added equipped item:", GDM.player.equipment[j].name])

func _refresh_inventory_from_state() -> void:
	_reset_inventory_grid()
	setup_equipment_slots()
	_populate_inventory_items()
	_populate_equipped_items()
	display_equipment_stats()

func _on_inventory_changed() -> void:
	if not is_inside_tree():
		return
	_refresh_inventory_from_state()

func save_equipment() -> void:
	# Store old consumable slots count before equipment change
	var old_max_slots = GDM.player.get_max_consumable_slots()

	GDM.player.stats.remove_all_equipment_bonus()
	var equipment_array: Array[FW_Equipment]
	for j in gear_slots:
		var item = j.get_child(0)
		if item:
			if item.get_child_count() > 0:
				var child = item.get_child(0)
				if child:
					equipment_array.append(child.data)
					child.data.apply_stats()
				else:
					equipment_array.append(null)
	GDM.player.equipment = equipment_array

	# Check if consumable slots changed after equipment update
	var new_max_slots = GDM.player.get_max_consumable_slots()
	if new_max_slots != old_max_slots:
		# Update consumable slots and handle any displaced items
		GDM.player.update_consumable_slots_size()

func display_equipment_stats() -> void:
	var equipment_array: Array[FW_Equipment]
	for j in gear_slots:
		if j.get_child_count() > 0:
			var item = j.get_child(0)
			if item:
				if item.get_child_count() > 0:
					var child = item.get_child(0)
					if child:
						equipment_array.append(child.data)
					else:
						equipment_array.append(null)
	var equipment_stats_dict := {}
	for item in equipment_array:
		if item:
			for effect in item.effects.keys():
				if equipment_stats_dict.has(effect):
					equipment_stats_dict[effect] = equipment_stats_dict[effect] + item.effects[effect]
				else:
					equipment_stats_dict[effect] = item.effects[effect]
	equipment_stats_label.text = FW_Utils.format_effects(equipment_stats_dict)

func clean_up() -> void:
	for s in %equipment_inventory.get_children():
		s.queue_free()
	for slot in gear_slots:
		for c in slot.get_children():
			c.queue_free()

func _exit_tree() -> void:
	# Clean up the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.stop()
		tooltip_timer.queue_free()
	if EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.disconnect(_on_inventory_changed)

func _on_back_button_pressed() -> void:
	save_equipment()
	GDM.vs_save()
	clean_up()
	emit_signal("back_button")

func _on_refresh_timer_timeout() -> void:
	display_equipment_stats()

# Tooltip functions
func _on_tooltip_timer_timeout() -> void:
	if tooltip_root:
		tooltip_root.hide()
		# Safe cleanup - remove all children
		for i in tooltip_root.get_children():
			if is_instance_valid(i):
				i.queue_free()

func _on_item_mouse_entered(item: FW_EquipmentInventoryItem) -> void:
	# Null safety check
	if not item or not item.data:
		return
	if not tooltip_root:
		return

	# Hide any existing tooltip before showing the new one
	if tooltip_root.visible:
		tooltip_root.hide()
		# Safe cleanup of previous tooltip content
		for i in tooltip_root.get_children():
			if is_instance_valid(i):
				i.queue_free()

	tooltip_root.show()

	# Position tooltip at top-left of the screen
	var new_pos = Vector2(TOOLTIP_MARGIN, TOOLTIP_MARGIN)
	tooltip_root.global_position = new_pos

	# Add the loot prefab to show item details
	if tooltip_prefab:
		var loot = tooltip_prefab.instantiate()
		loot.populate_fields(item.data)
		tooltip_root.add_child(loot)

	# Start/restart the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.start()

func _on_item_mouse_exited(_item: FW_EquipmentInventoryItem) -> void:
	# Tooltip persists until timer expires or replaced
	pass
