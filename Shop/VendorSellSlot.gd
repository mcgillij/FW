extends PanelContainer
class_name FW_VendorSellSlot

func init(cms: Vector2) -> void:
	custom_minimum_size = cms

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is FW_EquipmentInventoryItem or data is FW_InventoryItem:
		if get_child_count() == 0:
			return true
		else:
			return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not is_instance_valid(data):
		return
	if not (data is FW_InventoryItem):
		return
	var item_resource: FW_Item = data.data
	if item_resource == null:
		return
	var gold_value = item_resource.gold_value
	if get_child_count() > 0:
		var item := get_child(0)
		item.queue_free()
	GDM.player.inventory.erase(item_resource)
	data.queue_free()
	EventBus.inventory_changed.emit()
	EventBus.gain_gold.emit(gold_value)
