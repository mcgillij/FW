extends Resource

class_name FW_EffectManager

# Debug scaffolding removed

# Centralized current state tracking
var current_player_shields: int = 0
var current_monster_shields: int = 0
var current_player_hp: int = 0
var current_monster_hp: int = 0

# Generic combatant support (new system)
var player_combatant: FW_Combatant
var opponent_combatant: FW_Combatant

func _init() -> void:
	EventBus.start_of_monster_turn.connect(start_of_turn_shield_gain)
	EventBus.start_of_player_turn.connect(start_of_turn_shield_gain)

# Apply stat-based effects on abilities
func apply_stat_effects(ability: FW_Ability) -> Dictionary:
	var effects: Dictionary = {}
	# Example: Bark-based abilities get buffed by bark stat
	if ability.ability_type == FW_Ability.ABILITY_TYPES.Bark:
		var bark_stat: float
		if player_combatant:
			bark_stat = player_combatant.stats.get_stat("bark")
		else:
			bark_stat = GDM.player.stats.get_stat("bark")
		effects["damage"] = (bark_stat * 0.2)  # Only add the bark stat bonus, not the base damage
	return effects

func apply_monster_stat_effects(ability: FW_Ability) -> Dictionary:
	var effects: Dictionary = {}
	# Example: Bark-based abilities get buffed by bark stat
	if ability.ability_type == FW_Ability.ABILITY_TYPES.Bark:
		var bark_stat: float
		if opponent_combatant:
			bark_stat = opponent_combatant.stats.get_stat("bark")
		else:
			bark_stat = GDM.monster_to_fight.stats.get_stat("bark")
		effects["damage"] = (bark_stat * 0.2)  # Only add the bark stat bonus, not the base damage
	return effects

func process_mana_gain(mana_gained: Dictionary) -> Dictionary:
	var effects = {}
	if GDM.game_manager.turn_manager.is_player_turn():
		if player_combatant:
			effects = get_player_combatant_effects()
		else:
			effects = get_modifier_effects()
	else:
		if opponent_combatant:
			effects = get_opponent_combatant_effects()
		else:
			effects = get_monster_modifier_effects()
	var color_to_bonus = {
		"red": "red_mana_bonus",
		"green": "green_mana_bonus",
		"blue": "blue_mana_bonus",
		"orange": "orange_mana_bonus",
		"pink": "pink_mana_bonus"
	}
	var extra_mana = {}
	for color in mana_gained.keys():
		var raw_mana = mana_gained[color]
		var bonus = effects.get(color_to_bonus.get(color, ""), 0.0)
		extra_mana[color] = int(raw_mana * bonus) if raw_mana != 0 else 0
	return extra_mana

func start_of_turn_shield_gain() -> void:
	if not GDM.is_vs_mode():
		return
	var effects := {}
	var is_player: bool = GDM.game_manager.turn_manager.is_player_turn()
	if is_player:
		if player_combatant:
			effects = get_player_combatant_effects()
		else:
			effects = get_modifier_effects()
	else:
		if opponent_combatant:
			effects = get_opponent_combatant_effects()
		else:
			effects = get_monster_modifier_effects()
	if effects.get("shield_recovery", 0) > 0:
		add_shields(effects["shield_recovery"], is_player)


