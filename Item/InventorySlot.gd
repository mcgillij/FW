extends PanelContainer
class_name FW_InventorySlot

var slot_types: Array[FW_Item.ITEM_TYPE]

func _ready() -> void:
	_connect_child_signals()
	_update_cursor_shape()

func init(cms: Vector2, item_types: Array[FW_Item.ITEM_TYPE]) -> void:
	custom_minimum_size = cms
	slot_types = item_types

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_instance_valid(data):
		return false
	if data.get_parent() is FW_VendorInventorySlot:
		# Check if player has enough money to buy the item
		if not (data is FW_InventoryItem):
			return false
		return GDM.player.gold >= data.data.gold_value
	else:
		# Normal inventory logic
		return true # or implement your own logic here

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not is_instance_valid(data):
		return
	if data.get_parent() is FW_VendorInventorySlot:
		if not (data is FW_InventoryItem):
			return
		var item_resource: FW_Item = data.data
		if item_resource == null:
			return
		if GDM.player.gold >= item_resource.gold_value:
			GDM.player.gold -= item_resource.gold_value
			GDM.player.inventory.append(item_resource)
			data.reparent(self)
			EventBus.gain_gold.emit(-item_resource.gold_value)

			# Update quest progress for collected items
			if item_resource.item_type == FW_Item.ITEM_TYPE.QUEST:
				QuestManager.update_quest_progress(FW_QuestGoal.GOAL_TYPE.COLLECT, item_resource, 1)

			# Emit appropriate notification signals for purchased items
			if item_resource.item_type == FW_Item.ITEM_TYPE.EQUIPMENT:
				EventBus.equipment_added.emit(item_resource)
			elif item_resource.item_type == FW_Item.ITEM_TYPE.CONSUMABLE:
				EventBus.consumable_added.emit(item_resource)
			else:
				EventBus.inventory_item_added.emit(item_resource)

			EventBus.inventory_changed.emit()
	else:
		# Normal inventory logic (swap, move, etc.)
		if get_child_count() > 0:
			var item := get_child(0)
			if item == data:
				return
			item.reparent(data.get_parent())

		# If item came from a ConsumableInventorySlot, handle the move
		if data.get_parent() is FW_ConsumableInventorySlot:
			_handle_consumable_moved_from_slot(data)

		data.reparent(self)
		_update_cursor_shape()

# Handle when a consumable is moved from a consumable slot to inventory
func _handle_consumable_moved_from_slot(data: Variant) -> void:
	if data is FW_ConsumableInventoryItem and data.data is FW_Consumable:
		# Clear the item from player's consumable slots
		for i in range(GDM.player.consumable_slots.size()):
			if GDM.player.consumable_slots[i] == data.data:
				GDM.player.consumable_slots[i] = null
				break

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
