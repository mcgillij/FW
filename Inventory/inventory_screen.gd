extends "res://Scripts/base_menu_panel.gd"

signal back_button

@export var tooltip_prefab: PackedScene
@onready var inventory_node: GridContainer = %inventory
@onready var consumable_slot_container: HBoxContainer = %ConsumableSlotContainer

# Tooltip system
@export var tooltip_root: CanvasItem

const TOOLTIP_WIDTH := 350.0
const TOOLTIP_MARGIN := 20.0
const INVENTORY_ALLOWED_TYPES := [FW_Item.ITEM_TYPE.JUNK, FW_Item.ITEM_TYPE.CONSUMABLE, FW_Item.ITEM_TYPE.QUEST]

var tooltip_timer: Timer

# Dynamic array to hold references to consumable slots
var consumable_slots: Array[FW_ConsumableInventorySlot] = []
var consumable_style := load("res://Styles/ConsumableSlot.tres")

var inventory_grid

func setup() -> void:
	# Clean up existing UI elements first to prevent duplicates
	clean_up()

	# Check if slot count has changed and handle displaced items
	handle_slot_changes()

	# Ensure player has the right number of consumable slots
	GDM.player.update_consumable_slots_size()

	# Create consumable slots dynamically
	create_consumable_slots()
	_configure_inventory_grid()

	# Load consumables from player's consumable slots
	load_consumable_slots()

# Handle slot count changes (called when opening inventory)
func handle_slot_changes() -> void:
	var current_slot_data_count = GDM.player.consumable_slots.size()
	var expected_slot_count = GDM.player.get_max_consumable_slots()

	if current_slot_data_count != expected_slot_count:
		FW_Debug.debug_log(["Detected slot count mismatch: data has %d, expected %d" % [current_slot_data_count, expected_slot_count]])
		# The update_consumable_slots_size() call in setup() will handle this

# Check if a consumable is currently in a consumable slot

# Create consumable slots based on player's max slots
func create_consumable_slots() -> void:
	# Clear any existing slots
	consumable_slots.clear()
	for child in consumable_slot_container.get_children():
		child.queue_free()

	# Create slots based on player's available slots
	var max_slots = GDM.player.get_max_consumable_slots()
	for i in max_slots:
		var slot = FW_ConsumableInventorySlot.new()
		slot.init(Vector2(128, 128))
		slot.name = "ConsumableSlot" + str(i)
		slot.set("theme_override_styles/panel", consumable_style)
		consumable_slot_container.add_child(slot)
		consumable_slots.append(slot)

# Check if a consumable is currently in a consumable slot
func _is_consumable_slotted(consumable: FW_Consumable) -> bool:
	for slotted_consumable in GDM.player.consumable_slots:
		if slotted_consumable == consumable:
			return true
	return false

func load_consumable_slots() -> void:
	# Load consumables from player data into UI slots
	for i in range(min(consumable_slots.size(), GDM.player.consumable_slots.size())):
		var consumable = GDM.player.consumable_slots[i]
		if consumable:
			var item = FW_ConsumableInventoryItem.new()
			item.init(consumable)
			consumable_slots[i].add_child(item)

func save_consumable_slots() -> void:
	# Save UI slot contents back to player data
	# Ensure the player's array is the right size
	GDM.player.consumable_slots.resize(consumable_slots.size())

	for i in range(consumable_slots.size()):
		if consumable_slots[i].get_child_count() > 0:
			var item = consumable_slots[i].get_child(0)
			if item is FW_ConsumableInventoryItem:
				GDM.player.consumable_slots[i] = item.data
		else:
			GDM.player.consumable_slots[i] = null

func clean_up() -> void:
	# Clean up main inventory slots
	for slot in inventory_node.get_children():
		slot.queue_free()

	# Clean up consumable slots
	for slot in consumable_slots:
		if slot.get_child_count() > 0:
			slot.get_child(0).queue_free()

	# Clear the slots array but don't free the slot containers themselves
	# They'll be recreated in setup()
	consumable_slots.clear()

func _exit_tree() -> void:
	# Clean up the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.stop()
		tooltip_timer.queue_free()
	if inventory_grid and inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
		inventory_grid.items_changed.disconnect(_on_inventory_items_changed)
	inventory_grid = null

func _on_back_button_pressed() -> void:
	save_consumable_slots()  # Save slot contents before closing
	EventBus.consumable_slots_changed.emit()  # Notify other systems
	clean_up()
	emit_signal("back_button")

# Debug function to test consumable functionality
func _ready() -> void:
	if tooltip_root:
		tooltip_root.hide()

	# Create and configure the tooltip timer
	tooltip_timer = Timer.new()
	tooltip_timer.wait_time = 15.0
	tooltip_timer.one_shot = true
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	add_child(tooltip_timer)

	# Uncomment the line below to add test consumables when the inventory opens
	# FW_LootManager.give_test_consumables_to_player(3)
	pass

# Debug function to test different slot counts
func test_slot_expansion() -> void:
	# This simulates equipment that adds consumable slots
	# In a real game, this would be handled by equipment effects
	FW_Debug.debug_log(["Testing slot expansion - current max slots: ", GDM.player.get_max_consumable_slots()])

	# Force refresh the UI to show new slot count
	setup()

# Tooltip functions
func _on_tooltip_timer_timeout() -> void:
	FW_Debug.debug_log(["DEBUG: Tooltip timer timed out, hiding tooltip"])
	if tooltip_root:
		tooltip_root.hide()
		# Safe cleanup - remove all children
		for i in tooltip_root.get_children():
			if is_instance_valid(i):
				i.queue_free()

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

	# Position tooltip at top-left of the screen (consistent with equipment_panel.gd)
	var viewport_size = get_viewport().get_visible_rect().size
	var new_pos = Vector2(TOOLTIP_MARGIN, TOOLTIP_MARGIN)
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

func _configure_inventory_grid() -> void:
	if not is_instance_valid(inventory_node):
		return
	if not inventory_node.has_method("refresh_from_player"):
		return
	if inventory_grid and inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
		inventory_grid.items_changed.disconnect(_on_inventory_items_changed)
	inventory_grid = inventory_node
	inventory_grid.slot_count = GDM.inventory_size
	inventory_grid.allowed_item_types = INVENTORY_ALLOWED_TYPES.duplicate()
	inventory_grid.exclude_equipped = true
	inventory_grid.exclude_quest_items = false
	inventory_grid.set_tooltip_callbacks(_on_item_mouse_entered, _on_item_mouse_exited)
	inventory_grid.set_custom_filter(_inventory_filter)
	inventory_grid.items_changed.connect(_on_inventory_items_changed)
	inventory_grid.refresh_from_player()

func _inventory_filter(item: FW_Item) -> bool:
	if item == null:
		return false
	if item.item_type == FW_Item.ITEM_TYPE.CONSUMABLE and _is_consumable_slotted(item):
		return false
	return true

func _on_inventory_items_changed(items: Array[FW_Item]) -> void:
	if items.size() > GDM.inventory_size:
		for index in range(GDM.inventory_size, items.size()):
			var overflow_item := items[index]
			if overflow_item:
				push_warning("Inventory overflow! Item cannot be displayed: " + str(overflow_item.name))
