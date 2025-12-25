extends Node

#class_name CombatManager

var grid

var current_ability: FW_Ability
var _context_counter: int = 0

# Command queue for effect sequencing
var command_queue: Array = []

func _ready() -> void:
	# Connect to evasion events to notify buffs
	EventBus.publish_evasion.connect(_on_evasion_event)

func queue_command(command: Resource) -> void:
	command_queue.append(command)

func process_queue() -> void:
	while command_queue.size() > 0:
		var cmd = command_queue.pop_front()
		if cmd.can_execute():
			cmd.execute()

			# If a combatant died as a result of this command, stop processing further queued commands
			if GDM and GDM.effect_manager:
				var monster_hp = GDM.effect_manager.get_current_monster_hp()
				var player_hp = GDM.effect_manager.get_current_player_hp()
				if monster_hp <= 0 or player_hp <= 0:
					# Let GameManager handle win/lose immediately
					if GDM.game_manager:
						GDM.game_manager.check_game_win()
					# Clear remaining commands to avoid actions after death
					command_queue.clear()
					return

# Affinity damage calculation and application
func apply_affinity_damage(character: Resource, mana_dict: Dictionary, combo_multiplier: int, is_player: bool) -> void:
	# Handle each affinity via EffectResource
	var affinity_to_resource: Dictionary = {
		FW_Ability.ABILITY_TYPES.Reflex: "res://Effects/ReflexAffinity.tres",
		FW_Ability.ABILITY_TYPES.Bark: "res://Effects/BarkAffinity.tres",
		FW_Ability.ABILITY_TYPES.Vigor: "res://Effects/VigorAffinity.tres",
		FW_Ability.ABILITY_TYPES.Alertness: "res://Effects/AlertnessAffinity.tres",
		FW_Ability.ABILITY_TYPES.Enthusiasm: "res://Effects/EnthusiasmAffinity.tres"
	}

	for affinity in character.affinities:
		var extra_damage = calculate_affinity_damage([affinity], mana_dict, is_player)
		if extra_damage > 0:
			var multiplier = combo_multiplier if combo_multiplier > 1 else 1
			var total_damage = extra_damage * multiplier
			var resource_path = affinity_to_resource.get(affinity)
			if resource_path:
				var context = {"is_player_turn": is_player, "damage": total_damage, "mana_dict": mana_dict}
				apply_effect_resource(resource_path, total_damage, context)
			else:
				push_error("No resource found for affinity: " + str(affinity))

func set_grid(grid_ref: Node) -> void:
	grid = grid_ref

func get_total_effects(ability: FW_Ability, is_player: bool) -> Dictionary:
	if is_player:
		return FW_Utils.merge_dict(
			FW_Utils.merge_dict(GDM.effect_manager.apply_stat_effects(ability), GDM.effect_manager.get_modifier_effects()),
			ability.effects
		)
	else:
		return FW_Utils.merge_dict(
			FW_Utils.merge_dict(GDM.effect_manager.apply_monster_stat_effects(ability), GDM.effect_manager.get_monster_modifier_effects()),
			ability.effects
		)

const MAX_EVASION_CHANCE: float = 0.9  # Configurable cap at 90%

func check_evasion(evasion_chance: float, is_player: bool) -> bool:
	evasion_chance = clampf(evasion_chance, 0.0, MAX_EVASION_CHANCE)
	if evasion_chance > 0.0 and randf() <= evasion_chance:
		EventBus.publish_evasion.emit(is_player)
		return true
	return false

func apply_bomb_and_tenacity(amount: int, bomb_bonus: float, tenacity: float) -> int:
	if bomb_bonus > 0.0:
		amount += int(amount * bomb_bonus)
	var tenacity_clamped: float = clampf(tenacity, 0.0, 0.9)
	if tenacity_clamped > 0.0:
		var amount_reduced: int = int(tenacity_clamped * amount)
		if amount_reduced >= amount:
			EventBus.publish_tenacity_reduction.emit(amount)
			return int(amount * 0.1)
		else:
			EventBus.publish_tenacity_reduction.emit(amount_reduced)
			return max(amount - amount_reduced, int(amount * 0.1))
	return amount

