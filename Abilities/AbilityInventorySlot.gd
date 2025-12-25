extends PanelContainer
class_name FW_AbilityInventorySlot

func init(cms: Vector2, index: int = 0) -> void:
	custom_minimum_size = cms
	# sets the background
	if index != 0:
		var style := "res://Styles/numbered_panel_" + str(index) + ".tres"
		set("theme_override_styles/panel", load(style))

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var can_drop = data is Dictionary and data.has("item") and data.item is FW_AbilityInventoryItem
	return can_drop

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var dragged_item: FW_AbilityInventoryItem = data.item
	var source_slot: FW_AbilityInventorySlot = data.source_slot
	var target_slot: FW_AbilityInventorySlot = self

	if source_slot == target_slot:
		return

	if target_slot.get_child_count() > 0:
		var item_in_target: FW_AbilityInventoryItem = target_slot.get_child(0)
		item_in_target.reparent(source_slot)
		dragged_item.reparent(target_slot)
	else:
		dragged_item.reparent(target_slot)
	EventBus.tab_highlight.emit()
	EventBus.calculate_job.emit()
