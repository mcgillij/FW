extends RefCounted
class_name FW_AscensionHelper

# Helper utility to centralize ascension-related logic used during level generation.
# This keeps the LevelGenerator focused on structure and delegates ascension rules
# (multipliers, monster upgrades, chance adjustments, etc.) to a single place.

# --- AI Upgrade Logic (moved from UnlockManager) ---
const AI_UPGRADE_MAP = {
	FW_MonsterAI.monster_ai.RANDOM: FW_MonsterAI.monster_ai.SENTIENT,
	FW_MonsterAI.monster_ai.SENTIENT: FW_MonsterAI.monster_ai.BOMBER,
	FW_MonsterAI.monster_ai.BOMBER: FW_MonsterAI.monster_ai.SELF_AWARE,
	FW_MonsterAI.monster_ai.SELF_AWARE: FW_MonsterAI.monster_ai.SELF_AWARE
}

const MIN_AI_LEVEL_BY_ASCENSION = {
	0: FW_MonsterAI.monster_ai.RANDOM,
	1: FW_MonsterAI.monster_ai.BOMBER,
	2: FW_MonsterAI.monster_ai.SELF_AWARE
}

const ACT_LABELS := {
	1: "Act I",
	2: "Act II",
	3: "Act III",
	4: "Act IV",
	5: "Act V",
	6: "Act VI",
	7: "Act VII",
	8: "Act VIII" # final (no actual level 8)
}

const ACT_FINAL_WORLDS := {
	1: "world2",
	2: "world3",
	3: "world4",
	4: "world5",
	5: "world6",
	6: "world7",
	7: "world8" # final (act 8 has no levels)
}

static func get_min_ai_level(ascension_level: int) -> FW_MonsterAI.monster_ai:
	return MIN_AI_LEVEL_BY_ASCENSION.get(ascension_level, FW_MonsterAI.monster_ai.SELF_AWARE)

static func has_act(act_index: int) -> bool:
	return act_index >= 1 and ACT_LABELS.has(act_index)

static func get_act_label(act_index: int) -> String:
	return ACT_LABELS.get(act_index, "Act " + str(act_index))

static func get_world_id_for_act(act_index: int) -> String:
	return ACT_FINAL_WORLDS.get(act_index, "")

static func get_final_world_id_for_current_run() -> String:
	return get_world_id_for_act(UnlockManager.get_highest_act_unlocked())

static func get_base_final_world_id() -> String:
	return ACT_FINAL_WORLDS.get(1, "world8")

static func is_final_world(world_id: String) -> bool:
	if world_id == "":
		return false
	return world_id == get_final_world_id_for_current_run()

static func should_increment_ascension(world_id: String) -> bool:
	return world_id == get_base_final_world_id()

static func handle_world_completion(world_id: String) -> Dictionary:
	var result := {
		"unlocked_next_act": false,
		"next_act_index": 0,
		"next_act_label": ""
	}
	var act_index := _get_act_index_by_world(world_id)
	if act_index == 0:
		return result
	if act_index != UnlockManager.get_highest_act_unlocked():
		return result
	var next_act_index := act_index + 1
	if not has_act(next_act_index):
		return result
	if UnlockManager.unlock_next_act(act_index):
		result.unlocked_next_act = true
		result.next_act_index = next_act_index
		result.next_act_label = get_act_label(next_act_index)
	return result

static func build_act_unlock_message(next_act_label: String) -> String:
	if next_act_label == "":
		return ""
	return "[center][b]" + next_act_label + " unlocked![/b]\nPrepare for your next run.[/center]"

static func _get_act_index_by_world(world_id: String) -> int:
	for act_index in ACT_FINAL_WORLDS.keys():
		if ACT_FINAL_WORLDS.get(act_index, "") == world_id:
			return act_index
	return 0

static func upgrade_monster_ai(monster: FW_Monster_Resource, ascension_level: int) -> void:
	"""Upgrade monster AI if ascension level is 1 or higher."""
	if ascension_level >= 1:
		var min_ai = get_min_ai_level(ascension_level)
		if monster.ai_type < min_ai:
			monster.ai_type = min_ai
# --- End of AI Upgrade Logic ---


static func get_ascension_level(character_name: String) -> int:
	if typeof(UnlockManager) != TYPE_NIL and UnlockManager.has_method("get_ascension_level"):
		return UnlockManager.get_ascension_level(character_name)
	return 0