func apply_crit(amount: int, crit_chance: float, crit_mult: float, base_mult: float) -> int:
	if crit_chance > 0.0 and randf() <= crit_chance:
		var mult: float = base_mult + crit_mult
		EventBus.publish_crit.emit()
		return int(amount * mult)
	return amount

func apply_damage_resistance(amount: int, resistance: float) -> int:
	if resistance > 0.0:
		var reduced: int = int(amount - amount * clampf(resistance, 0.0, 1.0))
		if reduced < amount:
			EventBus.publish_damage_resist.emit(amount - reduced)
			return reduced
	return amount

func apply_lifesteal(amount: int, lifesteal: float, owner_is_player: bool) -> void:
	if lifesteal > 0.0:
		# Lifesteal is a multiplier, e.g., 1.0 for 100%.
		var value: int = int(amount * clampf(lifesteal, 0.0, 1.0))
		if value > 0:
			if owner_is_player:
				GDM.effect_manager.heal_player(value)
			else:
				GDM.effect_manager.heal_monster(value)
			EventBus.publish_lifesteal.emit(value, owner_is_player)

func resolve_dot(amount: int, _reason: String) -> void:
	if amount > 0:
		# DOT damage goes to monster
		GDM.effect_manager.apply_damage(false, amount)
		EventBus.publish_damage.emit(amount, _reason, true)  # Emit combat log event for DOT damage
		notify_damage_taken(false, amount)
		# Apply lifesteal for player (assuming DOT is from player's buffs)
		var attacker_effects = GDM.effect_manager.get_modifier_effects()
		if attacker_effects.get("lifesteal", 0) > 0:
			apply_lifesteal(amount, attacker_effects["lifesteal"], true)

func resolve_sinker(amount: int, reason: String, sinker_owner: FW_Piece.OWNER) -> void:
	# Centralize sinker damage through apply_damage_with_checks so checks / crit / lifesteal are consistent
	var is_player_attacker = sinker_owner == FW_Piece.OWNER.PLAYER
	var applied = apply_damage_with_checks(amount, reason, is_player_attacker, false, false)
	EventBus.publish_sinker_damage.emit(applied, reason, sinker_owner)  # Keep for UI compatibility

