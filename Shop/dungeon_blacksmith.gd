extends "res://Scripts/base_menu_panel.gd"

@export var tooltip_prefab: PackedScene
@export var floating_numbers_prefab: PackedScene
@export var tooltip_root: CanvasItem

const TOOLTIP_WIDTH := 350.0
const TOOLTIP_MARGIN := 20.0
const INVENTORY_ALLOWED_TYPES := [FW_Item.ITEM_TYPE.EQUIPMENT, FW_Item.ITEM_TYPE.JUNK]

var tooltip_timer: Timer

@onready var vendor_image: TextureRect = %vendor_image
@onready var vendor_name: Label = %vendor_name
@onready var vendor_description: Label = %vendor_description
@onready var vendor_inventory: GridContainer = %vendor_inventory
@onready var sell_area: GridContainer = %sell_area
@onready var player_money: Label = %player_money
@onready var inventory_node: GridContainer = %inventory
@onready var reroll_button: TextureButton = %reroll_button

# Store the level node when entering the blacksmith
var current_level_node: FW_LevelNode = null

var inventory_grid

func setup(character: FW_Character) -> void:

	# Store the current level node for completion handling
	current_level_node = GDM.current_info.level
	if not current_level_node:
		printerr("setup: Warning - no current level available when entering blacksmith")

	vendor_image.texture = character.texture
	vendor_name.text = character.name
	vendor_description.text = character.description
	SoundManager.wire_up_all_buttons()
	EventBus.gain_gold.connect(_on_gain_gold)
	# merchant sell slot
	player_money.text = str(GDM.player.gold) + " gp"
	var sell_slot = FW_VendorSellSlot.new()
	sell_slot.init(Vector2(190, 190))
	%sell_area.add_child(sell_slot)
	# init the ability inventory
	_configure_inventory_grid()
	load_gear()
	# init the vendor inventory
	load_vendor_loot()
	slide_in()

func _ready() -> void:
	if tooltip_root:
		tooltip_root.hide()

	# Create and configure the tooltip timer
	tooltip_timer = Timer.new()
	tooltip_timer.wait_time = 15.0
	tooltip_timer.one_shot = true
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	add_child(tooltip_timer)

	EventBus.trigger_blacksmith.connect(setup.bind(load("res://Characters/Blacksmith_MinnaSunderer.tres")))
	EventBus.blacksmith_completed.connect(_on_blacksmith_completed)

func load_vendor_loot(reroll: bool = false) -> void:
	# Clear previous vendor inventory if needed
	if reroll:
		GDM.world_state.blacksmith_loot.clear()
	for child in %vendor_inventory.get_children():
		child.queue_free()
	var loot_paths: Array[String] = []
	if GDM.world_state.blacksmith_loot.is_empty():
		var lm = FW_LootManager.new()
		var loot = lm.generate_loot_for_blacksmith()
		# Save each generated Equipment to disk and collect paths
		for eq in loot:
			var eq_path = GDM.save_equipment_to_disk(eq)
			loot_paths.append(eq_path)
		GDM.world_state.blacksmith_loot = loot_paths
	else:
		loot_paths = GDM.world_state.blacksmith_loot

	for eq_path in loot_paths:
		var slot = FW_VendorInventorySlot.new()
		slot.init(GDM.inventory_item_size, [FW_Item.ITEM_TYPE.EQUIPMENT])
		%vendor_inventory.add_child(slot)
		if eq_path:
			var item = ResourceLoader.load(eq_path)
			if item:
				var item_node = FW_EquipmentInventoryItem.new()
				item_node.init(item)
				item_node.tooltip_text = ""  # Disable built-in tooltip
				item_node.mouse_entered.connect(_on_item_mouse_entered.bind(item_node))
				item_node.mouse_exited.connect(_on_item_mouse_exited.bind(item_node))
				slot.add_child(item_node)

func load_gear() -> void:
	if inventory_grid:
		inventory_grid.refresh_from_player()

func clear_inventory() -> void:
	if inventory_grid:
		inventory_grid.refresh_from_player()

func _on_gain_gold(amount: int):
	if amount > 0:
		GDM.player.gold += amount
	SoundManager._player_random_money_sound()
	var current = floating_numbers_prefab.instantiate()
	current._gain_gold(amount)
	current.position.x = 700
	current.position.y = 550
	add_child(current)
	player_money.text = str(GDM.player.gold) + " gp"
	_update_reroll_button()

