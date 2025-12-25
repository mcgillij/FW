extends Resource

class_name FW_EquipmentConfig

# Centralized equipment configuration
@export var rarity_data: Dictionary = {}
@export var effect_scores: Dictionary = {}
@export var equipment_type_data: Dictionary = {}

func _init():
	_setup_rarity_data()
	_setup_effect_scores()
	_setup_equipment_type_data()

func _setup_rarity_data():
	rarity_data = {
		FW_Equipment.equipment_rarity.TERRIBLE: {"min_score": 0, "target_score": 5, "gold_multiplier": 0.5, "weight": 10},
		FW_Equipment.equipment_rarity.BAD: {"min_score": 10, "target_score": 15, "gold_multiplier": 0.75, "weight": 15},
		FW_Equipment.equipment_rarity.OK: {"min_score": 20, "target_score": 25, "gold_multiplier": 1.0, "weight": 20},
		FW_Equipment.equipment_rarity.COMMON: {"min_score": 30, "target_score": 35, "gold_multiplier": 1.25, "weight": 25},
		FW_Equipment.equipment_rarity.GOOD: {"min_score": 40, "target_score": 45, "gold_multiplier": 1.5, "weight": 20},
		FW_Equipment.equipment_rarity.GREAT: {"min_score": 50, "target_score": 55, "gold_multiplier": 1.75, "weight": 15},
		FW_Equipment.equipment_rarity.UNCOMMON: {"min_score": 60, "target_score": 65, "gold_multiplier": 2.0, "weight": 10},
		FW_Equipment.equipment_rarity.RARE: {"min_score": 70, "target_score": 75, "gold_multiplier": 2.5, "weight": 8},
		FW_Equipment.equipment_rarity.SPECIAL: {"min_score": 80, "target_score": 85, "gold_multiplier": 3.0, "weight": 5},
		FW_Equipment.equipment_rarity.EXTRAORDINARY: {"min_score": 90, "target_score": 95, "gold_multiplier": 4.0, "weight": 3},
		FW_Equipment.equipment_rarity.EPIC: {"min_score": 100, "target_score": 110, "gold_multiplier": 6.0, "weight": 2},
		FW_Equipment.equipment_rarity.LEGENDARY: {"min_score": 120, "target_score": 130, "gold_multiplier": 8.0, "weight": 1},
		FW_Equipment.equipment_rarity.MYTHIC: {"min_score": 140, "target_score": 150, "gold_multiplier": 10.0, "weight": 0.5},
		FW_Equipment.equipment_rarity.ARTIFACT: {"min_score": 160, "target_score": 170, "gold_multiplier": 15.0, "weight": 0.2},
		FW_Equipment.equipment_rarity.UNIQUE: {"min_score": 180, "target_score": 190, "gold_multiplier": 20.0, "weight": 0.1}
	}

func _setup_effect_scores():
	effect_scores = {
		"bark": 10, "reflex": 10, "alertness": 10, "vigor": 10, "enthusiasm": 10,
		"affinity_damage_bonus": 10, "hp": 0.5, "shields": 0.5, "critical_strike_chance": 10,
		"critical_strike_multiplier": 20, "evasion_chance": 20, "red_mana_bonus": 10,
		"blue_mana_bonus": 10, "green_mana_bonus": 10, "orange_mana_bonus": 10,
		"pink_mana_bonus": 10, "red_mana_max": 1, "blue_mana_max": 1, "green_mana_max": 1,
		"orange_mana_max": 1, "pink_mana_max": 1, "bomb_tile_bonus": 20,
		"cooldown_reduction": 20, "tenacity": 10, "luck": 1, "shield_recovery": 1,
		"lifesteal": 1, "damage_resistance": 30,
		"extra_consumable_slots": 20
	}
	_validate_effect_scores()

func _validate_effect_scores() -> void:
	# Defensive: ensure all scoring keys match canonical StatsManager stat keys.
	# We remove unknown entries to avoid silent 0-score bugs.
	var unknown_keys: Array[String] = []
	for key in effect_scores.keys():
		if not FW_StatsManager.STAT_NAMES.has(key):
			unknown_keys.append(str(key))
	for key in unknown_keys:
		push_warning("EquipmentConfig: effect_scores contains unknown stat key '%s' (removing)." % key)
		FW_Debug.debug_log(["[EquipmentConfig] effect_scores unknown key; removing:", key], FW_Debug.Level.WARN)
		effect_scores.erase(key)

func _setup_equipment_type_data():
	var bracer_texture = preload("res://Equipment/Images/bracers_uncolored.png")
	var collar_texture = preload("res://Equipment/Images/collar_uncolored.png")
	var harness_texture = preload("res://Equipment/Images/harness_uncolored.png")
	var hat_texture = preload("res://Equipment/Images/helmet_uncolored.png")
	var weapon_texture = preload("res://Equipment/Images/sword_uncolored.png")
	var tail_guard_texture = preload("res://Equipment/Images/tail_guard_uncolored.png")

	var bracer_names := ["Cuffs", "Gauntlets", "Bracers", "Bands", "Clasps", "Shackles", "Grips", "Armguards", "Wristlets", "Armlets", "Wristguards", "Bindings"]
	var hat_names := ["Hat", "Helmet", "Helm", "Cap", "Visor", "Crown", "Coif", "Circlet", "Mask", "Hood", "Headpiece", "Diadem", "Turban", "Bandana", "Tiara"]
	var harness_names := ["Harness", "Straps", "Tether", "Sash", "Rigging", "Barding", "Armor", "Yoke", "Girdle", "Vestment", "Chainmail", "Livery", "Plating", "Breastplate"]
	var collar_names := ["Collar", "Choker", "Band", "Chain", "Loop", "Torque", "Gorget", "Locket", "Leash", "Pendant", "Necklace", "Charm"]
	var weapon_names := ["Fangblade", "Spear", "Mace", "Sword", "Dagger", "Maul", "Warhammer", "Halberd", "Longsword", "Rapier", "Scimitar", "Axe", "War Axe"]
	var tail_guard_names := ["Tail Guard", "Protector", "Sweep", "Tail Shield", "Cover", "Wrap", "Guarding Wrap", "Coil", "Segment"]

	equipment_type_data = {
		FW_Equipment.equipment_types.BRACERS: { "texture": bracer_texture, "names": bracer_names },
		FW_Equipment.equipment_types.COLLAR: { "texture": collar_texture, "names": collar_names },
		FW_Equipment.equipment_types.HARNESS: { "texture": harness_texture, "names": harness_names },
		FW_Equipment.equipment_types.HAT: { "texture": hat_texture, "names": hat_names },
		FW_Equipment.equipment_types.WEAPON: { "texture": weapon_texture, "names": weapon_names },
		FW_Equipment.equipment_types.TAIL: { "texture": tail_guard_texture, "names": tail_guard_names }
	}

func get_rarity_data(rarity: FW_Equipment.equipment_rarity) -> Dictionary:
	return rarity_data.get(rarity, rarity_data[FW_Equipment.equipment_rarity.COMMON])

func get_equipment_type_data(type: FW_Equipment.equipment_types) -> Dictionary:
	return equipment_type_data.get(type, {})

func calculate_effect_score(effects: Dictionary) -> float:
	var score := 0.0
	for stat in effects.keys():
		if effect_scores.has(stat):
			score += effects[stat] * effect_scores[stat]
	return score
