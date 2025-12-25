extends PanelContainer
class_name FW_EquipmentInventorySlot

var slot_types: Array[FW_Equipment.equipment_types]

func _ready() -> void:
	_connect_child_signals()
	_update_cursor_shape()

func init(cms: Vector2, equipment_type: Array[FW_Equipment.equipment_types]) -> void:
	custom_minimum_size = cms
	slot_types = equipment_type

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is FW_EquipmentInventoryItem and data.data.type in slot_types:
		if get_child_count() == 0:
			return true
		else:
			return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if get_child_count() > 0:
		var item := get_child(0)
		if item == data:
			return
		item.reparent(data.get_parent())
	data.reparent(self)
	_update_cursor_shape()

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
