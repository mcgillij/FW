extends PanelContainer
class_name FW_ConsumableInventorySlot

var slot_type: FW_Item.ITEM_TYPE = FW_Item.ITEM_TYPE.CONSUMABLE

func init(cms: Vector2) -> void:
	custom_minimum_size = cms

func _ready() -> void:
	_connect_child_signals()
	_update_cursor_shape()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is FW_ConsumableInventoryItem and data.data.item_type == slot_type:
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if get_child_count() > 0:
		var existing_item := get_child(0)
		if existing_item == data:
			return
		# Move existing item back to where the dragged item came from
		existing_item.reparent(data.get_parent())

		# If we're swapping with an item from main inventory, the existing item
		# should go back to main inventory and be removed from consumable slots
		_handle_item_moved_to_inventory(existing_item)

	# Move the dragged item to this slot
	data.reparent(self)
	_update_cursor_shape()

	# If the item came from main inventory, it's now "slotted" and should
	# be handled by the consumable slot system
	_handle_item_moved_to_slot(data)

# Handle when an item is moved from a consumable slot back to inventory
func _handle_item_moved_to_inventory(item: FW_ConsumableInventoryItem) -> void:
	if item.data is FW_Consumable:
		# Find and clear this item from player's consumable slots
		for i in range(GDM.player.consumable_slots.size()):
			if GDM.player.consumable_slots[i] == item.data:
				GDM.player.consumable_slots[i] = null
				EventBus.consumable_slots_changed.emit()
				break

# Handle when an item is moved from inventory to a consumable slot
func _handle_item_moved_to_slot(_item: FW_ConsumableInventoryItem) -> void:
	# This will be handled when save_consumable_slots() is called
	# on inventory close, so no immediate action needed
	pass

func _connect_child_signals() -> void:
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
	if not child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.connect(_on_child_exiting_tree)

func _on_child_entered_tree(_child: Node) -> void:
	_update_cursor_shape()

func _on_child_exiting_tree(_child: Node) -> void:
	call_deferred("_update_cursor_shape")

func _update_cursor_shape() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _has_item_child() else Control.CURSOR_ARROW

func _has_item_child() -> bool:
	for child in get_children():
		if child is FW_InventoryItem:
			return true
	return false

# Handle right-click to use consumables
# For now not supporting using items out of the inventory screen,
# will be from the battle screen
#func _gui_input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.pressed:
		#if event.button_index == MOUSE_BUTTON_RIGHT and get_child_count() > 0:
			#var consumable_item = get_child(0)
			#if consumable_item is FW_ConsumableInventoryItem:
				#_use_consumable(consumable_item)

func _use_consumable(consumable_item: FW_ConsumableInventoryItem) -> void:
	var consumable = consumable_item.data as FW_Consumable
	if consumable and consumable.can_use() and consumable.use_consumable():
		# Successfully used - remove from slot/inventory
		_consume_item(consumable_item)

func _consume_item(consumable_item: FW_ConsumableInventoryItem) -> void:
	# Use player's method to properly remove from both inventory and slots
	if GDM.player and GDM.player.consume_item(consumable_item.data):
		# Remove the UI element
		consumable_item.queue_free()