func collect_effects(stats, char_effects := {}, env_effects := {}) -> Dictionary:
	var stat_names = FW_StatsManager.STAT_NAMES
	var effects = {}

	# If the stats object belongs to a PvP opponent, it already represents
	# a precomputed final snapshot (stored via _pvp_final_values). Using
	# get_stat_values() provides the final values for PvP opponents, however
	# we still want previews and combat initialization to reflect environment
	# and (optional) character overlays. Merge those additively into the
	# snapshot here — but do NOT add temporary_bonuses again (they are
	# already folded into the snapshot by the PvP StatsManager).
	if stats and stats.has_method("get_stat_values") and stats._is_pvp_opponent:
		var snapshot: Dictionary = stats.get_stat_values()
		# Add character effects (additive)
		for k in char_effects.keys():
			snapshot[k] = float(snapshot.get(k, 0.0)) + float(char_effects[k])
		# Add environmental effects (additive)
		for k in env_effects.keys():
			snapshot[k] = float(snapshot.get(k, 0.0)) + float(env_effects[k])
		return snapshot
	# Start with skill tree stats
	for stat in stat_names:
		effects[stat] = stats.get_stat_base(stat)

	# Merge with character effects (like Atiya's base hp: 40)
	var merged_effects = FW_Utils.merge_dict(effects, char_effects)
	# Merge with environmental effects
	merged_effects = FW_Utils.merge_dict(merged_effects, env_effects)

	# Add equipment bonuses
	for stat in stat_names:
		merged_effects[stat] += stats.get_stat_equipment(stat)

	# Add job bonuses
	for stat in stat_names:
		merged_effects[stat] += stats.get_stat_job(stat)

	# Add temporary bonuses
	# Temporary bonuses are added differently depending on whether the
	# StatsManager belongs to a PvP-opponent. For PvP opponents the
	# FW_StatsManager.get_stat(...) already includes temporary_bonuses (we
	# preserve that behavior), so adding them again here would double-
	# count them. Only add temporary_bonuses into merged_effects for
	# non-PvP StatsManagers.
	# If this StatsManager belongs to a PvP opponent it already folds
	# temporary_bonuses into its `get_stat(...)` results; adding them
	# again here duplicates the effect. Check the flag directly.
	if not stats._is_pvp_opponent:
		for stat in stats.temporary_bonuses:
			merged_effects[stat] = merged_effects.get(stat, 0.0) + stats.temporary_bonuses[stat]

	# High-volume trace for balance/debugging. Only prints when FW_Debug.level is set to VERBOSE.
	# Keeps output stable by listing canonical stat keys in order.
	var summary_parts: Array[String] = []
	for stat in stat_names:
		summary_parts.append("%s=%s" % [stat, str(merged_effects.get(stat, 0.0))])
	FW_Debug.debug_log([
		"[EffectManager] collect_effects merged",
		"pvp=", str(stats._is_pvp_opponent),
		"char_keys=", str(char_effects.keys().size()),
		"env_keys=", str(env_effects.keys().size()),
		"effects:",
		" | ".join(summary_parts)
	], FW_Debug.Level.VERBOSE)

	return merged_effects

func get_modifier_effects() -> Dictionary:
	if not GDM.player or not GDM.player.stats:
		return {}
	return collect_effects(
		GDM.player.stats,
		GDM.player.character.effects,
		GDM.env_manager.get_environmental_effects() if GDM.env_manager else {}
	)

func get_monster_modifier_effects() -> Dictionary:
	if not GDM.monster_to_fight or not GDM.monster_to_fight.stats:
		return {}
	return collect_effects(
		GDM.monster_to_fight.stats,
		{},
		GDM.env_manager.get_environmental_effects() if GDM.env_manager else {}
	)

# Add methods to get combatant-specific effects (new system)
func get_player_combatant_effects() -> Dictionary:
	if player_combatant:
		return collect_effects(
			player_combatant.stats,
			player_combatant.character_effects,
			GDM.env_manager.get_environmental_effects() if GDM.env_manager else {}
		)
	return get_modifier_effects()  # Fallback to old method

func get_opponent_combatant_effects() -> Dictionary:
	if opponent_combatant:
		return collect_effects(
			opponent_combatant.stats,
			opponent_combatant.character_effects,  # PvP opponents can have character effects too
			GDM.env_manager.get_environmental_effects() if GDM.env_manager else {}
		)
	return get_monster_modifier_effects()  # Fallback to old method