func apply_damage_with_checks(amount: int, reason: String, attacker_is_player: bool, bomb: bool = false, force_bypass: bool = false, emit_publish: bool = true) -> int:
	# Central helper: performs evasion, bomb/tenacity, crit, lifesteal and then applies damage.
	# Returns the amount actually applied (0 if evaded or reduced to 0 by resistances).
	if attacker_is_player:
		var monster_effects = GDM.effect_manager.get_monster_modifier_effects()
		var player_effects = GDM.effect_manager.get_modifier_effects()
		# Evasion check against monster
		if check_evasion(monster_effects.get("evasion_chance", 0.0), false):
			return 0
		if not force_bypass:
			# Normal path: perform checks and apply with bypass logic
			if bomb:
				amount = apply_bomb_and_tenacity(amount, player_effects.get("bomb_tile_bonus", 0.0), monster_effects.get("tenacity", 0.0))
			amount = apply_crit(amount, GDM.player.stats.base_crit_chance + player_effects.get("critical_strike_chance", 0.0), player_effects.get("critical_strike_multiplier", 0.0), GDM.player.stats.base_crit_multiplier)
			amount = apply_damage_resistance(amount, monster_effects.get("damage_resistance", 0.0))
			if amount > 0:
				# Apply lifesteal
				var attacker_effects = GDM.effect_manager.get_modifier_effects()
				if attacker_effects.get("lifesteal", 0) > 0:
					apply_lifesteal(amount, attacker_effects["lifesteal"], true)
				var target_shields = GDM.effect_manager.get_current_monster_shields()
				var bypass_damage = GDM.effect_manager.get_bypass_damage(int(GDM.player.stats.get_stat("enthusiasm")))
				if bypass_damage > 0 and target_shields > 0:
					var remaining = max(0, amount - bypass_damage)
					# Apply bypass damage
					GDM.effect_manager.apply_damage(false, bypass_damage, true)
					if emit_publish:
						EventBus.publish_bypass_damage.emit(bypass_damage)
					notify_damage_taken(false, bypass_damage)
					if remaining > 0:
						# Apply remaining normal damage
						GDM.effect_manager.apply_damage(false, remaining)
						if emit_publish:
							EventBus.publish_damage.emit(remaining, reason, true)
						notify_damage_taken(false, remaining)
				else:
					# No bypass, apply normal damage
					GDM.effect_manager.apply_damage(false, amount)
					if emit_publish:
						EventBus.publish_damage.emit(amount, reason, true)
					notify_damage_taken(false, amount)
			return amount
		else:
			# Forced bypass path: still allow bomb/crit, but apply as bypass
			if bomb:
				amount = apply_bomb_and_tenacity(amount, player_effects.get("bomb_tile_bonus", 0.0), monster_effects.get("tenacity", 0.0))
			amount = apply_crit(amount, GDM.player.stats.base_crit_chance + player_effects.get("critical_strike_chance", 0.0), player_effects.get("critical_strike_multiplier", 0.0), GDM.player.stats.base_crit_multiplier)
			# Lifesteal is now handled in _resolve_damage() to avoid duplication
			if amount > 0:
				# Apply lifesteal
				var attacker_effects = GDM.effect_manager.get_modifier_effects()
				if attacker_effects.get("lifesteal", 0) > 0:
					apply_lifesteal(amount, attacker_effects["lifesteal"], true)
				GDM.effect_manager.apply_damage(false, amount, true)
				EventBus.publish_bypass_damage.emit(amount)
				notify_damage_taken(false, amount)
			return amount
	else:
		var player_effects = GDM.effect_manager.get_modifier_effects()
		var monster_effects = GDM.effect_manager.get_monster_modifier_effects()
		# Evasion check against player
		if check_evasion(player_effects.get("evasion_chance", 0.0), true):
			return 0
		if not force_bypass:
			# Normal path for monster
			if bomb:
				amount = apply_bomb_and_tenacity(amount, monster_effects.get("bomb_tile_bonus", 0.0), player_effects.get("tenacity", 0.0))
			amount = apply_crit(amount, GDM.monster_to_fight.stats.base_crit_chance + monster_effects.get("critical_strike_chance", 0.0), monster_effects.get("critical_strike_multiplier", 0.0), GDM.player.stats.base_crit_multiplier)
			amount = apply_damage_resistance(amount, player_effects.get("damage_resistance", 0.0))
			if amount > 0:
				# Apply lifesteal
				var attacker_effects = GDM.effect_manager.get_monster_modifier_effects()
				if attacker_effects.get("lifesteal", 0) > 0:
					apply_lifesteal(amount, attacker_effects["lifesteal"], false)
				var target_shields = GDM.effect_manager.get_current_player_shields()
				var bypass_damage = GDM.effect_manager.get_bypass_damage(int(GDM.monster_to_fight.stats.get_stat("enthusiasm")))
				if bypass_damage > 0 and target_shields > 0:
					var remaining = max(0, amount - bypass_damage)
					# Apply bypass damage
					GDM.effect_manager.apply_damage(true, bypass_damage, true)
					if emit_publish:
						EventBus.publish_bypass_damage.emit(bypass_damage)
					notify_damage_taken(true, bypass_damage)
					if remaining > 0:
						# Apply remaining normal damage
						GDM.effect_manager.apply_damage(true, remaining)
						if emit_publish:
							EventBus.publish_damage.emit(remaining, reason, false)
						notify_damage_taken(true, remaining)
				else:
					# No bypass, apply normal damage
					GDM.effect_manager.apply_damage(true, amount)
					if emit_publish:
						EventBus.publish_damage.emit(amount, reason, false)
					notify_damage_taken(true, amount)
			return amount
		else:
			# Forced bypass path for monster
			if bomb:
				amount = apply_bomb_and_tenacity(amount, monster_effects.get("bomb_tile_bonus", 0.0), player_effects.get("tenacity", 0.0))
			amount = apply_crit(amount, GDM.monster_to_fight.stats.base_crit_chance + monster_effects.get("critical_strike_chance", 0.0), monster_effects.get("critical_strike_multiplier", 0.0), GDM.player.stats.base_crit_multiplier)
			# Lifesteal is now handled in _resolve_damage() to avoid duplication
			if amount > 0:
				# Apply lifesteal
				var attacker_effects = GDM.effect_manager.get_monster_modifier_effects()
				if attacker_effects.get("lifesteal", 0) > 0:
					apply_lifesteal(amount, attacker_effects["lifesteal"], false)
				GDM.effect_manager.apply_damage(true, amount, true)
				EventBus.publish_bypass_damage.emit(amount)
				notify_damage_taken(true, amount)
			return amount

