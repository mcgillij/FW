extends CanvasLayer

@onready var forge_container: HBoxContainer = %forge_container
@onready var garden_container: HBoxContainer = %garden_container
@onready var doghouse_image: TextureRect = %doghouse_image
@export var loot_screen: CanvasLayer

# Forge Buttons
@onready var weapon_button: TextureButton = %weapon_button
@onready var harness_button: TextureButton = %harness_button
@onready var helmet_button: TextureButton = %helmet_button
@onready var bracers_button: TextureButton = %bracers_button
@onready var collar_button: TextureButton = %collar_button
@onready var tailguard_button: TextureButton = %tailguard_button
# Garden Buttons
@onready var potion_button_1: TextureButton = %potion_button1
@onready var potion_button_2: TextureButton = %potion_button2
@onready var potion_button_3: TextureButton = %potion_button3

# Collections (populated in _ready)
var forge_buttons: Dictionary = {}
var potion_buttons: Array = []

# Mapping from forge item names to equipment types for generation
const FORGE_ITEM_TYPES = {
	"weapon": FW_Equipment.equipment_types.WEAPON,
	"harness": FW_Equipment.equipment_types.HARNESS,
	"helmet": FW_Equipment.equipment_types.HAT,
	"bracers": FW_Equipment.equipment_types.BRACERS,
	"collar": FW_Equipment.equipment_types.COLLAR,
	"tailguard": FW_Equipment.equipment_types.TAIL
}

#unlock buttons
@onready var forge_unlock_button: Button = %forge_unlock_button
@onready var garden_unlock_button: Button = %garden_unlock_button
@onready var gear_unlock_button: Button = %gear_unlock_button
@onready var potion_unlock_button: Button = %potion_unlock_button

func _ready() -> void:
	SoundManager.wire_up_all_buttons()
	# Build button mappings programmatically based on manager constants.
	# This keeps the UI in sync with DoghouseManager.FORGE_ITEMS / GARDEN_POTIONS
	forge_buttons.clear()
	for item_name in DoghouseManager.FORGE_ITEMS:
		var node_name = item_name + "_button"
		var btn_ref: TextureButton = null
		if has_node(node_name):
			btn_ref = get_node(node_name)
		else:
			# fallback to onready vars if the node isn't a direct child
			match item_name:
				"weapon": btn_ref = weapon_button
				"harness": btn_ref = harness_button
				"helmet": btn_ref = helmet_button
				"bracers": btn_ref = bracers_button
				"collar": btn_ref = collar_button
				"tailguard": btn_ref = tailguard_button
				_:
					btn_ref = null
		if btn_ref != null:
			forge_buttons[item_name] = btn_ref

	# Potion buttons in index order (index 0 -> potion 1)
	potion_buttons.clear()
	for idx in DoghouseManager.GARDEN_POTIONS:
		var node_name = "potion_button" + str(idx)
		var pbtn: TextureButton = null
		if has_node(node_name):
			pbtn = get_node(node_name)
		else:
			# fallback to onready vars
			match idx:
				1: pbtn = potion_button_1
				2: pbtn = potion_button_2
				3: pbtn = potion_button_3
				_: pbtn = null
		if pbtn != null:
			potion_buttons.append(pbtn)

	_wire_buttons()

	# Ensure manager state is loaded before we update the UI
	DoghouseManager.load_state()

	# Connect to global unlock signals so the UI updates when things change
	if has_node("/root/EventBus"):
		EventBus.forge_unlocked.connect(update_ui)
		EventBus.garden_unlocked.connect(update_ui)
		EventBus.doghouse_unlocked.connect(update_ui)
		# item-level signals
		EventBus.forge_item_unlocked.connect(update_ui)
		EventBus.garden_potion_unlocked.connect(update_ui)

	# Connect unlock button signals
	forge_unlock_button.pressed.connect(_on_forge_unlock_pressed)
	garden_unlock_button.pressed.connect(_on_garden_unlock_pressed)
	gear_unlock_button.pressed.connect(_on_gear_unlock_pressed)
	potion_unlock_button.pressed.connect(_on_potion_unlock_pressed)

	# Connect loot screen back button
	#loot_screen.back_button.connect(_on_loot_screen_back_button)

	# Initial UI pass (after buttons wired and state loaded)
	update_ui()

func update_ui() -> void:
	update_button_texts()
	update_visibilities()
	update_button_states()
	update_doghouse_image()