func get_monster_hp() -> int:
	if opponent_combatant:
		return opponent_combatant.get_max_hp()

	# Fallback to old system
	var monster_effects = get_monster_modifier_effects()
	# If the monster resource represents a PvP opponent its effects dict
	# is already a precomputed snapshot (see FW_StatsManager._is_pvp_opponent).
	# In that case monster_effects["hp"] already contains the final HP and
	# should not be added to the resource's base max_hp again (that caused
	# a doubled HP previously).
	if GDM.monster_to_fight and GDM.monster_to_fight.stats and GDM.monster_to_fight.stats._is_pvp_opponent:
		return max(int(monster_effects.get("hp", 1)), 1)
	var modified_hp = GDM.monster_to_fight.max_hp + monster_effects["hp"]
	return max(modified_hp, 1.0)

func get_monster_shields() -> int:
	if opponent_combatant:
		return opponent_combatant.get_max_shields()

	# Fallback to old system
	var monster_effects = get_monster_modifier_effects()
	# Avoid double-adding for PvP snapshots (monster_effects already includes shields)
	if GDM.monster_to_fight and GDM.monster_to_fight.stats and GDM.monster_to_fight.stats._is_pvp_opponent:
		return int(monster_effects.get("shields", 0))
	return GDM.monster_to_fight.shields + monster_effects["shields"]

func get_shields() -> int:
	if player_combatant:
		return player_combatant.get_max_shields()

	# Fallback to old system
	var player_effects = get_modifier_effects()
	return player_effects["shields"]

func get_bypass_damage(enthusiasm_stat: float) -> int:
	# for every 2 points over 10, bypass 1 damage
	var modifier = int(floor((enthusiasm_stat - 10.0) / 2.0))
	return max(modifier, 0)

# Centralized current state getters
func get_current_monster_shields() -> int:
	return current_monster_shields

func get_current_player_shields() -> int:
	return current_player_shields

func get_current_monster_hp() -> int:
	return current_monster_hp

func get_current_player_hp() -> int:
	return current_player_hp

# Max value getters
func get_monster_max_hp() -> int:
	return get_monster_hp()

func get_player_max_hp() -> int:
	if player_combatant:
		return player_combatant.get_max_hp()

	# Fallback to old system
	var player_effects = get_modifier_effects()
	return int(player_effects["hp"])

# Centralized current state setters
func update_monster_shields(new_value: int) -> void:
	current_monster_shields = max(0, new_value)

func update_player_shields(new_value: int) -> void:
	current_player_shields = max(0, new_value)

func update_monster_hp(new_value: int) -> void:
	current_monster_hp = max(0, new_value)

func update_player_hp(new_value: int) -> void:
	current_player_hp = max(0, new_value)

# Initialize current state from calculated values (call during combat setup)
func initialize_combat_state() -> void:
	# Calculate maximum HP and shields with all modifiers for new combat
	var player_effects = get_modifier_effects()
	var monster_effects = get_monster_modifier_effects()

	# Set player to full health with modifiers
	current_player_hp = int(player_effects["hp"])  # This should be max HP with modifiers
	current_player_shields = player_effects["shields"]

	# Set monster to full health with modifiers
	# If the monster is a PvP snapshot, monster_effects["hp"] already
	# represents the full hp; don't add it to the resource max_hp again.
	# Debug: show stats state before computing monster HP/shields
	# Monster stats should now contain job bonuses if assigned at generation time.

	if GDM.monster_to_fight and GDM.monster_to_fight.stats and GDM.monster_to_fight.stats._is_pvp_opponent:
		current_monster_hp = int(monster_effects.get("hp", 1))
	else:
		current_monster_hp = GDM.monster_to_fight.max_hp + monster_effects["hp"]
	# Debug info removed: computed_current_monster_hp available in logs if needed
	current_monster_shields = GDM.monster_to_fight.shields + monster_effects["shields"]

	# Ensure minimum values
	current_monster_hp = max(current_monster_hp, 1)
	current_monster_shields = max(current_monster_shields, 0)
	current_player_hp = max(current_player_hp, 1)
	current_player_shields = max(current_player_shields, 0)

	# Also restore the player's base stats to full for consistency
	if GDM.player and GDM.player.stats:
		GDM.player.stats.current_hp = current_player_hp
		GDM.player.stats.current_shields = current_player_shields

	# Notify UI that combat state is now initialized
	EventBus.combat_state_initialized.emit()

