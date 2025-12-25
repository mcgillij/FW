extends Node

class_name FW_LootManager

var JUNK_ITEMS: Array[FW_Junk] = []
const CONSUMABLE_ITEMS = [preload("res://Item/Consumables/Resources/HealingPotion.tres"), preload("res://Item/Consumables/Resources/FirePotion.tres"), preload("res://Item/Consumables/Resources/ShieldPotion.tres"), preload("res://Item/Consumables/Resources/RainbowPotion.tres")]

func _ready() -> void:
	load_junk_items()
	FW_Debug.debug_log(["Loaded %d junk items" % JUNK_ITEMS.size()])

func load_junk_items() -> void:
	JUNK_ITEMS.clear()
	var dir := DirAccess.open("res://Item/Junk/Resources")
	var default_texture := preload("res://Item/Junk/Images/gold_coins.png")
	if dir:
		dir.list_dir_begin()
		var filename := dir.get_next()
		while filename != "":
			if filename.ends_with(".tres") or filename.ends_with(".res"):
				var path := "res://Item/Junk/Resources/%s" % filename
				var resource := ResourceLoader.load(path)
				if resource and resource is FW_Junk:
					var junk := resource as FW_Junk
					# Ensure resource has a texture (fallback to gold coins)
					if junk.texture == null:
						junk.texture = default_texture
					JUNK_ITEMS.append(junk)
			filename = dir.get_next()
		dir.list_dir_end()

func list_junk_items() -> Array:
	var names := []
	for r in JUNK_ITEMS:
		names.append(r.name)
	return names

# Debug helper: give player some random junk items for testing
func give_random_junk_to_player(count: int = 5) -> void:
	if JUNK_ITEMS.size() == 0:
		load_junk_items()
	if JUNK_ITEMS.size() == 0:
		FW_Debug.debug_log(["No junk items loaded to give to player."])
		return
	for i in range(count):
		var src: FW_Junk = JUNK_ITEMS[randi() % JUNK_ITEMS.size()] as FW_Junk
		var item: FW_Junk = src.duplicate() as FW_Junk
		GDM.player.inventory.append(item)
		EventBus.inventory_item_added.emit(item)
	FW_Debug.debug_log(["Added %d junk items to player inventory" % count])

const BASE_GOLD_REWARDS = {
	FW_Monster_Resource.monster_type.SCRUB: 10,
	FW_Monster_Resource.monster_type.GRUNT: 25,
	FW_Monster_Resource.monster_type.ELITE: 50,
	FW_Monster_Resource.monster_type.BOSS: 100,
}
const LUCK_SCALING_FACTOR = 0.01  # e.g., 1% bonus per luck point
const GOLD_VARIANCE = 0.2  # ±20% random variance

func generate_loot_for_blacksmith() -> Array[FW_Equipment]:
	var luck: float = GDM.player.stats.get_stat("luck")
	var eg = FW_EquipmentGeneratorV2.new()
	return eg.generate_loot_for_blacksmith(luck)

func generate_loot_for_victory(monster: FW_Monster_Resource) -> Array[FW_Item]:
	var luck: float = GDM.player.stats.get_stat("luck")
	var eg = FW_EquipmentGeneratorV2.new()
	var loot: Array[FW_Item] = []
	var equipment_drop_chance = 0.03 + (luck * LUCK_SCALING_FACTOR)
	if randf() < equipment_drop_chance:
		loot.append_array(eg.generate_loot_for_victory(luck))
	if loot.size() == 0:
		if JUNK_ITEMS.is_empty():
			load_junk_items()
		if not JUNK_ITEMS.is_empty():
			var src: FW_Junk = JUNK_ITEMS[randi() % JUNK_ITEMS.size()]
			loot.append(src.duplicate() as FW_Junk)
		else:
			push_warning("LootManager: No junk items loaded; skipping junk fallback drop")

	# Add chance for consumable drops based on luck and monster type
	var consumable_drop_chance = calculate_consumable_drop_chance(luck, monster.type)
	if randf() < consumable_drop_chance:
		var consumable = generate_consumable_loot(monster.type)
		if consumable:
			loot.append(consumable)

	var quest_items = get_quest_item_rewards()
	if quest_items.size() > 0:
		loot.append(quest_items[0])

	# Add gold reward as a display item
	var gold_amount = calculate_gold_reward(luck, monster.type)
	if gold_amount > 0:
		loot.append(create_gold_item(gold_amount))

	return loot