func update_button_states() -> void:
	if not DoghouseManager.is_forge_unlocked():
		forge_unlock_button.disabled = not DoghouseManager.can_afford_forge_unlock()
	if not DoghouseManager.is_garden_unlocked():
		garden_unlock_button.disabled = not DoghouseManager.can_afford_garden_unlock()

	# Gear unlock (batch) button state
	if DoghouseManager.has_locked_forge_items():
		var next_cost = DoghouseManager.get_next_forge_item_cost()
		gear_unlock_button.disabled = GDM.player.gold < next_cost or not DoghouseManager.is_forge_unlocked()
	else:
		gear_unlock_button.disabled = true

	# Potion unlock (batch) button state
	if DoghouseManager.has_locked_garden_potions():
		var next_p_cost = DoghouseManager.get_next_garden_potion_cost()
		potion_unlock_button.disabled = GDM.player.gold < next_p_cost or not DoghouseManager.is_garden_unlocked()
	else:
		potion_unlock_button.disabled = true

	# Update forge item buttons via collection
	for item_name in forge_buttons.keys():
		var btn = forge_buttons[item_name]
		if btn == null:
			continue
		var unlocked = DoghouseManager.is_forge_unlocked() and DoghouseManager.is_forge_item_unlocked(item_name)
		var pressed = item_name in GDM.player.pressed_forge_items
		var enabled = unlocked and not pressed
		_apply_button_state(btn, enabled, pressed)

	# Update potion buttons via collection (potion index is i+1)
	for i in range(potion_buttons.size()):
		var btnp = potion_buttons[i]
		if btnp == null:
			continue
		var idx = i + 1
		var unlocked_p = DoghouseManager.is_garden_unlocked() and DoghouseManager.is_garden_potion_unlocked(idx)
		var pressed_p = idx in GDM.player.pressed_garden_potions
		var enabled_p = unlocked_p and not pressed_p
		_apply_button_state(btnp, enabled_p, pressed_p)

func _apply_button_state(btn: TextureButton, enabled: bool, pressed: bool = false) -> void:
	# Centralizes disabled flag and tween modulate behavior
	btn.disabled = not enabled
	if btn.disabled:
		var dim_color = FW_UIUtils.PRESSED_COLOR if pressed else FW_UIUtils.DIMMED_COLOR
		FW_UIUtils.tween_modulate(self, btn, dim_color)
	else:
		FW_UIUtils.tween_modulate(self, btn, FW_UIUtils.NORMAL_COLOR)

func _wire_buttons() -> void:
	# Wire up signals programmatically (keeps code DRY and makes adding/removing items easier)
	for item_name in forge_buttons.keys():
		var btn: TextureButton = forge_buttons[item_name]
		btn.pressed.connect(Callable(self, "_on_forge_item_pressed").bind(item_name))
		btn.mouse_entered.connect(Callable(self, "_on_item_mouse_enter").bind(btn))
		btn.mouse_exited.connect(Callable(self, "_on_item_mouse_exit").bind(btn))

	for i in range(potion_buttons.size()):
		var btnp: TextureButton = potion_buttons[i]
		btnp.pressed.connect(Callable(self, "_on_garden_potion_pressed").bind(i + 1))
		btnp.mouse_entered.connect(Callable(self, "_on_item_mouse_enter").bind(btnp))
		btnp.mouse_exited.connect(Callable(self, "_on_item_mouse_exit").bind(btnp))

func update_doghouse_image() -> void:
	var key = "normal"
	if DoghouseManager.is_forge_unlocked() and DoghouseManager.is_garden_unlocked():
		key = "forge_and_garden"
	elif DoghouseManager.is_forge_unlocked():
		key = "forge"
	elif DoghouseManager.is_garden_unlocked():
		key = "garden"
	doghouse_image.texture = load(DoghouseManager.dog_house_images[key])

