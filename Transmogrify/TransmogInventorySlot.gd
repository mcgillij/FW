extends FW_InventorySlot
class_name FW_TransmogInventorySlot

signal slot_changed

var locked := false

func init(cms: Vector2, item_types: Array[FW_Item.ITEM_TYPE] = [FW_Item.ITEM_TYPE.EQUIPMENT], index: int = -1) -> void:
	super.init(cms, item_types)
	var style := "res://Styles/numbered_panel_" + str(index + 1) + ".tres"
	set("theme_override_styles/panel", load(style))

func _ready() -> void:
	child_entered_tree.connect(_on_child_changed)
	child_exiting_tree.connect(_on_child_changed)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _on_child_changed(node: Node) -> void:
	if node is FW_InventoryItem:
		emit_signal("slot_changed")
		_apply_lock_state()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if locked:
		return false
	if not (data is FW_InventoryItem):
		return false
	if not data.data:
		return false
	if data.get_parent() is FW_VendorInventorySlot:
		return GDM.player.gold >= data.data.gold_value and data.data.item_type in slot_types
	return data.data.item_type in slot_types

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if locked:
		return
	super._drop_data(at_position, data)
	emit_signal("slot_changed")

func set_locked(value: bool) -> void:
	locked = value
	_apply_lock_state()

func _apply_lock_state() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_PASS
	if get_child_count() == 0:
		return
	var child := get_child(0)
	if child is FW_InventoryItem:
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_PASS
