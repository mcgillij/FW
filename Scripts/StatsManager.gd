extends Resource


class_name FW_StatsManager

# Define primary and secondary stats for easy reference
const PRIMARY_STATS = [
	"bark", "reflex", "alertness", "vigor", "enthusiasm"
]
const SECONDARY_STATS = [
	"affinity_damage_bonus", "hp", "shields", "critical_strike_chance", "critical_strike_multiplier",
	"evasion_chance", "red_mana_bonus", "blue_mana_bonus", "green_mana_bonus", "orange_mana_bonus",
	"pink_mana_bonus", "red_mana_max", "blue_mana_max", "green_mana_max", "orange_mana_max",
	"pink_mana_max", "bomb_tile_bonus", "cooldown_reduction", "tenacity", "luck", "shield_recovery",
	"lifesteal", "damage_resistance", "extra_consumable_slots"
]

# Flag to indicate this StatsManager belongs to a monster (not player)
var is_monster_stats := false

var max_hp: float
var current_hp: float:
	set(value):
		current_hp = clampf(value, 0, max_hp)

var max_shields := 999.0
var current_shields: float:
	set(value):
		current_shields = clampf(value, 0, max_shields)

# Base stats
@export var bark := 0.0
@export var reflex := 0.0
@export var alertness := 0.0
@export var vigor := 0.0
@export var enthusiasm := 0.0
@export var affinity_damage_bonus := 0.0
@export var hp: float
@export var shields: float # bonus shields
@export var critical_strike_chance: float
@export var critical_strike_multiplier: float
@export var evasion_chance: float
@export var red_mana_bonus: float
@export var blue_mana_bonus: float
@export var green_mana_bonus: float
@export var orange_mana_bonus: float
@export var pink_mana_bonus: float
# max manas
@export var red_mana_max: float
@export var blue_mana_max: float
@export var green_mana_max: float
@export var orange_mana_max: float
@export var pink_mana_max: float
@export var bomb_tile_bonus: float
@export var cooldown_reduction: float
@export var tenacity: float # reduce bomb damage
@export var luck: float # chance of rare loot drops
@export var shield_recovery: float
@export var lifesteal: float
@export var damage_resistance: float
@export var extra_consumable_slots: float

# List of stats to format as int (not percent)
const INT_STATS = [
	"bark", "reflex", "alertness", "vigor", "enthusiasm",
	"hp", "shields", "affinity_damage_bonus", "luck", "shield_recovery",
	"red_mana_max", "blue_mana_max", "green_mana_max", "orange_mana_max", "pink_mana_max",
	"extra_consumable_slots"
]

# Stat limits
var stat_max = 999
var stat_min = 0

var base_crit_multiplier := 2.0
var base_crit_chance := .05

const STAT_NAMES = [
	"bark", "reflex", "alertness", "vigor", "enthusiasm", "affinity_damage_bonus", "hp", "shields",
	"critical_strike_chance", "critical_strike_multiplier", "evasion_chance",
	"red_mana_bonus", "blue_mana_bonus", "green_mana_bonus", "orange_mana_bonus", "pink_mana_bonus",
	"red_mana_max", "blue_mana_max", "green_mana_max", "orange_mana_max", "pink_mana_max",
	"bomb_tile_bonus", "cooldown_reduction", "tenacity", "luck", "shield_recovery", "lifesteal",
	"damage_resistance", "extra_consumable_slots"
]

func _zero_stat_dict() -> Dictionary:
	var d = {}
	for s in STAT_NAMES:
		d[s] = 0.0
	return d

var equipment_bonuses = _zero_stat_dict()
var temporary_bonuses = _zero_stat_dict()
var job_bonuses = _zero_stat_dict()

# PvP opponent special handling
var _is_pvp_opponent: bool = false
var _pvp_final_values: Dictionary = {}

func _init() -> void:
	pass

