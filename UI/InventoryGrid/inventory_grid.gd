extends GridContainer
class_name FW_InventoryGrid

@export var slot_count: int = 0
@export var slot_accept_types: Array = []
@export var allowed_item_types: Array = []
@export var exclude_equipped: bool = true
@export var exclude_quest_items: bool = true
@export var listen_inventory_changed: bool = true
@export var auto_tooltip: bool = true
@export var refresh_on_ready: bool = true

signal items_changed(items: Array[FW_Item])
signal item_mouse_entered(item_node: FW_InventoryItem)
signal item_mouse_exited(item_node: FW_InventoryItem)

var custom_filter: Callable = Callable()
var _tooltip_enter_callable: Callable = Callable()
var _tooltip_exit_callable: Callable = Callable()
var _items: Array[FW_Item] = []

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if slot_count <= 0 and GDM:
		slot_count = GDM.inventory_size
	if listen_inventory_changed and not EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.connect(_on_inventory_changed)
	if refresh_on_ready:
		refresh_from_player()

func _exit_tree() -> void:
	if listen_inventory_changed and EventBus.inventory_changed.is_connected(_on_inventory_changed):
		EventBus.inventory_changed.disconnect(_on_inventory_changed)

func set_custom_filter(filter_callable: Callable) -> void:
	custom_filter = filter_callable
	refresh_from_player()

func set_tooltip_callbacks(enter_callable: Callable, exit_callable: Callable = Callable()) -> void:
	_tooltip_enter_callable = enter_callable
	_tooltip_exit_callable = exit_callable

func refresh_from_player() -> void:
	if Engine.is_editor_hint():
		return
	var slots_to_build := slot_count
	if slots_to_build <= 0 and GDM:
		slots_to_build = GDM.inventory_size
	_clear_slots()
	_build_slots(slots_to_build)
	_items = _collect_items()
	FW_Debug.debug_log(["[InventoryGrid] refresh_from_player collected items:", _items.size()])
	FW_Debug.debug_log(["[InventoryGrid] slot children count:", get_child_count()])
	_populate_items(_items)
	items_changed.emit(_items.duplicate())

func get_displayed_items() -> Array[FW_Item]:
	return _items.duplicate()

func _clear_slots() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

func _build_slots(count: int) -> void:
	for i in range(count):
		var slot := _create_slot()
		add_child(slot)

func _create_slot() -> Control:
	var slot: Control
	if InventorySlot:
		slot = FW_InventorySlot.new()
	else:
		slot = PanelContainer.new()
	if slot and slot.has_method("init"):
		var cms := GDM.inventory_item_size if GDM else Vector2(64, 64)
		var accept_types := slot_accept_types if slot_accept_types.size() > 0 else _default_slot_types()
		slot.init(cms, accept_types)
	return slot

func _collect_items() -> Array[FW_Item]:
	var collected: Array[FW_Item] = []
	if not GDM or not GDM.player:
		return collected
	for item in GDM.player.inventory:
		if item == null:
			continue
		if exclude_quest_items and item.item_type == FW_Item.ITEM_TYPE.QUEST:
			continue
		if exclude_equipped and _is_equipped(item):
			continue
		if allowed_item_types.size() > 0 and not allowed_item_types.has(item.item_type):
			continue
		if custom_filter.is_valid() and not custom_filter.call(item):
			continue
		collected.append(item)
	return collected

func _is_equipped(item: FW_Item) -> bool:
	if not GDM or not GDM.player:
		return false
	for eq in GDM.player.equipment:
		if eq == item:
			return true
	return false

func _populate_items(items: Array[FW_Item]) -> void:
	for index in range(items.size()):
		if index >= get_child_count():
			break
		var slot := get_child(index)
		var item_node := _create_item_node(items[index])
		if item_node:
			slot.add_child(item_node)

func _create_item_node(item: FW_Item) -> FW_InventoryItem:
	var node: FW_InventoryItem
	if item.item_type == FW_Item.ITEM_TYPE.CONSUMABLE:
		node = FW_ConsumableInventoryItem.new()
	else:
		node = FW_InventoryItem.new()
	if node.has_method("init"):
		node.init(item)
	if auto_tooltip:
		node.tooltip_text = ""
		node.mouse_entered.connect(_handle_item_mouse_entered.bind(node))
		node.mouse_exited.connect(_handle_item_mouse_exited.bind(node))
	return node

func _handle_item_mouse_entered(node: FW_InventoryItem) -> void:
	if _tooltip_enter_callable.is_valid():
		_tooltip_enter_callable.call(node)
	item_mouse_entered.emit(node)

func _handle_item_mouse_exited(node: FW_InventoryItem) -> void:
	if _tooltip_exit_callable.is_valid():
		_tooltip_exit_callable.call(node)
	item_mouse_exited.emit(node)

func _on_inventory_changed() -> void:
	if not is_inside_tree():
		return
	call_deferred("refresh_from_player")

func _default_slot_types() -> Array[FW_Item.ITEM_TYPE]:
	return [FW_Item.ITEM_TYPE.EQUIPMENT, FW_Item.ITEM_TYPE.JUNK]