func _apply_ability_effects(ability: FW_Ability, mana: FW_Mana, is_player: bool, context_id: String = "") -> int:
	var effects = {}
	if is_player:
		effects = FW_Utils.merge_dict(GDM.effect_manager.apply_stat_effects(ability), GDM.effect_manager.get_modifier_effects())
	else:
		effects = FW_Utils.merge_dict(GDM.effect_manager.apply_monster_stat_effects(ability), GDM.effect_manager.get_monster_modifier_effects())
	effects = FW_Utils.merge_dict(ability.effects, effects)
	var damage = ability.damage
	if effects.has("damage") and effects["damage"] > 0:
		EventBus.publish_bonus_damage.emit(ability, effects["damage"])
		damage += effects["damage"]
	if effects.has("drain"):
		damage += drain_mana(ability.effects["drain"], mana)
	if effects.has("mana_to_damage"):
		var key = ability.effects["mana_to_damage"]
		if is_player:
			damage += mana.player[key]
		else:
			damage += mana.enemy[key]
	if effects.has("mana_to_shields"):
		var shields = 0
		if is_player:
			shields = mana.player[ability.effects["mana_to_shields"]]
		else:
			shields = mana.enemy[ability.effects["mana_to_shields"]]
		if shields > 0:
			var ctx = {"is_player_turn": is_player, "ability": ability}
			if context_id != "":
				ctx["context_id"] = context_id
			apply_effect_resource("res://Effects/ManaToShields.tres", shields, ctx)
	if effects.has("channel"):
		var ctx2 = {"ability": ability, "is_player_turn": is_player}
		if context_id != "":
			ctx2["context_id"] = context_id
		apply_effect_resource("res://Effects/ChannelMana.tres", 0, ctx2)
	return damage

func resolve_ability_usage(ability: FW_Ability, mana: FW_Mana) -> void:
	# Trace entry into resolve_ability_usage for debugging
	if EventBus.has_signal("debug_log"):
		FW_Debug.debug_log(["CombatManager.resolve_ability_usage: ability=%s" % ability.name])

	var is_player = GDM.game_manager.turn_manager.is_player_turn()
	current_ability = ability
	if not is_player:
		EventBus.publish_monster_used_ability.emit(ability)
	# create a context id for this ability usage
	_context_counter += 1
	var context_id = "ctx_%d" % _context_counter
	var damage = _apply_ability_effects(ability, mana, is_player, context_id)
	var effects = get_total_effects(ability, is_player)

	if effects.has("shield_bash"):
		var shields = 0
		if is_player:
			shields = GDM.effect_manager.get_current_player_shields()
		else:
			shields = GDM.effect_manager.get_current_monster_shields()
		if shields > 0:
			var ctx_sb = {"is_player_turn": is_player}
			if context_id != "": ctx_sb["context_id"] = context_id
			apply_effect_resource("res://Effects/ShieldBash.tres", shields, ctx_sb)

	if effects.has("shatter"):
		var shields = 0
		if is_player:
			shields = GDM.effect_manager.get_current_monster_shields()
		else:
			shields = GDM.effect_manager.get_current_player_shields()
		if shields > 0:
			var ctx_sh = {"is_player_turn": is_player}
			if context_id != "": ctx_sh["context_id"] = context_id
			apply_effect_resource("res://Effects/Shatter.tres", shields, ctx_sh)

	if effects.has("radiance"):
		var heal_amount = effects.get("radiance", 0)
		if heal_amount > 0:
			var ctx_r = {"is_player_turn": is_player}
			if context_id != "": ctx_r["context_id"] = context_id
			apply_effect_resource("res://Effects/RadianceHealing.tres", heal_amount, ctx_r)

	if effects.has("gain_shield"):
		var shield_amount = effects.get("gain_shield", 0)
		if shield_amount > 0:
			var ctx_gs = {"is_player_turn": is_player}
			if context_id != "": ctx_gs["context_id"] = context_id
			apply_effect_resource("res://Effects/GainShield.tres", shield_amount, ctx_gs)

	if effects.has("shields_to_health"):
		var ctx_sth = {"is_player_turn": is_player}
		if context_id != "": ctx_sth["context_id"] = context_id
		apply_effect_resource("res://Effects/ShieldsToHealth.tres", 0, ctx_sth)

	if effects.has("drain_with_heal"):
		var drain_dict = effects.get("drain_with_heal", {})
		var ctx_dwh = {"is_player_turn": is_player, "drain_dict": drain_dict}
		if context_id != "": ctx_dwh["context_id"] = context_id
		apply_effect_resource("res://Effects/DrainWithHeal.tres", 0, ctx_dwh)

	_use_mana(ability.cost, mana)
	_cooldown(ability)
	if damage > 0:
		_resolve_damage(damage, ability)
	EventBus.do_booster_screen_effect.emit(ability.ability_type)
	EventBus.wrap_up_booster.emit()
	current_ability = null
	# signal context end so log bus can flush
	if EventBus.has_signal("combat_context_end"):
		EventBus.combat_context_end.emit(context_id)
	process_queue()