func get_stat(stat_name: String) -> float:
	stat_name = stat_name.to_lower()

	# For PvP opponents, return the final combined values directly
	if _is_pvp_opponent and _pvp_final_values.has(stat_name):
		# Treat the serialized PvP final values as the base value, but still allow
		# equipment, job and temporary bonuses (from buffs/debuffs/environment)
		var pvp_base = float(_pvp_final_values[stat_name])
		var equip_bonus = get_stat_equipment(stat_name)
		var job_bonus = get_stat_job(stat_name)
		var temp_bonus = get_stat_temporary(stat_name)
		var combined = pvp_base + equip_bonus + job_bonus + temp_bonus
		return clampf(combined, stat_min, stat_max)

	var base_value =  get_base_stat(stat_name) # Get the base stat value
	var equipment_bonus_val = get_stat_equipment(stat_name)  # Get the equipment bonus
	var job_bonus_val = get_stat_job(stat_name)
	var effective_value = base_value + equipment_bonus_val + job_bonus_val
	return clampf(effective_value, stat_min, stat_max)

func get_base_stat(stat_name: String) -> float:
	stat_name = stat_name.to_lower()
	# Get skill tree allocated stats
	var skill_tree_value = get_stat_base(stat_name)
	# Get character base stats (only for player, not monsters)
	var character_value = 0.0
	if not is_monster_stats and GDM.player and GDM.player.character and GDM.player.character.effects:
		character_value = GDM.player.character.effects.get(stat_name, 0.0)
	return skill_tree_value + character_value

func get_stat_base(stat_name:String) -> float:
	stat_name = stat_name.to_lower()
	return self.get(stat_name)

func get_stat_equipment(stat_name:String) -> float:
	stat_name = stat_name.to_lower()
	var value = equipment_bonuses.get(stat_name, 0.0)
	return value

func get_stat_temporary(stat_name: String) -> float:
	stat_name = stat_name.to_lower()
	return temporary_bonuses.get(stat_name, 0.0)

func get_stat_job(stat_name: String) -> float:
	stat_name = stat_name.to_lower()
	var val = job_bonuses.get(stat_name, 0.0)
	return val

func get_stat_values() -> Dictionary:
	var values = {}
	for stat_name in STAT_NAMES:
		values[stat_name] = get_stat(stat_name)
	return values

func apply_job_bonus(effects: Dictionary) -> void:
	for stat in effects.keys():
		var bonus = effects[stat]
		var key := str(stat).to_lower()
		if not STAT_NAMES.has(key):
			push_warning("StatsManager: ignoring unknown job stat key '%s'" % key)
			FW_Debug.debug_log(["[StatsManager] unknown job stat key; ignoring:", key], FW_Debug.Level.WARN)
			continue
		if typeof(bonus) not in [TYPE_INT, TYPE_FLOAT]:
			push_warning("StatsManager: ignoring non-numeric job bonus for '%s'" % key)
			FW_Debug.debug_log(["[StatsManager] non-numeric job bonus; ignoring:", key, "value=", bonus], FW_Debug.Level.WARN)
			continue
		job_bonuses[key] += float(bonus)
	# apply_job_bonus: updates job_bonuses in-place

func apply_equipment_bonus(effects: Dictionary) -> void:
	for stat in effects.keys():
		var bonus = effects[stat]
		var key := str(stat).to_lower()
		if not STAT_NAMES.has(key):
			push_warning("StatsManager: ignoring unknown equipment stat key '%s'" % key)
			FW_Debug.debug_log(["[StatsManager] unknown equipment stat key; ignoring:", key], FW_Debug.Level.WARN)
			continue
		if typeof(bonus) not in [TYPE_INT, TYPE_FLOAT]:
			push_warning("StatsManager: ignoring non-numeric equipment bonus for '%s'" % key)
			FW_Debug.debug_log(["[StatsManager] non-numeric equipment bonus; ignoring:", key, "value=", bonus], FW_Debug.Level.WARN)
			continue
		equipment_bonuses[key] += float(bonus)

func apply_temporary_bonus(stat_name: String, bonus: float) -> void:
	stat_name = stat_name.to_lower()
	temporary_bonuses[stat_name] += bonus

# Remove the temporary bonus when the timer expires
func _on_temporary_bonus_timeout(stat_name: String, bonus: float) -> void:
	stat_name = stat_name.to_lower()
	temporary_bonuses[stat_name] -= bonus

func remove_equipment_bonus(stat_name: String, bonus: float) -> void:
	stat_name = stat_name.to_lower()
	equipment_bonuses[stat_name] -= bonus

func remove_all_job_bonus() -> void:
	job_bonuses = _zero_stat_dict()
	# remove_all_job_bonus: reset job bonuses