func update_button_texts() -> void:
	forge_unlock_button.text = "Unlock Forge - " + str(DoghouseManager.get_forge_unlock_cost()) + " gold"
	garden_unlock_button.text = "Unlock Garden - " + str(DoghouseManager.get_garden_unlock_cost()) + " gold"

	# Update batch unlock buttons' labels to show next item cost or hide when none remain
	if DoghouseManager.is_forge_unlocked() and DoghouseManager.has_locked_forge_items():
		gear_unlock_button.visible = true
		var next_item_name = DoghouseManager.get_next_locked_forge_item()
		gear_unlock_button.text = "Unlock " + next_item_name.capitalize() + " - " + str(DoghouseManager.get_next_forge_item_cost()) + " gold"
	else:
		gear_unlock_button.visible = false

	if DoghouseManager.is_garden_unlocked() and DoghouseManager.has_locked_garden_potions():
		potion_unlock_button.visible = true
		var next_p_idx = DoghouseManager.get_next_locked_garden_potion()
		potion_unlock_button.text = "Unlock Potion " + str(next_p_idx) + " - " + str(DoghouseManager.get_next_garden_potion_cost()) + " gold"
	else:
		potion_unlock_button.visible = false

# Tooltips removed in favor of batch unlock buttons that show costs on Steam Deck

func update_visibilities() -> void:
	forge_container.visible = DoghouseManager.is_forge_unlocked()
	garden_container.visible = DoghouseManager.is_garden_unlocked()
	forge_unlock_button.visible = not DoghouseManager.is_forge_unlocked()
	garden_unlock_button.visible = not DoghouseManager.is_garden_unlocked()

func _on_forge_unlock_pressed() -> void:
	if DoghouseManager.unlock_forge():
		update_ui()

func _on_garden_unlock_pressed() -> void:
	if DoghouseManager.unlock_garden():
		update_ui()

func _on_gear_unlock_pressed() -> void:
	if DoghouseManager.unlock_next_forge_item():
		update_ui()

func _on_potion_unlock_pressed() -> void:
	if DoghouseManager.unlock_next_garden_potion():
		update_ui()

func _on_forge_item_pressed(item_name: String) -> void:
	# Check if already pressed this run
	if item_name in GDM.player.pressed_forge_items:
		return  # Already generated loot for this item

	# Generate equipment of the corresponding type
	var equipment_type = FORGE_ITEM_TYPES.get(item_name, FW_Equipment.equipment_types.WEAPON)
	var eg = FW_EquipmentGeneratorV2.new()
	var item = eg.generate_equipment_of_type(equipment_type)

	# Display the item on the loot screen
	loot_screen.show_single_loot(item)
	loot_screen.slide_in()

	# Grant the item to the player
	var lm = FW_LootManager.new()
	lm.grant_loot_to_player([item])

	# Mark as pressed to prevent re-generation
	GDM.player.pressed_forge_items.append(item_name)

	# Save the game state to prevent loot farming
	GDM.vs_save()

	# Update UI if needed
	update_ui()

func _on_garden_potion_pressed(_index: int) -> void:
	# Check if already pressed this run
	if _index in GDM.player.pressed_garden_potions:
		return  # Already generated loot for this potion

	# Generate a random consumable
	var lm = FW_LootManager.new()
	var item = lm.generate_consumable_loot(FW_Monster_Resource.monster_type.SCRUB)  # Type doesn't matter for random

	if item == null:
		push_warning("Failed to generate consumable")
		return

	# Display the item on the loot screen
	loot_screen.show_single_loot(item)
	loot_screen.slide_in()

	# Grant the item to the player
	lm.grant_loot_to_player([item])

	# Mark as pressed to prevent re-generation
	GDM.player.pressed_garden_potions.append(_index)

	# Save the game state to prevent loot farming
	GDM.vs_save()

	# Update UI if needed
	update_ui()

func _set_button_modulate(btn: TextureButton) -> void:
	# Deprecated: we now use UIUtils tween_modulate for smooth transitions
	if btn.disabled:
		FW_UIUtils.tween_modulate(self, btn, FW_UIUtils.DIMMED_COLOR)
	else:
		FW_UIUtils.tween_modulate(self, btn, FW_UIUtils.NORMAL_COLOR)

func _on_item_mouse_enter(btn: TextureButton) -> void:
	# Apply a subtle dim on hover for enabled buttons
	if not btn.disabled:
		FW_UIUtils.tween_modulate(self, btn, FW_UIUtils.HOVER_COLOR)

func _on_item_mouse_exit(btn: TextureButton) -> void:
	# Restore normal modulate for enabled buttons; keep disabled dim
	if not btn.disabled:
		FW_UIUtils.tween_modulate(self, btn, FW_UIUtils.NORMAL_COLOR)

func _on_back_button_pressed() -> void:
	ScreenRotator.change_scene("res://WorldMap/world_map.tscn")

func _on_loot_screen_back_button() -> void:
	loot_screen.slide_out()