func sweet_loot() -> FW_Equipment:
	var eg = FW_EquipmentGeneratorV2.new()
	return eg.generate_equipment_of_rarity(FW_Equipment.equipment_rarity.EPIC)

func get_quest_item_rewards() -> Array[FW_QuestItem]:
	# this should check the active quests and return the possible items that we need to collect
	var needed : Array[FW_QuestItem] = []
	for q in GDM.player.quests:
		if !q.completed:
			needed.append_array(QuestManager.get_required_quest_items_for_quest(q))
	return needed

func inventory_has_space() -> bool:
	return GDM.player.inventory.size() < GDM.inventory_size

# Calculates gold reward based on luck and monster difficulty.
# Returns an int (clamped to >= 0).
func calculate_gold_reward(luck: float, monster_type: FW_Monster_Resource.monster_type) -> int:
	var base_gold = BASE_GOLD_REWARDS.get(monster_type, 10)  # Default to SCRUB
	var luck_bonus = base_gold * luck * LUCK_SCALING_FACTOR
	var total_gold = base_gold + luck_bonus
	var variance = total_gold * GOLD_VARIANCE * (randf() * 2 - 1)  # Random ±variance
	return maxi(0, int(total_gold + variance))  # Ensure non-negative

# Creates a new Junk item representing gold with the given amount.
# Duplicates GoldCoins.tres and sets gold_value and item_type.
func create_gold_item(amount: int) -> FW_Junk:
	var gold_item = preload("res://Item/Junk/Resources/GoldCoins.tres").duplicate() as FW_Junk
	gold_item.gold_value = amount
	gold_item.item_type = FW_Item.ITEM_TYPE.MONEY
	return gold_item

# Calculate consumable drop chance based on luck and monster difficulty
func calculate_consumable_drop_chance(luck: float, monster_type: FW_Monster_Resource.monster_type) -> float:
	var base_chance = {
		FW_Monster_Resource.monster_type.SCRUB: 0.25,     # 15% base chance
		FW_Monster_Resource.monster_type.GRUNT: 0.35,     # 25% base chance
		FW_Monster_Resource.monster_type.ELITE: 0.50,     # 40% base chance
		FW_Monster_Resource.monster_type.BOSS: 0.65,      # 65% base chance
	}

	var chance = base_chance.get(monster_type, 0.25)  # Default to SCRUB
	var luck_bonus = luck * LUCK_SCALING_FACTOR  # 0.5% bonus per luck point
	return minf(0.75, chance + luck_bonus)  # Cap at 75%

# Generate a consumable item based on monster type
func generate_consumable_loot(_monster_type: FW_Monster_Resource.monster_type) -> FW_Consumable:
	if CONSUMABLE_ITEMS.is_empty():
		return null

	# For now, randomly select from available consumables
	# Later you can weight this based on monster type or add rarity system
	var consumable_resource = CONSUMABLE_ITEMS[randi() % CONSUMABLE_ITEMS.size()]
	return consumable_resource.duplicate() as FW_Consumable

func generate_random_consumable() -> FW_Consumable:
	if CONSUMABLE_ITEMS.is_empty():
		return null
	var index := randi() % CONSUMABLE_ITEMS.size()
	var consumable_resource = CONSUMABLE_ITEMS[index]
	return consumable_resource.duplicate() as FW_Consumable