static func get_ascension_multipliers(ascension_level: int) -> Dictionary:
	"""
	Returns a dictionary of multipliers for game difficulty based on ascension level.
	Scaling effects only apply from ascension 4 onwards.
	"""
	var effective_level = 0
	if ascension_level >= 4:
		effective_level = ascension_level - 3 # A4 is like old A1, A5 is like old A2, etc.

	return {
		"monster_count": 1.0 + (effective_level * 0.2),
		"monster_hp": 1.0 + (effective_level * 0.15),
		"elite_chance": 0.15 + (effective_level * 0.05),
		"event_chance": 0.3 + (effective_level * 0.1),
		"monster_xp": 1.0 + (effective_level * 0.1),
		"skill_check_difficulty": 1.0 + (effective_level * 0.05)
	}

static func get_monster_count_multiplier(character_name: String) -> float:
	var asc = get_ascension_level(character_name)
	var mults = get_ascension_multipliers(asc)
	return float(mults.get("monster_count", 1.0))

static func get_skill_check_multiplier(character_name: String) -> float:
	var asc = get_ascension_level(character_name)
	var mults = get_ascension_multipliers(asc)
	return float(mults.get("skill_check_difficulty", 1.0))

static func apply_environment_chance(base_chance: float, character_name: String) -> float:
	var asc = get_ascension_level(character_name)
	if asc > 0:
		return base_chance + float(asc) * 0.1
	return base_chance

static func apply_to_monster(monster, character_name: String) -> void:
	"""Apply ascension-based modifications to a monster during level generation."""
	if not monster or monster.get("is_pvp_monster") == true:
		return

	var ascension_level = get_ascension_level(character_name)

	# Always ensure regular monsters have a StatsManager initialized
	if not monster.stats:
		monster.stats = FW_StatsManager.new()
	monster.stats.is_monster_stats = true

	# --- Ascension Effects ---
	# AI upgrades start at A1
	upgrade_monster_ai(monster, ascension_level)

	# Multipliers for stats/etc start at A4
	var multipliers = get_ascension_multipliers(ascension_level)
	monster.max_hp = int(monster.max_hp * float(multipliers.get("monster_hp", 1.0)))
	monster.xp = int(monster.xp * float(multipliers.get("monster_xp", 1.0)))
	if monster.shields > 0:
		monster.shields = int(monster.shields * float(multipliers.get("monster_hp", 1.0)))

	# Call setup after applying stat changes
	if monster.has_method("setup"):
		monster.setup()

	# For A2+, give SCRUB monsters a persisted random ability if they have none
	if ascension_level >= 2 and monster.type == FW_Monster_Resource.monster_type.SCRUB and monster.abilities.size() == 0:
		var possible := []
		if typeof(monster.monster_compatible_abilities) == TYPE_ARRAY and monster.monster_compatible_abilities.size() > 0:
			possible = monster.monster_compatible_abilities.duplicate()
		else:
			possible = ["res://Abilities/Resources/bite.tres", "res://Abilities/Resources/claw.tres"]
		possible.shuffle()
		var ab_path = possible[0]
		var ab_res = load(ab_path)
		if ab_res:
			var ab_copy = ab_res.duplicate(true)
			if ab_copy.level == 0:
				ab_copy.level = 1
			monster.abilities.append(ab_copy)
			monster.abilities_initialized = true

	# For A3+, ensure monsters have abilities and apply job logic
	if ascension_level >= 3 and not monster.is_pvp_monster:
		if monster.abilities.size() == 0:
			var possible2 := []
			if typeof(monster.monster_compatible_abilities) == TYPE_ARRAY and monster.monster_compatible_abilities.size() > 0:
				possible2 = monster.monster_compatible_abilities.duplicate()
			if possible2.size() > 0:
				possible2.shuffle()
				var ab_path2 = possible2[0]
				var ab_res2 = load(ab_path2)
				if ab_res2:
					var ab_copy2 = ab_res2.duplicate(true)
					if ab_copy2.level == 0:
						ab_copy2.level = 1
					monster.abilities.append(ab_copy2)
					monster.abilities_initialized = true
		if monster.has_method("apply_job_from_abilities"):
			monster.apply_job_from_abilities()