func _cooldown(ability: FW_Ability) -> void:
	var cdm
	var owner_id: String
	if GDM.game_manager.turn_manager.is_player_turn():
		cdm = GDM.game_manager.player_cooldown_manager
		owner_id = "player"
		EventBus.publish_used_ability.emit(ability)  # Keep for UI
		GDM.tracker.add_to_ability_log(ability.name)
	else:
		cdm = GDM.game_manager.monster_cooldown_manager
		owner_id = "monster"
	var key = [owner_id, ability.name]
	if !cdm.abilities.has(key):
		cdm.add_ability(owner_id, ability)
	# Debug: log which ability is being activated so we can trace activation -> visual triggers
	if EventBus.has_signal("debug_log"):
		FW_Debug.debug_log(["CombatManager._cooldown: activating ability %s" % ability.name])

	ability.activate_booster(self.grid, "")
	# Emit generic log for ability usage
	# Ability UI consumption is handled elsewhere and ability-specific logs are emitted by the effect resources

func handle_bypass_and_normal_damage(amount: int, enthusiasm: int, is_player: bool, reason: String, ability: FW_Ability = null) -> void:
	# Apply lifesteal
	if ability:
		var effects = get_total_effects(ability, is_player)
		if effects.get("lifesteal", 0) > 0:
			apply_lifesteal(amount, effects["lifesteal"], is_player)
	var target_shields = 0
	if is_player: # Player is attacking monster
		target_shields = GDM.effect_manager.get_current_monster_shields()
	else: # Monster is attacking player
		target_shields = GDM.effect_manager.get_current_player_shields()

	var bypass_damage = GDM.effect_manager.get_bypass_damage(enthusiasm)

	# Only apply bypass if there is bypass damage AND the target has shields to bypass
	if bypass_damage > 0 and target_shields > 0:
		var remaining = max(0, amount - bypass_damage)

		# Queue bypass damage command
		var bypass_cmd = FW_DamageCommand.new(bypass_damage, "", is_player, true)
		if ability:
			bypass_cmd.log_message = ability.get_formatted_log_message({
				"attacker": GDM.player.character.name if is_player else GDM.monster_to_fight.name,
				"target": GDM.monster_to_fight.name if is_player else GDM.player.character.name,
				"damage": bypass_damage,
				"action": "bypass",
				"amount": ability.effects.get("gain_shield", ability.effects.get("radiance", ability.damage))
			})
		queue_command(bypass_cmd)

		# Queue remaining damage command
		if remaining > 0:
			var normal_cmd = FW_DamageCommand.new(remaining, reason, is_player, false)
			if ability:
				normal_cmd.log_message = ability.get_formatted_log_message({
					"attacker": GDM.player.character.name if is_player else GDM.monster_to_fight.name,
					"target": GDM.monster_to_fight.name if is_player else GDM.player.character.name,
					"damage": remaining,
					"action": "damage",
					"amount": ability.effects.get("gain_shield", ability.effects.get("radiance", ability.damage))
				})
			queue_command(normal_cmd)
	else:
		# No bypass, queue normal damage command
		var cmd = FW_DamageCommand.new(amount, reason, is_player, false)
		if ability:
			cmd.log_message = ability.get_formatted_log_message({
				"attacker": GDM.player.character.name if is_player else GDM.monster_to_fight.name,
				"target": GDM.monster_to_fight.name if is_player else GDM.player.character.name,
				"damage": amount,
				"action": "damage",
				"amount": ability.effects.get("gain_shield", ability.effects.get("radiance", ability.damage))
			})
		queue_command(cmd)
	# Notify buffs of damage taken
	if not is_player:
		notify_damage_taken(true, amount)
	else:
		notify_damage_taken(false, amount)

