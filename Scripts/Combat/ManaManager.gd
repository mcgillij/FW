extends RefCounted
class_name FW_ManaManager

# Centralized mana management for both player and monster

static func check_sufficient_mana(cost: Dictionary, mana_pool: Dictionary) -> bool:
	for color in cost.keys():
		if mana_pool[color] < cost[color]:
			return false
	return true

static func calculate_mana_bonus(base_mana: Dictionary, bonus_mana: Dictionary) -> void:
	for color in bonus_mana.keys():
		base_mana[color] = base_mana.get(color, 0) + bonus_mana[color]

static func clamp_mana_to_max(mana_dict: Dictionary, max_mana: Dictionary) -> void:
	for key in mana_dict.keys():
		mana_dict[key] = clampi(mana_dict[key], 0, max_mana[key])

static func has_positive_values(mana_dict: Dictionary) -> bool:
	return mana_dict.values().any(func(val): return val > 0)

static func get_player_max_mana() -> Dictionary:
	return GDM.player.stats.calculate_max_mana()

static func get_monster_max_mana() -> Dictionary:
	return {"red": 100, "blue": 100, "green": 100, "orange": 100, "pink": 100}
