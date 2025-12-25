extends Node

#class_name DoghouseManager
enum DOGHOUSE_STATE {
	LOCKED,
	UNLOCKED
}

enum FORGE_STATE {
	LOCKED,
	UNLOCKED
}

enum GARDEN_STATE {
	LOCKED,
	UNLOCKED
}

const DOGHOUSE_UNLOCK_COST = 5000
const FORGE_UNLOCK_COST = 1000
const GARDEN_UNLOCK_COST = 2000

const dog_house_images := {
	"normal": "res://WorldMap/Images/doghouse.png",
	"forge": "res://WorldMap/Images/doghouse_forge.png",
	"garden": "res://WorldMap/Images/doghouse_garden.png",
	"forge_and_garden": "res://WorldMap/Images/doghouse_garden_and_forge.png"
}

var doghouse_state: DOGHOUSE_STATE = DOGHOUSE_STATE.LOCKED
var forge_state: FORGE_STATE = FORGE_STATE.LOCKED
var garden_state: GARDEN_STATE = GARDEN_STATE.LOCKED

# Forge item list (names used as keys in UnlockManager)
const FORGE_ITEMS := ["weapon", "harness", "helmet", "bracers", "collar", "tailguard"]

# Garden potions indices (1-based for UI)
const GARDEN_POTIONS := [1, 2, 3]

# Base cost for individual forge/garden unlocks
const ITEM_BASE_COST = 100

# Cached per-item unlocked states (kept for quick access)
var forge_item_states := {}
var garden_potion_states := {}

func _ready():
	# Don't load state here, wait for player to be loaded
	pass

func load_state():
	_load_state()

func _load_state():
	# Load from UnlockManager
	doghouse_state = DOGHOUSE_STATE.UNLOCKED if UnlockManager.is_doghouse_unlocked() else DOGHOUSE_STATE.LOCKED
	forge_state = FORGE_STATE.UNLOCKED if UnlockManager.is_forge_unlocked() else FORGE_STATE.LOCKED
	garden_state = GARDEN_STATE.UNLOCKED if UnlockManager.is_garden_unlocked() else GARDEN_STATE.LOCKED

	# Load per-item states from UnlockManager
	for item in FORGE_ITEMS:
		forge_item_states[item] = UnlockManager.is_forge_item_unlocked(item)

	for idx in GARDEN_POTIONS:
		garden_potion_states[idx] = UnlockManager.is_garden_potion_unlocked(idx)

func _save_state():
	# No longer save to player, handled by UnlockManager
	pass

func is_unlocked() -> bool:
	return doghouse_state == DOGHOUSE_STATE.UNLOCKED

func can_afford_unlock() -> bool:
	return GDM.player.gold >= DOGHOUSE_UNLOCK_COST

func get_menu_entries() -> Array[FW_MenuEntryData]:
	var entries: Array[FW_MenuEntryData] = []

	match doghouse_state:
		DOGHOUSE_STATE.LOCKED:
			var unlock_entry := FW_MenuEntryData.new()
			unlock_entry.key = "UNLOCK"
			unlock_entry.label_override = "Unlock - " + str(DOGHOUSE_UNLOCK_COST) + " gold"
			unlock_entry.icon_path = "res://Item/Junk/Images/gold_coins.png"
			entries.append(unlock_entry)
		DOGHOUSE_STATE.UNLOCKED:
			var home_entry := FW_MenuEntryData.new()
			home_entry.key = "DOGHOUSE"
			home_entry.label_override = "Home"
			entries.append(home_entry)

	return entries

func unlock_doghouse() -> bool:
	if doghouse_state == DOGHOUSE_STATE.UNLOCKED:
		return true  # Already unlocked

	if not can_afford_unlock():
		return false  # Can't afford

	# Deduct gold
	GDM.player.gold -= DOGHOUSE_UNLOCK_COST

	# Update state
	doghouse_state = DOGHOUSE_STATE.UNLOCKED
	UnlockManager.unlock_doghouse()

	# Emit signal for UI updates
	if has_node("/root/EventBus"):
		EventBus.emit_signal("doghouse_unlocked")

	return true

func get_DOGHOUSE_UNLOCK_COST() -> int:
	return DOGHOUSE_UNLOCK_COST

# Compatibility wrapper: older code expects get_unlock_cost()
func get_unlock_cost() -> int:
	return DOGHOUSE_UNLOCK_COST

func get_remaining_cost() -> int:
	if is_unlocked():
		return 0
	return max(0, DOGHOUSE_UNLOCK_COST - GDM.player.gold)

# Forge functions
func is_forge_unlocked() -> bool:
	return forge_state == FORGE_STATE.UNLOCKED

func is_forge_item_unlocked(item_name: String) -> bool:
	return forge_item_states.get(item_name, false)

func can_afford_forge_unlock() -> bool:
	return GDM.player.gold >= FORGE_UNLOCK_COST

