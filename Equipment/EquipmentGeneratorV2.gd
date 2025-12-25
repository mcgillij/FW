extends RefCounted

class_name FW_EquipmentGeneratorV2

var factory: FW_EquipmentFactory

func _init():
	factory = FW_EquipmentFactory.new()

# Main public interface - simplified and clean
func generate_equipment(desired_rarity = null) -> FW_Equipment:
	return factory.create_equipment(desired_rarity)

func generate_equipment_of_type(type: FW_Equipment.equipment_types, desired_rarity = null) -> FW_Equipment:
	return factory.create_equipment_of_type(type, desired_rarity)

func generate_equipment_with_luck(luck: float) -> FW_Equipment:
	return factory.create_equipment_with_luck(luck)

func generate_random_equipment() -> FW_Equipment:
	return factory.create_random_equipment()

# Convenience methods for specific use cases
func generate_equipment_of_rarity(rarity: FW_Equipment.equipment_rarity) -> FW_Equipment:
	return generate_equipment(rarity)

func generate_loot_for_blacksmith(luck: float = 0.0) -> Array[FW_Equipment]:
	var blacksmith_inventory_slots := 4
	var loot: Array[FW_Equipment] = []

	for i in range(blacksmith_inventory_slots):
		var item = generate_equipment_with_luck(luck)
		if item:
			loot.append(item)

	return loot

func generate_loot_for_victory(luck: float = 0.0) -> Array[FW_Item]:
	var loot: Array[FW_Item] = []
	var base_chance := 0.5 # 50% base chance to get loot
	var luck_bonus = luck * 0.01 # Convert luck to percentage
	var final_chance = clampf(base_chance + luck_bonus, 0.0, 0.95)

	if randf() < final_chance:
		var item = generate_equipment_with_luck(luck)
		if item:
			loot.append(item)

	return loot