func _resolve_damage(amount: int, ability: FW_Ability) -> void:
	var is_player = GDM.game_manager.turn_manager.is_player_turn()
	var effects = get_total_effects(ability, is_player)
	var base_crit_mult = 0.0
	var enthusiasm = 0
	var base_crit_chance = 0.0

	if is_player:
		base_crit_chance = GDM.player.stats.base_crit_chance
		base_crit_mult = GDM.player.stats.base_crit_multiplier
		enthusiasm = int(GDM.player.stats.get_stat("enthusiasm"))
	else:
		base_crit_chance = GDM.monster_to_fight.stats.base_crit_chance
		base_crit_mult = GDM.monster_to_fight.stats.base_crit_multiplier
		enthusiasm = int(GDM.monster_to_fight.stats.get_stat("enthusiasm"))

	# Crit
	amount = apply_crit(amount, base_crit_chance + effects.get("critical_strike_chance", 0), effects.get("critical_strike_multiplier", 0), base_crit_mult)

	# Lifesteal moved to damage application

	# Bypass
	if effects.has("bypass"):
		apply_damage_with_checks(amount, "with " + ability.name, is_player, false, true)
	else:
		handle_bypass_and_normal_damage(amount, enthusiasm, is_player, "with " + ability.name, ability)

func drain_mana(dict_of_mana: Dictionary, mana: FW_Mana) -> int:
	var update_dict: Dictionary
	if GDM.game_manager.turn_manager.is_player_turn():
		update_dict = mana.enemy
	else:
		update_dict = mana.player

	var total_damage = 0

	# Track drained mana
	var drained_mana: Dictionary = {}

	for key in dict_of_mana.keys():
		var current_value = update_dict[key]
		var drain_amount = min(dict_of_mana[key], current_value)  # Ensure we don't drain more than available
		drained_mana[key] = drain_amount
		update_dict[key] = current_value - drain_amount  # Update mana, ensuring it doesn't go below 0
		total_damage += drain_amount  # Add to total damage

	# Emit events with the drained mana and updated mana state
	EventBus.publish_mana_drain.emit(drained_mana)
	EventBus.do_mana_drain.emit(update_dict)

	return total_damage

func _use_mana(dict_of_mana: Dictionary, mana: FW_Mana) -> void:
	var update_dict: Dictionary
	if GDM.game_manager.turn_manager.is_player_turn():
		update_dict = mana.player
	else:
		update_dict = mana.enemy
	for key in dict_of_mana.keys():
		var value = update_dict[key]
		update_dict[key] = clampi(value + -dict_of_mana[key], 0, 9999999) # negative value cause of cost
	if GDM.game_manager.turn_manager.is_player_turn():
		GDM.tracker.use_mana(dict_of_mana)
	EventBus.update_mana.emit(update_dict)
	EventBus.trigger_show_hide_boosters.emit()

func apply_buff_to_player(buff: FW_Buff) -> void:
	if GDM.player and GDM.player.buffs:
		GDM.player.buffs.set_meta("owner_type", "player")
		# Set caster type if not already set
		if buff.caster_type == "":
			buff.caster_type = "player"  # Default to player if not specified
		GDM.player.buffs.add_buff(buff)


func apply_buff_to_monster(buff: FW_Buff) -> void:
	if GDM.monster_to_fight and GDM.monster_to_fight.buffs:
		GDM.monster_to_fight.buffs.set_meta("owner_type", "monster")
		# Set caster type if not already set
		if buff.caster_type == "":
			buff.caster_type = "monster"  # Default to monster if not specified
		GDM.monster_to_fight.buffs.add_buff(buff)