func _update_reroll_button():
	reroll_button.disabled = GDM.player.gold < 200

func _on_reroll_button_pressed():
	if GDM.player.gold >= 200:
		GDM.player.gold -= 200
		player_money.text = str(GDM.player.gold) + " gp"
		load_vendor_loot(true)
		_update_reroll_button()

func _on_back_button_pressed() -> void:
	_handle_blacksmith_completion()

func _exit_tree() -> void:
	# Clean up the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.stop()
		tooltip_timer.queue_free()
	if inventory_grid and is_instance_valid(inventory_grid):
		if inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
			inventory_grid.items_changed.disconnect(_on_inventory_items_changed)
	inventory_grid = null

func _handle_blacksmith_completion() -> void:
	"""Handle blacksmith completion and progression similar to events"""
	# Try to get the current level, fallback to stored level node
	var completed_node: FW_LevelNode = GDM.current_info.level
	if not completed_node:
		completed_node = current_level_node

	if not completed_node:
		printerr("_handle_blacksmith_completion: no level node available")
		# Fallback: just slide out without progression if no level context
		slide_out()
		return

	# Capture current world info
	var map_hash = GDM.current_info.world.world_hash

	# Mark node as cleared and update world state
	GDM.mark_node_cleared(map_hash, completed_node.level_hash, true)
	completed_node.cleared = true

	# Update path history
	GDM.world_state.update_path_history(
		map_hash,
		completed_node.level_depth,
		completed_node
	)

	# Check if this is the final level
	var is_final_level = completed_node.level_depth == GDM.current_info.level_to_generate["max_depth"]
	if is_final_level:
		GDM.world_state.update_completed(map_hash, true)

	# Update current level
	var new_level := GDM.world_state.get_current_level(map_hash) + 1
	GDM.world_state.update_current_level(map_hash, new_level)

	# Save state
	GDM.vs_save()

	# Clear action flags
	GDM.player_action_in_progress = false
	GDM.skill_check_in_progress = false

	# Slide out and emit completion
	slide_out()

	# Emit completion signal deferred to avoid race conditions
	call_deferred("_emit_blacksmith_completion", completed_node)

func _emit_blacksmith_completion(node: FW_LevelNode) -> void:
	"""Emit blacksmith completion signal"""
	EventBus.level_completed.emit(node)

func _on_blacksmith_completed() -> void:
	"""Handle external blacksmith completion signal if needed"""
	pass

# Tooltip functions
func _on_tooltip_timer_timeout() -> void:
	if tooltip_root:
		tooltip_root.hide()
		# Safe cleanup - remove all children
		for i in tooltip_root.get_children():
			if is_instance_valid(i):
				i.queue_free()

func _on_item_mouse_entered(item: FW_InventoryItem) -> void:
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

	# Position tooltip at top-right of the screen
	var viewport_size = get_viewport().get_visible_rect().size
	var new_pos = Vector2(max(0, viewport_size.x - TOOLTIP_WIDTH - TOOLTIP_MARGIN), TOOLTIP_MARGIN)
	tooltip_root.global_position = new_pos

	# Add the loot prefab to show item details
	if tooltip_prefab:
		var loot = tooltip_prefab.instantiate()
		loot.populate_fields(item.data)
		tooltip_root.add_child(loot)

	# Start/restart the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.start()

func _on_item_mouse_exited(_item: FW_InventoryItem) -> void:
	# Tooltip persists until timer expires or replaced
	pass

func _on_inventory_items_changed(_items: Array[FW_Item]) -> void:
	_update_reroll_button()

func _configure_inventory_grid() -> void:
	if not is_instance_valid(inventory_node):
		return
	if inventory_node.has_method("refresh_from_player"):
		inventory_grid = inventory_node
	else:
		return
	if inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
		inventory_grid.items_changed.disconnect(_on_inventory_items_changed)
	inventory_grid.allowed_item_types = INVENTORY_ALLOWED_TYPES.duplicate()
	inventory_grid.exclude_equipped = true
	inventory_grid.exclude_quest_items = true
	inventory_grid.set_tooltip_callbacks(_on_item_mouse_entered, _on_item_mouse_exited)
	inventory_grid.items_changed.connect(_on_inventory_items_changed)
	inventory_grid.refresh_from_player()