func get_forge_item_cost(item_name: String) -> int:
	# cost scales by 2^index where index is position in FORGE_ITEMS
	var idx = FORGE_ITEMS.find(item_name)
	if idx == -1:
		return ITEM_BASE_COST
	return ITEM_BASE_COST * int(pow(2, idx))

func can_afford_forge_item(item_name: String) -> bool:
	return GDM.player.gold >= get_forge_item_cost(item_name)

func unlock_forge_item(item_name: String) -> bool:
	if is_forge_item_unlocked(item_name):
		return true
	var cost = get_forge_item_cost(item_name)
	if GDM.player.gold < cost:
		return false
	GDM.player.gold -= cost
	forge_item_states[item_name] = true
	UnlockManager.unlock_forge_item(item_name)
	if has_node("/root/EventBus"):
		EventBus.emit_signal("forge_item_unlocked", item_name)
	return true

func has_locked_forge_items() -> bool:
	for item in FORGE_ITEMS:
		if not is_forge_item_unlocked(item):
			return true
	return false

func get_next_locked_forge_item() -> String:
	for item in FORGE_ITEMS:
		if not is_forge_item_unlocked(item):
			return item
	return ""

func get_next_forge_item_cost() -> int:
	var item = get_next_locked_forge_item()
	if item == "":
		return 0
	return get_forge_item_cost(item)

func unlock_next_forge_item() -> bool:
	var item = get_next_locked_forge_item()
	if item == "":
		return false
	return unlock_forge_item(item)

func unlock_forge() -> bool:
	if forge_state == FORGE_STATE.UNLOCKED:
		return true  # Already unlocked

	if not can_afford_forge_unlock():
		return false  # Can't afford

	# Deduct gold
	GDM.player.gold -= FORGE_UNLOCK_COST

	# Update state
	forge_state = FORGE_STATE.UNLOCKED
	UnlockManager.unlock_forge()

	# Emit signal for UI updates
	if has_node("/root/EventBus"):
		EventBus.emit_signal("forge_unlocked")

	return true

func get_forge_unlock_cost() -> int:
	return FORGE_UNLOCK_COST

func get_forge_remaining_cost() -> int:
	if is_forge_unlocked():
		return 0
	return max(0, FORGE_UNLOCK_COST - GDM.player.gold)

# Garden functions
func is_garden_unlocked() -> bool:
	return garden_state == GARDEN_STATE.UNLOCKED

func is_garden_potion_unlocked(index: int) -> bool:
	return garden_potion_states.get(index, false)

func can_afford_garden_unlock() -> bool:
	return GDM.player.gold >= GARDEN_UNLOCK_COST

func get_garden_potion_cost(index: int) -> int:
	# index is 1-based; scale by 2^(index-1)
	return ITEM_BASE_COST * int(pow(2, index - 1))

func can_afford_garden_potion(index: int) -> bool:
	return GDM.player.gold >= get_garden_potion_cost(index)

func unlock_garden_potion(index: int) -> bool:
	if is_garden_potion_unlocked(index):
		return true
	var cost = get_garden_potion_cost(index)
	if GDM.player.gold < cost:
		return false
	GDM.player.gold -= cost
	garden_potion_states[index] = true
	UnlockManager.unlock_garden_potion(index)
	if has_node("/root/EventBus"):
		EventBus.emit_signal("garden_potion_unlocked", index)
	return true

func has_locked_garden_potions() -> bool:
	for idx in GARDEN_POTIONS:
		if not is_garden_potion_unlocked(idx):
			return true
	return false

func get_next_locked_garden_potion() -> int:
	for idx in GARDEN_POTIONS:
		if not is_garden_potion_unlocked(idx):
			return idx
	return 0

func get_next_garden_potion_cost() -> int:
	var idx = get_next_locked_garden_potion()
	if idx == 0:
		return 0
	return get_garden_potion_cost(idx)

func unlock_next_garden_potion() -> bool:
	var idx = get_next_locked_garden_potion()
	if idx == 0:
		return false
	return unlock_garden_potion(idx)

func unlock_garden() -> bool:
	if garden_state == GARDEN_STATE.UNLOCKED:
		return true  # Already unlocked

	if not can_afford_garden_unlock():
		return false  # Can't afford

	# Deduct gold
	GDM.player.gold -= GARDEN_UNLOCK_COST

	# Update state
	garden_state = GARDEN_STATE.UNLOCKED
	UnlockManager.unlock_garden()

	# Emit signal for UI updates
	if has_node("/root/EventBus"):
		EventBus.emit_signal("garden_unlocked")

	return true

func get_garden_unlock_cost() -> int:
	return GARDEN_UNLOCK_COST

func get_garden_remaining_cost() -> int:
	if is_garden_unlocked():
		return 0
	return max(0, GARDEN_UNLOCK_COST - GDM.player.gold)