func remove_all_equipment_bonus() -> void:
	equipment_bonuses = _zero_stat_dict()

# Example method to reset all temporary bonuses (e.g., at the start of a new turn)
func reset_temporary_bonuses() -> void:
	temporary_bonuses = _zero_stat_dict()

func calculate_max_mana() -> Dictionary:
	var effects = GDM.effect_manager.get_modifier_effects()

	var max_mana = {}
	for color in ["red", "green", "blue", "orange", "pink"]:
		var stat = 0
		match color:
			"red":  # Bark
				stat = get_stat("bark") + effects["red_mana_max"]
			"green":  # Reflex
				stat = get_stat("reflex") + effects["green_mana_max"]
			"blue":  # Alertness
				stat = get_stat("alertness") + effects["blue_mana_max"]
			"orange":  # Vigor
				stat = get_stat("vigor") + effects["orange_mana_max"]
			"pink":  # Enthusiasm
				stat = get_stat("enthusiasm") + effects["pink_mana_max"]
		# Calculate max mana based on the stat value (scales from 10 to 100)
		max_mana[color] = int(10 + (stat / 50.0) * 90)
	return max_mana

func set_stats_from_skilltree(stats_dict: Dictionary) -> void:
	zero_out_base_stats()
	for stat_name in stats_dict.keys():
		var stat_value = stats_dict[stat_name]
		match stat_name:
			&"bark":
				bark = stat_value
			&"reflex":
				reflex = stat_value
			&"alertness":
				alertness = stat_value
			&"vigor":
				vigor = stat_value
			&"enthusiasm":
				enthusiasm = stat_value
			&"affinity_damage_bonus":
				affinity_damage_bonus = stat_value
			&"hp":
				hp = stat_value
			&"shields":
				shields = stat_value
			&"critical_strike_chance":
				critical_strike_chance = stat_value
			&"critical_strike_multiplier":
				critical_strike_multiplier = stat_value
			&"evasion_chance":
				evasion_chance = stat_value
			&"red_mana_bonus":
				red_mana_bonus = stat_value
			&"blue_mana_bonus":
				blue_mana_bonus = stat_value
			&"green_mana_bonus":
				green_mana_bonus = stat_value
			&"orange_mana_bonus":
				orange_mana_bonus = stat_value
			&"pink_mana_bonus":
				pink_mana_bonus = stat_value
			&"red_mana_max":
				red_mana_max = stat_value
			&"blue_mana_max":
				blue_mana_max = stat_value
			&"green_mana_max":
				green_mana_max = stat_value
			&"orange_mana_max":
				orange_mana_max = stat_value
			&"pink_mana_max":
				pink_mana_max = stat_value
			&"bomb_tile_bonus":
				bomb_tile_bonus = stat_value
			&"cooldown_reduction":
				cooldown_reduction = stat_value
			&"tenacity":
				tenacity = stat_value
			&"luck":
				luck = stat_value
			&"shield_recovery":
				shield_recovery = stat_value
			&"lifesteal":
				lifesteal = stat_value
			&"damage_resistance":
				damage_resistance = stat_value
			&"extra_consumable_slots":
				extra_consumable_slots = stat_value

func zero_out_base_stats() -> void:
	bark = 0.0
	reflex = 0.0
	alertness = 0.0
	vigor = 0.0
	enthusiasm = 0.0
	affinity_damage_bonus = 0.0
	hp = 0.0
	shields = 0.0
	critical_strike_chance = 0.0
	critical_strike_multiplier = 0.0
	evasion_chance = 0.0
	red_mana_bonus = 0.0
	blue_mana_bonus = 0.0
	green_mana_bonus = 0.0
	orange_mana_bonus = 0.0
	pink_mana_bonus = 0.0
	red_mana_max = 0.0
	blue_mana_max = 0.0
	green_mana_max = 0.0
	orange_mana_max = 0.0
	pink_mana_max = 0.0
	bomb_tile_bonus = 0.0
	cooldown_reduction = 0.0
	tenacity = 0.0
	luck = 0.0
	shield_recovery = 0.0
	lifesteal = 0.0
	damage_resistance = 0.0
	extra_consumable_slots = 0.0

func debug_print_stats() -> void:
	# Manual debug helper kept for me; no automatic prints
	for k in STAT_NAMES:
		FW_Debug.debug_log([k, ":", get_stat(k)])