# Generate a specific consumable by index (1-based for garden potions)
func generate_specific_consumable(index: int) -> FW_Consumable:
	if CONSUMABLE_ITEMS.is_empty() or index < 1 or index > CONSUMABLE_ITEMS.size():
		return null

	var consumable_resource = CONSUMABLE_ITEMS[index - 1]
	return consumable_resource.duplicate() as FW_Consumable

# Helper function for testing - generates guaranteed consumable loot
func generate_test_consumable_loot() -> Array[FW_Consumable]:
	var consumables: Array[FW_Consumable] = []
	for consumable_resource in CONSUMABLE_ITEMS:
		consumables.append(consumable_resource.duplicate() as FW_Consumable)
	return consumables

# Debug/cheat function to give player some healing potions for testing
func give_test_consumables_to_player(_count: int = 3) -> void:
	# Add one of each consumable type
	for consumable_resource in CONSUMABLE_ITEMS:
		var consumable = consumable_resource.duplicate() as FW_Consumable
		GDM.player.inventory.append(consumable)

	FW_Debug.debug_log(["Added one of each consumable type to player inventory"])

# Debug function to give player equipment that adds consumable slots
func give_consumable_slot_equipment() -> void:
	# Give player the Alchemist's Belt that adds 2 extra consumable slots
	var alchemist_belt = preload("res://Equipment/Resources/AlchemistBelt.tres")
	if alchemist_belt:
		GDM.player.inventory.append(alchemist_belt)
		FW_Debug.debug_log(["Added Alchemist's Belt to inventory - equip it to get +2 consumable slots!"])
	else:
		FW_Debug.debug_log(["Could not load Alchemist's Belt resource"])

	FW_Debug.debug_log(["Current consumable slots: %d" % GDM.player.get_max_consumable_slots()])

# Debug function to test slot reduction behavior
func test_slot_reduction() -> void:
	FW_Debug.debug_log(["=== Testing Consumable Slot Reduction ==="])

	# Give player some consumables
	give_test_consumables_to_player(5)

	# Give player equipment that adds slots
	give_consumable_slot_equipment()

	FW_Debug.debug_log(["1. Player should have consumables and extra slots now"])
	FW_Debug.debug_log(["2. Open inventory and place consumables in all available slots"])
	FW_Debug.debug_log(["3. Go to equipment screen and unequip the Alchemist's Belt"])
	FW_Debug.debug_log(["4. Return to inventory - displaced items should be moved to available slots or returned to inventory"])
	FW_Debug.debug_log(["5. Check console for messages about item displacement"])

func grant_loot_to_player(loot: Array) -> void:
	var did_change_inventory := false
	for item in loot:
		if item == null:
			continue
		if item.item_type == FW_Item.ITEM_TYPE.MONEY:
			# Add gold directly to player instead of inventory
			GDM.player.gold += item.gold_value
			EventBus.gain_gold.emit(item.gold_value)
			continue

		# Everything else goes into inventory
		GDM.player.inventory.append(item)
		did_change_inventory = true

		if item.item_type == FW_Item.ITEM_TYPE.CONSUMABLE:
			# Note: Consumables don't need to be saved to disk like equipment
			FW_Debug.debug_log(["Consumable added to inventory: ", item.name])
			EventBus.consumable_added.emit(item)
			continue

		# Update quest progress for collected items
		if item.item_type == FW_Item.ITEM_TYPE.QUEST:
			QuestManager.update_quest_progress(FW_QuestGoal.GOAL_TYPE.COLLECT, item, 1)

		if item.item_type == FW_Item.ITEM_TYPE.EQUIPMENT:
			GDM.save_equipment_to_disk(item)
			EventBus.equipment_added.emit(item)
		else:
			EventBus.inventory_item_added.emit(item)

	if did_change_inventory:
		EventBus.inventory_changed.emit()

# Optionally, handle UI panel instantiation here as well
func create_loot_panels(loot: Array, loot_item_panel: PackedScene, loot_panel_container: Node) -> void:
	for item in loot:
		var loot_panel = loot_item_panel.instantiate()
		loot_panel.populate_fields(item)
		loot_panel_container.add_child(loot_panel)