func apply_buff_intelligently(buff: FW_Buff) -> void:
	var is_player_turn: bool = GDM.game_manager.turn_manager.is_player_turn()

	# Set the caster type based on whose turn it is
	buff.caster_type = "player" if is_player_turn else "monster"

	if buff.category == FW_Buff.buff_category.beneficial:
		if is_player_turn:
			apply_buff_to_player(buff)
		else:
			apply_buff_to_monster(buff)
	else:
		if is_player_turn:
			apply_buff_to_monster(buff)
		else:
			apply_buff_to_player(buff)

# Mana gain helpers for buffs
func apply_mana_gain_to_player(mana_dict: Dictionary) -> void:
	if GDM.game_manager and GDM.game_manager.mana:
		var player_mana = GDM.game_manager.mana.player
		var max_mana = GDM.player.stats.calculate_max_mana()
		for color in mana_dict.keys():
			var gain_amount = mana_dict[color]
			if gain_amount > 0:
				player_mana[color] = clampi(player_mana[color] + gain_amount, 0, max_mana[color])

		EventBus.do_player_gain_mana.emit(mana_dict)  # Keep for UI compatibility
		EventBus.update_mana.emit(player_mana)

func apply_mana_gain_to_monster(mana_dict: Dictionary) -> void:
	if GDM.game_manager and GDM.game_manager.mana:
		var monster_mana = GDM.game_manager.mana.enemy
		var max_mana = GDM.game_manager.MONSTER_MAX_MANA
		for color in mana_dict.keys():
			var gain_amount = mana_dict[color]
			if gain_amount > 0:
				monster_mana[color] = clampi(monster_mana[color] + gain_amount, 0, max_mana[color])

		EventBus.do_monster_gain_mana.emit(mana_dict)  # Keep for UI compatibility
		EventBus.update_mana.emit(monster_mana)

# Helper to notify buffs when damage is taken
func notify_damage_taken(target_is_player: bool, amount: int) -> void:
	if target_is_player:
		if GDM.player and GDM.player.buffs:
			GDM.player.buffs.notify_damage_taken(amount, "player")
	else:
		if GDM.monster_to_fight and GDM.monster_to_fight.buffs:
			GDM.monster_to_fight.buffs.notify_damage_taken(amount, "monster")

func notify_evasion(target_is_player: bool) -> void:
	if target_is_player:
		if GDM.player and GDM.player.buffs:
			GDM.player.buffs.notify_evasion("player")
	else:
		if GDM.monster_to_fight and GDM.monster_to_fight.buffs:
			GDM.monster_to_fight.buffs.notify_evasion("monster")

func _on_evasion_event(is_player: bool) -> void:
	# Called when EventBus.publish_evasion is emitted
	notify_evasion(is_player)

# --- Utility Functions ---

func apply_effect_resource(effect_path: String, amount: int = 0, context: Dictionary = {}) -> void:
	# Helper to easily apply effect resources with dynamic amounts
	var effect_resource = load(effect_path)
	if effect_resource:
		effect_resource.amount = amount
		var cmd = FW_UniversalEffectCommand.new(effect_resource, context)
		queue_command(cmd)
	else:
		push_error("Could not load effect resource: " + effect_path)

func calculate_affinity_damage(affinities: Array, mana_dict: Dictionary, is_player: bool) -> int:
	var effects: Dictionary = {}
	if is_player:
		effects = GDM.effect_manager.get_modifier_effects()
	else:
		effects = GDM.effect_manager.get_monster_modifier_effects()
	var affinity_damage_bonus: int = 5 + effects.get("affinity_damage_bonus", 0)
	const AFFINITY_THRESHOLD: int = 3
	var aff_to_color: Dictionary = {
		FW_Ability.ABILITY_TYPES.Bark: "red",
		FW_Ability.ABILITY_TYPES.Reflex: "green",
		FW_Ability.ABILITY_TYPES.Alertness: "blue",
		FW_Ability.ABILITY_TYPES.Vigor: "orange",
		FW_Ability.ABILITY_TYPES.Enthusiasm: "pink"
	}
	var total_damage: int = 0
	for aff in affinities:
		var color = aff_to_color.get(aff, null)
		if color and mana_dict.get(color, 0) >= AFFINITY_THRESHOLD:
			total_damage += mana_dict[color] + affinity_damage_bonus
	return total_damage
