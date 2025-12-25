extends "res://Scripts/base_menu_panel.gd"

@export var tooltip_prefab: PackedScene
@export var floating_numbers_prefab: PackedScene
@export var tooltip_root: CanvasItem

const TOOLTIP_WIDTH := 350.0
const TOOLTIP_MARGIN := 20.0
const INVENTORY_ALLOWED_TYPES := [FW_Item.ITEM_TYPE.EQUIPMENT, FW_Item.ITEM_TYPE.JUNK, FW_Item.ITEM_TYPE.CONSUMABLE]

var tooltip_timer: Timer

@onready var vendor_image: TextureRect = %vendor_image
@onready var vendor_name: Label = %vendor_name
@onready var vendor_description: Label = %vendor_description
@onready var sell_area: GridContainer = %sell_area

@onready var player_money: Label = %player_money
@onready var inventory_node: GridContainer = %inventory

@export var parallax_bg: PackedScene

var inventory_grid

func setup(character: FW_Character) -> void:
	vendor_image.texture = character.texture
	vendor_name.text = character.name
	vendor_description.text = character.description

func _ready() -> void:
	var bg = parallax_bg.instantiate()
	add_child(bg)
	SoundManager.wire_up_all_buttons()
	if tooltip_root:
		tooltip_root.hide()

	# Create and configure the tooltip timer
	tooltip_timer = Timer.new()
	tooltip_timer.wait_time = 15.0
	tooltip_timer.one_shot = true
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	add_child(tooltip_timer)

	setup(GDM.npc_to_load)
	EventBus.gain_gold.connect(_on_gain_gold)
	# merchant sell slot
	player_money.text = str(GDM.player.gold) + " gp"
	var sell_slot = FW_VendorSellSlot.new()
	sell_slot.init(Vector2(190, 190))
	%sell_area.add_child(sell_slot)
	# init the ability inventory
	_configure_inventory_grid()
	load_gear()
	slide_in()

func load_gear() -> void:
	if inventory_grid:
		inventory_grid.refresh_from_player()

func _on_gain_gold(amount: int):
	if amount > 0:
		GDM.player.gold += amount
	SoundManager._player_random_money_sound()
	var current = floating_numbers_prefab.instantiate()
	current._gain_gold(amount)
	current.position.x = 700
	current.position.y = 350
	add_child(current)
	player_money.text = str(GDM.player.gold) + " gp"

func _on_back_button_pressed() -> void:
	GDM.vs_save()
	ScreenRotator.change_scene("res://WorldMap/world_map.tscn")

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

	# Position tooltip at top-right of the screen
	var viewport_size = get_viewport().get_visible_rect().size
	var new_pos = Vector2(max(0, viewport_size.x - TOOLTIP_WIDTH - TOOLTIP_MARGIN), TOOLTIP_MARGIN)
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

func _exit_tree() -> void:
	# Clean up the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.stop()
		tooltip_timer.queue_free()
	if inventory_grid and inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
		inventory_grid.items_changed.disconnect(_on_inventory_items_changed)
	inventory_grid = null

func _on_inventory_items_changed(_items: Array[FW_Item]) -> void:
	pass

func _configure_inventory_grid() -> void:
	if not is_instance_valid(inventory_node):
		return
	if not inventory_node.has_method("refresh_from_player"):
		return
	if inventory_grid and inventory_grid.items_changed.is_connected(_on_inventory_items_changed):
		inventory_grid.items_changed.disconnect(_on_inventory_items_changed)
	inventory_grid = inventory_node
	inventory_grid.allowed_item_types = INVENTORY_ALLOWED_TYPES.duplicate()
	inventory_grid.exclude_equipped = true
	inventory_grid.exclude_quest_items = true
	inventory_grid.set_tooltip_callbacks(_on_item_mouse_entered, _on_item_mouse_exited)
	inventory_grid.items_changed.connect(_on_inventory_items_changed)
	inventory_grid.refresh_from_player()
