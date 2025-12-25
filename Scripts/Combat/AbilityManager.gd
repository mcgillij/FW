extends RefCounted
class_name FW_AbilityManager

# Centralized ability checking and validation

static func check_ability_usable(ability: FW_Ability, mana_pool: Dictionary, cooldown_manager) -> bool:
	var on_cooldown = cooldown_manager.abilities.has(["monster", ability.name])
	if on_cooldown:
		return false

	var has_enough_mana = check_sufficient_mana(ability.cost, mana_pool)
	if not has_enough_mana:
		return false

	return true

static func check_sufficient_mana(cost: Dictionary, mana_pool: Dictionary) -> bool:
	for color in cost.keys():
		if mana_pool[color] < cost[color]:
			return false
	return true

static func filter_usable_abilities(abilities: Array[FW_Ability], mana_pool: Dictionary, cooldown_manager) -> Array[FW_Ability]:
	return abilities.filter(func(ability): return check_ability_usable(ability, mana_pool, cooldown_manager))

static func get_ability_names(abilities: Array[FW_Ability]) -> Array[String]:
	var names: Array[String] = []
	for ability in abilities:
		names.append(ability.name if ability else "null")
	return names