# Generic combatant initialization (new system)
func initialize_combat_state_generic(player: FW_Combatant, opponent: FW_Combatant) -> void:
	"""Initialize combat with two generic combatants"""
	player_combatant = player
	opponent_combatant = opponent

	# Calculate maximum HP and shields with all modifiers for new combat
	var player_max_hp = player.get_max_hp()
	var player_max_shields = player.get_max_shields()
	var opponent_max_hp = opponent.get_max_hp()
	var opponent_max_shields = opponent.get_max_shields()

	# Set both combatants to full health
	current_player_hp = player_max_hp
	current_player_shields = player_max_shields
	current_monster_hp = opponent_max_hp  # Keep variable names for compatibility
	current_monster_shields = opponent_max_shields
	# Ensure minimum values
	current_player_hp = max(current_player_hp, 1)
	current_player_shields = max(current_player_shields, 0)
	current_monster_hp = max(current_monster_hp, 1)
	current_monster_shields = max(current_monster_shields, 0)

	# Notify UI that combat state is now initialized
	EventBus.combat_state_initialized.emit()

func is_combat_state_initialized() -> bool:
	return current_monster_hp > 0 or current_player_hp > 0

# Check if we're using the generic combatant system
func is_using_generic_combatants() -> bool:
	return player_combatant != null and opponent_combatant != null

# Damage application helpers - these update centralized state and emit events
func apply_damage(to_player: bool, amount: int, bypass: bool = false) -> void:
	var hp: int
	var shields: int
	var show_damage_effects: Signal
	var state_changed: Signal
	var died: Signal

	if to_player:
		hp = current_player_hp
		shields = current_player_shields
		show_damage_effects = EventBus.show_player_damage_effects
		state_changed = EventBus.player_state_changed
		died = EventBus.player_died
	else:
		hp = current_monster_hp
		shields = current_monster_shields
		show_damage_effects = EventBus.show_monster_damage_effects
		state_changed = EventBus.monster_state_changed
		died = EventBus.monster_died

	if bypass:
		hp = max(0, hp - amount)
		show_damage_effects.emit(amount, true, false)
	else:
		var shield_damage = min(amount, shields)
		var hp_damage = max(0, amount - shield_damage)
		shields = max(0, shields - shield_damage)
		hp = max(0, hp - hp_damage)

		if shield_damage > 0:
			show_damage_effects.emit(shield_damage, false, true)
		if hp_damage > 0:
			show_damage_effects.emit(hp_damage, false, false)

	if to_player:
		current_player_hp = hp
		current_player_shields = shields
	else:
		current_monster_hp = hp
		current_monster_shields = shields
	state_changed.emit()
	if hp <= 0:
		died.emit()

# Healing helpers
func heal_monster(amount: int) -> void:
	var max_hp = get_monster_hp()
	current_monster_hp = min(max_hp, current_monster_hp + amount)
	EventBus.show_monster_heal_effects.emit(amount)
	EventBus.monster_state_changed.emit()

func heal_player(amount: int) -> void:
	var max_hp = int(get_modifier_effects()["hp"])
	current_player_hp = min(max_hp, current_player_hp + amount)
	EventBus.show_player_heal_effects.emit(amount)
	EventBus.player_state_changed.emit()

# Shield helpers
func add_monster_shields(amount: int) -> void:
	current_monster_shields += amount
	EventBus.show_monster_shield_effects.emit(amount)
	EventBus.monster_state_changed.emit()

func add_player_shields(amount: int) -> void:
	current_player_shields += amount
	EventBus.show_player_shield_effects.emit(amount)
	EventBus.player_state_changed.emit()

func add_shields(amount: int, is_player: bool) -> void:
	if is_player:
		add_player_shields(amount)
	else:
		add_monster_shields(amount)
