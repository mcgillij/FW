extends RefCounted

class_name FW_EquipmentRarityManager

var config: FW_EquipmentConfig

func _init(equipment_config: FW_EquipmentConfig):
	config = equipment_config

func get_rarity_from_score(score: float) -> FW_Equipment.equipment_rarity:
	for rarity in FW_Equipment.equipment_rarity.values():
		var data = config.get_rarity_data(rarity)
		if score >= data.min_score and score <= data.get("max_score", data.min_score + 10):
			return rarity
	return FW_Equipment.equipment_rarity.COMMON

func get_target_score_for_rarity(rarity: FW_Equipment.equipment_rarity) -> int:
	return config.get_rarity_data(rarity).target_score

func get_rarity_weights(luck: float) -> Dictionary:
	var weights = {}
	for rarity in FW_Equipment.equipment_rarity.values():
		var data = config.get_rarity_data(rarity)
		weights[rarity] = data.weight

	var luck_factor = clampf(luck * 0.01, 0.0, 2.0)

	# Apply luck bonuses to higher rarities
	var luck_bonuses = {
		FW_Equipment.equipment_rarity.GOOD: 5.0,
		FW_Equipment.equipment_rarity.GREAT: 4.0,
		FW_Equipment.equipment_rarity.UNCOMMON: 3.0,
		FW_Equipment.equipment_rarity.RARE: 2.5,
		FW_Equipment.equipment_rarity.SPECIAL: 2.0,
		FW_Equipment.equipment_rarity.EXTRAORDINARY: 1.5,
		FW_Equipment.equipment_rarity.EPIC: 1.0,
		FW_Equipment.equipment_rarity.LEGENDARY: 0.5,
		FW_Equipment.equipment_rarity.MYTHIC: 0.2,
		FW_Equipment.equipment_rarity.ARTIFACT: 0.1,
		FW_Equipment.equipment_rarity.UNIQUE: 0.05
	}

	for rarity in luck_bonuses.keys():
		weights[rarity] += luck_factor * luck_bonuses[rarity]

	return weights

func weighted_random_rarity(weights: Dictionary) -> FW_Equipment.equipment_rarity:
	var total = 0.0
	for weight in weights.values():
		total += weight

	var random_value = randf() * total
	var cumulative = 0.0

	for rarity in weights.keys():
		cumulative += weights[rarity]
		if random_value <= cumulative:
			return rarity

	return FW_Equipment.equipment_rarity.COMMON

func calculate_gold_value(rarity: FW_Equipment.equipment_rarity) -> int:
	var base_value = 100
	var multiplier = config.get_rarity_data(rarity).gold_multiplier
	return int(base_value * multiplier)
