extends Resource

class_name FW_EffectResource

# Logging contract (standard for EffectResource)
# - Resources should NOT directly emit final UI log signals (e.g., EventBus.publish_combat_log/_with_icon).
# - Instead, they must populate `last_log_message` and optionally `last_log_icon` during `execute()`.
#   The caller (for example `UniversalEffectCommand`) will read these fields and publish them
#   in queue order so log ordering is preserved.
# - Resources should implement `get_formatted_log_message(vars: Dictionary)` to produce
#   a templated message. Use `log_message` as template when present, otherwise fall back
#   to `_generate_default_message`.
# - `last_context` may be set by callers to allow resources to access contextual templating
#   (attacker/target names, amounts, etc.).
# TODO: When adding new EffectResource types, ensure they set `last_log_message`/`last_log_icon`
#       for every code-path that should produce a final combat log entry.

@export var name: String
@export var log_message: String = ""
@export var texture: Texture2D
@export var effect_type: String  # "heal", "damage", "shield", "buff", "mana_gain", etc.
@export var target_type: String = "auto"  # "auto", "self", "enemy", "player", "monster"
@export var amount: int = 0
@export var effects: Dictionary = {}  # For complex effects
@export var bypass_shields: bool = false
@export var force_crit: bool = false

# Last-run logging outputs (populated by execute and read by caller to publish)
var last_log_message: String = ""
var last_log_icon: Texture2D = null

# Templating system with smart defaults
func get_formatted_log_message(vars: Dictionary = {}) -> String:
	# Default vars for common templating
	var default_vars = {
		"effect_name": name,
		"amount": amount,
		"effect_type": effect_type,
		"target_type": target_type
	}

	# Auto-populate attacker/target based on game state
	if GDM.game_manager:
		var is_player_turn = GDM.game_manager.turn_manager.is_player_turn()
		default_vars["attacker"] = GDM.player.character.name if is_player_turn else GDM.monster_to_fight.name
		default_vars["target"] = GDM.monster_to_fight.name if is_player_turn else GDM.player.character.name

		# Smart target resolution for "auto" mode
		if target_type == "auto":
			# Beneficial effects target self, harmful target enemy
			var is_beneficial = _is_beneficial_effect()
			if is_beneficial:
				default_vars["effective_target"] = default_vars["attacker"]
			else:
				default_vars["effective_target"] = default_vars["target"]
		else:
			default_vars["effective_target"] = _resolve_target_name()

	# Merge with provided vars (allows override)
	for key in vars.keys():
		default_vars[key] = vars[key]

	# Use template if provided, otherwise generate smart default
	if log_message and log_message.strip_edges() != "":
		var formatted := log_message.format(default_vars)
		return formatted.strip_edges()
	else:
		# Generate contextual default message
		return _generate_default_message(default_vars)

func _is_beneficial_effect() -> bool:
	# Determine if this is a beneficial effect (heal, shield, buff) or harmful (damage, debuff)
	return effect_type in ["heal", "shield", "mana_gain", "beneficial_buff", "mana_gain_formatted"]

func _resolve_target_name() -> String:
	# Resolve target_type to actual character name
	match target_type:
		"player":
			return GDM.player.character.name if GDM.player else "Player"
		"monster":
			return GDM.monster_to_fight.name if GDM.monster_to_fight else "Monster"
		"self":
			return GDM.player.character.name if GDM.game_manager.turn_manager.is_player_turn() else GDM.monster_to_fight.name
		"enemy":
			return GDM.monster_to_fight.name if GDM.game_manager.turn_manager.is_player_turn() else GDM.player.character.name
		_:
			return "Unknown"

func _generate_default_message(vars: Dictionary) -> String:
	var attacker = vars.get("attacker", "Someone")
	var target = vars.get("effective_target", vars.get("target", "target"))
	var amt = vars.get("amount", amount)

	match effect_type:
		"heal":
			return "{attacker} heals {target} for {amount} HP!".format({
				"attacker": attacker, "target": target, "amount": amt
			})
		"damage":
			return "{attacker} deals {amount} damage to {target}!".format({
				"attacker": attacker, "target": target, "amount": amt
			})
		"shield":
			return "{target} gains {amount} shields!".format({
				"target": target, "amount": amt
			})
		"mana_gain":
			return "{target} gains mana!".format({"target": target})
		_:
			return "{attacker} uses {effect_name} on {target}!".format({
				"attacker": attacker, "effect_name": name, "target": target
			})

# Execute the effect - override in subclasses or use generic processing
func execute(context: Dictionary = {}) -> void:
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())
	var target_is_player = _determine_target_is_player(is_player_turn)

	match effect_type:
		"heal":
			_execute_heal(amount, target_is_player)
			_emit_log(context)
		"damage":
			_execute_damage(amount, target_is_player, is_player_turn, context)
			_emit_log(context)
		"damage_with_buff":
			_execute_damage_with_buff(amount, target_is_player, is_player_turn, context)
			_emit_log(context)
		"damage_with_lifesteal":
			_execute_damage_with_lifesteal(amount, target_is_player, is_player_turn)
			# Logging handled internally
		"damage_with_shields":
			_execute_damage_with_shields(amount, target_is_player, is_player_turn)
			# Logging handled internally
		"vigor_damage":
			_execute_vigor_damage(amount, target_is_player, is_player_turn, context)
			_emit_log(context)
		"shield":
			_execute_shield(amount, target_is_player)
			# Logging handled by CombatLogBus
		"mana_gain":
			_execute_mana_gain(effects, target_is_player)
			_emit_log(context)
		"mana_gain_formatted":
			_execute_mana_gain_formatted(context)
			# Logging handled internally
		"channel":
			_execute_channel(context)
			# Logging handled internally
		"shields_to_health":
			_execute_shields_to_health(target_is_player)
			# Logging handled internally
		"drain_with_heal":
			_execute_drain_with_heal(context)
			# Logging handled internally
		"explosion", "sinker_explosion":
			_execute_sinker_explosion(context)
			# Logging handled internally
		"sinker_damage":
			_execute_sinker_damage(context)
			# Logging handled internally
		"sinker_random_tiles":
			_execute_sinker_random_tiles(context)
			# Logging handled internally
		"sinker_column_clear":
			_execute_sinker_column_clear(context)
			# Logging handled internally
		"sinker_row_clear":
			_execute_sinker_row_clear(context)
			# Logging handled internally
		"sinker_v_formation":
			_execute_sinker_v_formation(context)
			# Logging handled internally
		_:
			push_warning("Unknown effect type: " + effect_type)

func _emit_log(context: Dictionary) -> void:
	# Emit log for simple effects that don't handle their own logging
	# Prepare last_log_* so caller can decide when/how to publish (keeps queue ordering)
	last_log_message = ""
	last_log_icon = null
	var log_vars = context.duplicate()
	log_vars["amount"] = amount
	var message = get_formatted_log_message(log_vars)
	if message:
		last_log_message = message
		last_log_icon = texture


# Compute a canonical single-target for VFX from a list of grid_cells.
# - If grid_cells is present, we average their grid coordinates to produce a
#   canonical `grid_cell` (float coords) and compute `target_position` by
#   averaging the world pixels and projecting into the provided viewport.
# - If no grid_cells are present but a `grid_cell` or `position` exists in the
#   context, we will attempt to compute a `target_position` for that cell.
func _compute_and_set_canonical_target(context: Dictionary) -> void:
	var gc: Array = context.get("grid_cells", [])
	var vp = null
	if typeof(GDM) != TYPE_NIL and GDM and GDM.game_manager and GDM.game_manager.get_viewport():
		vp = GDM.game_manager.get_viewport()

	if gc and gc.size() > 0:
		# Average grid coordinates
		var sum_grid = Vector2(0.0, 0.0)
		for c in gc:
			if typeof(c) == TYPE_VECTOR2:
				sum_grid += Vector2(float(c.x), float(c.y))
			else:
				# try to coerce
				sum_grid += Vector2(float(c["x"]), float(c["y"]))
		var cnt = max(gc.size(), 1)
		var avg_grid = sum_grid / float(cnt)
		context["grid_cell"] = Vector2(float(avg_grid.x), float(avg_grid.y))

		# If we can project to a viewport, average world pixels then project to normalized target
		if vp:
			var sum_world = Vector2(0.0, 0.0)
			for c2 in gc:
				var col_i = int(floor(c2.x))
				var row_f = float(c2.y)
				var world_px = GDM.grid.grid_to_pixel(col_i, row_f)
				sum_world += world_px
			var avg_world = sum_world / float(cnt)
			var avg_screen = GDM.grid.world_to_viewport_pixels(avg_world, vp)
			var vp_size = vp.get_visible_rect().size
			context["target_position"] = Vector2(avg_screen.x / max(vp_size.x, 1.0), avg_screen.y / max(vp_size.y, 1.0))
		return

	# No grid_cells: attempt to derive from existing grid_cell or position
	if context.has("grid_cell"):
		var gc2 = context["grid_cell"]
		context["grid_cell"] = Vector2(float(gc2.x), float(gc2.y))
		if vp:
			context["target_position"] = GDM.grid.grid_cell_to_normalized_target(int(gc2.x), float(gc2.y), vp)
		return

	if context.has("position"):
		var pos = context["position"]
		if typeof(pos) == TYPE_VECTOR2:
			context["grid_cell"] = Vector2(float(pos.x), float(pos.y))
			if vp:
				context["target_position"] = GDM.grid.grid_cell_to_normalized_target(int(pos.x), float(pos.y), vp)
		return

func _determine_target_is_player(is_player_turn: bool) -> bool:
	match target_type:
		"player":
			return true
		"monster":
			return false
		"self":
			return is_player_turn
		"enemy":
			return not is_player_turn
		"auto":
			var is_beneficial = _is_beneficial_effect()
			# For beneficial effects like healing/shields, target should be the caster
			# For harmful effects like damage, target should be the enemy
			if is_beneficial:
				return is_player_turn  # Beneficial effects go to whoever is taking the turn
			else:
				return not is_player_turn  # Harmful effects go to the opponent
		_:
			return is_player_turn

func _execute_heal(heal_amount: int, target_is_player: bool) -> void:
	if target_is_player:
		GDM.effect_manager.heal_player(heal_amount)
		EventBus.do_player_regenerate.emit(heal_amount)
	else:
		GDM.effect_manager.heal_monster(heal_amount)
		EventBus.do_monster_regenerate.emit(heal_amount)

func _execute_damage(damage_amount: int, _target_is_player: bool, attacker_is_player: bool, context: Dictionary = {}) -> void:
	# Use the existing centralized damage system
	var actual_damage = context.get("damage", damage_amount)
	var applied = CombatManager.apply_damage_with_checks(actual_damage, "", attacker_is_player, false, bypass_shields, false)

	# Emit combat log message
	var damage_log_vars = {"damage": applied}
	var message = get_formatted_log_message(damage_log_vars)
	if message:
		last_log_message = message
		last_log_icon = texture

func _execute_damage_with_buff(damage_amount: int, _target_is_player: bool, attacker_is_player: bool, context: Dictionary = {}) -> void:
	# Apply damage first
	var actual_damage = context.get("damage", damage_amount)
	var damage_applied = CombatManager.apply_damage_with_checks(actual_damage, "", attacker_is_player, false, bypass_shields, false)

	# Apply buff if damage landed
	if damage_applied > 0:
		var buff_path = effects.get("buff_path", "")
		if buff_path:
			var buff = load(buff_path).duplicate()
			if attacker_is_player:
				CombatManager.apply_buff_to_player(buff)
			else:
				CombatManager.apply_buff_to_monster(buff)

	# Emit combat log message
	var damage_log_vars = {"damage": damage_applied}
	var message = get_formatted_log_message(damage_log_vars)
	if message:
		last_log_message = message
		last_log_icon = texture

func _execute_damage_with_lifesteal(damage_amount: int, _target_is_player: bool, attacker_is_player: bool) -> void:
	# Apply damage first and get the actual applied amount
	var applied = CombatManager.apply_damage_with_checks(damage_amount, "", attacker_is_player, false, bypass_shields, false)

	# Apply lifesteal based on actual damage dealt
	if applied > 0:
		var lifesteal_percent = effects.get("lifesteal_percent", 100)
		var heal_amount = int(applied * lifesteal_percent / 100.0)
		if heal_amount > 0:
			if attacker_is_player:
				GDM.effect_manager.heal_player(heal_amount)
				EventBus.do_player_regenerate.emit(heal_amount)
			else:
				GDM.effect_manager.heal_monster(heal_amount)
				EventBus.do_monster_regenerate.emit(heal_amount)

			# Update the context for logging
			var lifesteal_log_vars = {"heal": heal_amount, "damage": applied}
			var lifesteal_message = get_formatted_log_message(lifesteal_log_vars)
			if lifesteal_message:
				last_log_message = lifesteal_message
				last_log_icon = texture
			return  # Early return to avoid duplicate logging

	# Standard damage logging if no lifesteal occurred
	var damage_log_vars = {"damage": applied}
	var damage_message = get_formatted_log_message(damage_log_vars)
	if damage_message:
		last_log_message = damage_message
		last_log_icon = texture

func _execute_damage_with_shields(damage_amount: int, _target_is_player: bool, attacker_is_player: bool) -> void:
	# Apply damage first and get the actual applied amount
	var applied = CombatManager.apply_damage_with_checks(damage_amount, "", attacker_is_player, false, bypass_shields, false)

	# Grant shields to attacker based on damage dealt
	if applied > 0:
		var shield_percent = effects.get("shield_percent", 50)
		var shield_amount = int(applied * shield_percent / 100.0)
		if shield_amount > 0:
			GDM.effect_manager.add_shields(shield_amount, attacker_is_player)
			if attacker_is_player:
				EventBus.do_player_gain_shields.emit(shield_amount, texture, GDM.player.character.name)
			else:
				EventBus.do_monster_gain_shields.emit(shield_amount, texture, GDM.monster_to_fight.name)

			# Update the context for logging
			var shield_log_vars = {"shields": shield_amount, "damage": applied}
			var shield_message = get_formatted_log_message(shield_log_vars)
			if shield_message:
				last_log_message = shield_message
				last_log_icon = texture
			return  # Early return to avoid duplicate logging

	# Standard damage logging if no shields occurred
	var standard_log_vars = {"damage": applied}
	var standard_message = get_formatted_log_message(standard_log_vars)
	if standard_message:
		last_log_message = standard_message
		last_log_icon = texture

func _execute_vigor_damage(damage_amount: int, target_is_player: bool, attacker_is_player: bool, context: Dictionary = {}) -> void:
	# Check if orange mana requirement is met
	var required_orange = effects.get("requires_orange_mana", 0)
	if required_orange > 0:
		var mana_dict = context.get("mana_dict", {})
		var orange_mana = mana_dict.get("orange", 0)
		if orange_mana < required_orange:
			# Fall back to normal damage if orange mana requirement not met
			_execute_damage(damage_amount, target_is_player, attacker_is_player, context)
			return

	# Vigor shield doubling logic
	var shield_val = 0
	if attacker_is_player:
		shield_val = GDM.effect_manager.get_current_monster_shields()
	else:
		shield_val = GDM.effect_manager.get_current_player_shields()

	var shield_damage = min(damage_amount, shield_val)
	var hp_damage = max(0, damage_amount - shield_val)
	var doubled_shield_damage = shield_damage * 2

	# Apply doubled shield damage (suppress individual logging)
	if shield_damage > 0:
		CombatManager.apply_damage_with_checks(doubled_shield_damage, "", attacker_is_player, false, false, false)

	# Apply normal HP damage (suppress individual logging)
	if hp_damage > 0:
		CombatManager.apply_damage_with_checks(hp_damage, "", attacker_is_player, false, false, false)

	# Single comprehensive log message
	var total_damage = doubled_shield_damage + hp_damage
	var log_vars = {"damage": total_damage}
	var message = get_formatted_log_message(log_vars)
	if message:
		last_log_message = message
		last_log_icon = texture

func _execute_shield(shield_amount: int, target_is_player: bool) -> void:
	GDM.effect_manager.add_shields(shield_amount, target_is_player)
	if target_is_player:
		EventBus.do_player_gain_shields.emit(shield_amount, texture, GDM.player.character.name)
	else:
		EventBus.do_monster_gain_shields.emit(shield_amount, texture, GDM.monster_to_fight.name)

func _execute_mana_gain(mana_dict: Dictionary, target_is_player: bool) -> void:
	# Direct mana application without calling the CombatManager functions to avoid recursion
	if target_is_player and GDM.game_manager and GDM.game_manager.mana:
		var player_mana = GDM.game_manager.mana.player
		var max_mana = GDM.player.stats.calculate_max_mana()
		for color in mana_dict.keys():
			var gain_amount = mana_dict[color]
			if gain_amount > 0:
				player_mana[color] = clampi(player_mana[color] + gain_amount, 0, max_mana[color])
		EventBus.do_player_gain_mana.emit(mana_dict)
		EventBus.update_mana.emit(player_mana)
	elif not target_is_player and GDM.game_manager and GDM.game_manager.mana:
		var monster_mana = GDM.game_manager.mana.enemy
		var max_mana = GDM.game_manager.MONSTER_MAX_MANA
		for color in mana_dict.keys():
			var gain_amount = mana_dict[color]
			if gain_amount > 0:
				monster_mana[color] = clampi(monster_mana[color] + gain_amount, 0, max_mana[color])
		EventBus.do_monster_gain_mana.emit(mana_dict)
		EventBus.update_mana.emit(monster_mana)

func _execute_mana_gain_formatted(context: Dictionary) -> void:
	# Handle formatted mana gain with proper logging
	var mana_dict = context.get("mana_dict", {})
	var target_is_player = context.get("target_is_player", false)

	if target_is_player:
		CombatManager.apply_mana_gain_to_player(mana_dict)
	else:
		CombatManager.apply_mana_gain_to_monster(mana_dict)

	# Format mana for logging
	var log_parts = []
	for color in mana_dict.keys():
		if mana_dict[color] > 0:
			log_parts.append("{amount} {color}".format({"amount": mana_dict[color], "color": color}))

	if log_parts.size() > 0:
		var mana_text = " and ".join(log_parts)
		var mana_log_vars = {"mana": mana_text}
		var mana_message = get_formatted_log_message(mana_log_vars)
		if mana_message:
			last_log_message = mana_message
			last_log_icon = texture

func _execute_channel(context: Dictionary) -> void:
	# Channel effect - always targets self (the caster)
	var ability = context.get("ability")
	var mana = GDM.game_manager.mana
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())
	var target_is_player = _determine_target_is_player(is_player_turn)

	if not ability or not mana:
		push_warning("Channel effect missing required context")
		return

	# Get channel color from ability.effects (original logic)
	var channel_color = null
	if ability.effects.has("channel"):
		channel_color = ability.effects["channel"]
	elif effects.has("channel"):
		channel_color = effects["channel"]

	var valid_colors = ["red", "green", "blue", "orange", "pink"]
	if channel_color != null and channel_color in valid_colors:
		# Use target_is_player to determine which mana pool to modify (this should be the caster)
		var update_dict: Dictionary = mana.player if target_is_player else mana.enemy
		var drained: Dictionary = {}
		var total_drained: int = 0
		for c in valid_colors:
			if c == channel_color:
				continue
			var amt = update_dict.get(c, 0)
			drained[c] = amt
			total_drained += amt
			update_dict[c] = 0
		# transfer total to target color
		if total_drained > 0:
			update_dict[channel_color] = update_dict.get(channel_color, 0) + total_drained
			# Emit same events as mana drains so UI / logs update
			#EventBus.publish_mana_drain.emit(drained)

			# Publish channel-specific event for separate combat-log handling
			EventBus.publish_channel_mana.emit(drained, channel_color, target_is_player, total_drained)
			EventBus.do_channel_mana.emit(update_dict, target_is_player)

			# Request a visual effect for channeling (ensure the channel shader plays)
			var vfx_params = {}
			# Resolve color from FW_Colors.gd if available
			if typeof(channel_color) == TYPE_STRING and FW_Colors.has_color(str(channel_color)):
				vfx_params["effect_color"] = FW_Colors.get_color(str(channel_color))
			else:
				vfx_params["effect_color"] = Color(1.0, 0.333, 0.333, 1.0)
			vfx_params["duration"] = 1.2
			vfx_params["intensity"] = 0.9
			if EventBus.has_signal("ability_visual_effect_requested"):
				EventBus.ability_visual_effect_requested.emit("channel_filter", vfx_params)
			# Prepare generic log for channel - caller will publish in queue order
			var owner_name = GDM.player.character.name if target_is_player else GDM.monster_to_fight.name
			last_log_message = "{owner} channels mana into {color} and gains {amount}!".format({
				"owner": owner_name,
				"color": channel_color,
				"amount": total_drained 
			})
			last_log_icon = null

func _execute_shields_to_health(target_is_player: bool) -> void:
	# Calculate conversion amount: min(missing_health, current_shields)
	var current_hp: int
	var max_hp: int
	var current_shields: int

	if target_is_player:
		current_hp = GDM.effect_manager.get_current_player_hp()
		max_hp = GDM.effect_manager.get_player_max_hp()
		current_shields = GDM.effect_manager.get_current_player_shields()
	else:
		current_hp = GDM.effect_manager.get_current_monster_hp()
		max_hp = GDM.effect_manager.get_monster_max_hp()
		current_shields = GDM.effect_manager.get_current_monster_shields()

	var missing_hp: int = max_hp - current_hp
	var conversion_amount: int = min(missing_hp, current_shields)

	# Only proceed if there's something to convert
	if conversion_amount > 0:
		# Remove shields
		if target_is_player:
			GDM.effect_manager.update_player_shields(current_shields - conversion_amount)
		else:
			GDM.effect_manager.update_monster_shields(current_shields - conversion_amount)

		# Add health
		if target_is_player:
			GDM.effect_manager.heal_player(conversion_amount)
		else:
			GDM.effect_manager.heal_monster(conversion_amount)

		# Prepare log message
		var log_vars = {
			"shields": conversion_amount,
			"health": conversion_amount,
			"amount": conversion_amount
		}
		last_log_message = get_formatted_log_message(log_vars)
		last_log_icon = texture
	else:
		# No conversion possible - either full health or no shields
		var attacker_name = GDM.player.character.name if target_is_player else GDM.monster_to_fight.name
		if missing_hp <= 0:
			last_log_message = "{attacker} is already at full health!".format({"attacker": attacker_name})
		else:
			last_log_message = "{attacker} has no shields to convert!".format({"attacker": attacker_name})
		last_log_icon = texture

func _execute_drain_with_heal(context: Dictionary) -> void:
	# Drain mana from opponent and heal caster for the amount drained
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())

	# Get drain dictionary from context (passed from ability) or fallback to effects
	var drain_dict = context.get("drain_dict", effects.get("drain", {}))

	if drain_dict.is_empty():
		last_log_message = "No mana to drain!"
		last_log_icon = texture
		return

	# Get the current mana state
	var mana = GDM.game_manager.mana
	if not mana:
		last_log_message = "Mana system not available!"
		last_log_icon = texture
		return

	# Determine which mana pool to drain from
	var target_mana: Dictionary
	if is_player_turn:
		target_mana = mana.enemy  # Player drains from enemy
	else:
		target_mana = mana.player  # Monster drains from player

	# Calculate actual drained amounts
	var total_drained = 0
	var drained_mana: Dictionary = {}

	for color in drain_dict.keys():
		var drain_amount = drain_dict[color]
		var current_value = target_mana.get(color, 0)
		var actual_drain = min(drain_amount, current_value)

		if actual_drain > 0:
			drained_mana[color] = actual_drain
			target_mana[color] = current_value - actual_drain
			total_drained += actual_drain

	# Apply healing to caster if mana was drained
	if total_drained > 0:
		# Heal the caster
		if is_player_turn:
			GDM.effect_manager.heal_player(total_drained)
		else:
			GDM.effect_manager.heal_monster(total_drained)

		# Emit mana drain events
		EventBus.publish_mana_drain.emit(drained_mana)
		EventBus.do_mana_drain.emit(target_mana)

		# Prepare log message with actual amounts
		var log_vars = {
			"drained": total_drained,
			"healed": total_drained,
			"amount": total_drained
		}
		last_log_message = get_formatted_log_message(log_vars)
		last_log_icon = texture
	else:
		# No mana was available to drain
		var attacker_name = GDM.player.character.name if is_player_turn else GDM.monster_to_fight.name
		last_log_message = "{attacker} finds no mana to drain!".format({"attacker": attacker_name})
		last_log_icon = texture

func _execute_sinker_explosion(context: Dictionary) -> void:
	# Handle sinker explosion effect - destroys tiles in a smart 3x3 pattern
	var grid = context.get("grid")
	var position = context.get("position", Vector2.ZERO)
	var levels = effects.get("levels", 3)
	var damage_amount = effects.get("damage", amount)
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())

	if not grid or not grid.has_method("apply_sinker_explosion"):
		push_warning("Grid context missing or doesn't support sinker explosion")
		return

	# PRESERVE original sinker position for visual effects targeting
	var original_sinker_cell = context.get("grid_cell", Vector2.ZERO)
	var original_target_position = context.get("target_position", Vector2.ZERO)

	# Apply the explosion effect to the grid
	var tiles_destroyed = grid.apply_sinker_explosion(position, levels)

	# Populate canonical grid_cells for VFX projection so scene/shader effects
	# can target the actual tiles that were destroyed. We reconstruct the
	# 3xN area around the sinker center (same logic as Grid.apply_sinker_explosion).
	var center_col = int(position.x)
	var center_row = int(position.y)
	var start_col: int
	var end_col: int
	if center_col == 0:
		start_col = 0
		end_col = min(2, GDM.grid.width - 1)
	elif center_col >= GDM.grid.width - 1:
		start_col = max(0, GDM.grid.width - 3)
		end_col = GDM.grid.width - 1
	else:
		start_col = max(0, center_col - 1)
		end_col = min(GDM.grid.width - 1, center_col + 1)
	var gc_explosion: Array = []
	for col in range(start_col, end_col + 1):
		for level_i in range(levels):
			var target_row = center_row + level_i
			var target_pos = Vector2(col, target_row)
			if GDM.grid.is_in_grid(target_pos):
				gc_explosion.append(Vector2(float(col), float(target_row)))
	context["grid_cells"] = gc_explosion
	
	# For visual effects: keep the original sinker position, not the explosion area average
	# Override the canonical target computation to use sinker position
	context["grid_cell"] = original_sinker_cell  # Restore original sinker position
	context["target_position"] = original_target_position  # Restore original target position
	
	# Apply damage if specified
	if damage_amount > 0:
		var applied = CombatManager.apply_damage_with_checks(damage_amount, "", is_player_turn, false, bypass_shields, false)

		# Apply healing to caster if specified
		var heal_amount = effects.get("heal_amount", 0)
		if heal_amount > 0:
			if is_player_turn:
				GDM.effect_manager.heal_player(heal_amount)
			else:
				GDM.effect_manager.heal_monster(heal_amount)

		# Prepare comprehensive log message with proper template variables
		var sinker_ability = context.get("sinker_ability")
		var attacker_name = ""
		if is_player_turn:
			attacker_name = GDM.player.character.name if GDM.player else "Player"
		else:
			attacker_name = GDM.monster_to_fight.name if GDM.monster_to_fight else "Monster"

		var log_vars = {
			"tiles_destroyed": tiles_destroyed,
			"damage": applied,
			"position": position,
			"ability_name": sinker_ability.name if sinker_ability else name,
			"attacker": attacker_name
		}
		last_log_message = get_formatted_log_message(log_vars)
		last_log_icon = texture

func _execute_sinker_damage(context: Dictionary) -> void:
	# Handle basic sinker damage (fallback for sinkers without special effects)
	var damage_amount = effects.get("damage", amount)
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())

	if damage_amount > 0:
		var applied = CombatManager.apply_damage_with_checks(damage_amount, "", is_player_turn, false, bypass_shields, false)

		# Prepare log message with proper template variables
		var sinker_ability = context.get("sinker_ability")
		var attacker_name = ""
		if is_player_turn:
			attacker_name = GDM.player.character.name if GDM.player else "Player"
		else:
			attacker_name = GDM.monster_to_fight.name if GDM.monster_to_fight else "Monster"

		var log_vars = {
			"damage": applied,
			"ability_name": sinker_ability.name if sinker_ability else name,
			"attacker": attacker_name
		}
		last_log_message = get_formatted_log_message(log_vars)
		last_log_icon = texture

func _execute_sinker_random_tiles(context: Dictionary) -> void:
	# Handle Jadestrike-style effect: destroy random tiles + grant shields
	var grid = context.get("grid")
	var position = context.get("position", Vector2.ZERO)
	var tile_count = effects.get("tile_count", 8)
	var damage_amount = effects.get("damage", amount)
	var shield_gain = effects.get("shield_gain", 0)
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())

	if not grid or not grid.has_method("destroy_random_tiles"):
		push_warning("Grid context missing or doesn't support random tiles destruction")
		return

	# PRESERVE original sinker position for visual effects targeting
	var original_sinker_cell = context.get("grid_cell", Vector2.ZERO)
	var original_target_position = context.get("target_position", Vector2.ZERO)

	# Apply random tile destruction
	var tiles_to_destroy = grid.destroy_random_tiles(position, tile_count)
	var tiles_destroyed = tiles_to_destroy.size()

	# Add destroyed tile coordinates to context for visual effects (canonical)
	var gc: Array = []
	for p in tiles_to_destroy:
		if typeof(p) == TYPE_VECTOR2:
			gc.append(Vector2(float(p.x), float(p.y)))
	context["grid_cells"] = gc

	# For visual effects: keep the original sinker position, not the random tiles average
	# Override the canonical target computation to use sinker position
	context["grid_cell"] = original_sinker_cell  # Restore original sinker position
	context["target_position"] = original_target_position  # Restore original target position

	# Apply damage if specified
	var applied_damage = 0
	if damage_amount > 0:
		applied_damage = CombatManager.apply_damage_with_checks(damage_amount, "", is_player_turn, false, bypass_shields, false)

	# Grant shields to caster
	if shield_gain > 0:
		GDM.effect_manager.add_shields(shield_gain, is_player_turn)

	# Prepare log message
	var sinker_ability = context.get("sinker_ability")
	var attacker_name = GDM.player.character.name if is_player_turn else GDM.monster_to_fight.name
	var log_vars = {
		"tiles_destroyed": tiles_destroyed,
		"damage": applied_damage,
		"shield_gain": shield_gain,
		"ability_name": sinker_ability.name if sinker_ability else name,
		"attacker": attacker_name
	}
	last_log_message = get_formatted_log_message(log_vars)
	last_log_icon = texture

func _execute_sinker_column_clear(context: Dictionary) -> void:
	# Handle Rage Bomb-style effect: clear random column + apply buff
	var grid = context.get("grid")
	var damage_amount = effects.get("damage", amount)
	var buff_path = effects.get("buff_path", "")
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())

	if not grid or not grid.has_method("apply_column_clear"):
		push_warning("Grid context missing or doesn't support column clear")
		return

	# PRESERVE original sinker position for visual effects targeting
	var original_sinker_cell = context.get("grid_cell", Vector2.ZERO)
	var original_target_position = context.get("target_position", Vector2.ZERO)

	# Apply random column clear
	var column_cleared = grid.apply_column_clear()

	# Populate grid_cells for visuals: all rows in the cleared column
	var gc_col: Array = []
	for r in range(GDM.grid.height):
		if GDM.grid.is_in_grid(Vector2(column_cleared, r)):
			gc_col.append(Vector2(float(column_cleared), float(r)))
	context["grid_cells"] = gc_col

	# For visual effects: keep the original sinker position, not the column average
	# Override the canonical target computation to use sinker position
	context["grid_cell"] = original_sinker_cell  # Restore original sinker position
	context["target_position"] = original_target_position  # Restore original target position

	# Apply damage if specified
	var applied_damage = 0
	if damage_amount > 0:
		applied_damage = CombatManager.apply_damage_with_checks(damage_amount, "", is_player_turn, false, bypass_shields, false)

	# Apply buff if specified
	if buff_path != "":
		var buff = load(buff_path)
		if buff and is_player_turn:
			# Apply buff to player (assuming buff system exists)
			if GDM.player and GDM.player.has_method("apply_buff"):
				GDM.player.apply_buff(buff)

	# Prepare log message
	var sinker_ability = context.get("sinker_ability")
	var attacker_name = GDM.player.character.name if is_player_turn else GDM.monster_to_fight.name
	var log_vars = {
		"column_cleared": column_cleared,
		"damage": applied_damage,
		"ability_name": sinker_ability.name if sinker_ability else name,
		"attacker": attacker_name
	}
	last_log_message = get_formatted_log_message(log_vars)
	last_log_icon = texture

func _execute_sinker_row_clear(context: Dictionary) -> void:
	# Handle Stormsurge-style effect: clear random row + apply buff
	var grid = context.get("grid")
	var damage_amount = effects.get("damage", amount)
	var buff_path = effects.get("buff_path", "")
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())

	if not grid or not grid.has_method("apply_row_clear"):
		push_warning("Grid context missing or doesn't support row clear")
		return

	# PRESERVE original sinker position for visual effects targeting
	var original_sinker_cell = context.get("grid_cell", Vector2.ZERO)
	var original_target_position = context.get("target_position", Vector2.ZERO)

	# Apply random row clear
	var row_cleared = grid.apply_row_clear()

	# Populate grid_cells for visuals: all columns in the cleared row
	var gc_row: Array = []
	for c in range(GDM.grid.width):
		if GDM.grid.is_in_grid(Vector2(c, row_cleared)):
			gc_row.append(Vector2(float(c), float(row_cleared)))
	context["grid_cells"] = gc_row
	
	# For visual effects: keep the original sinker position, not the row average
	# Override the canonical target computation to use sinker position
	context["grid_cell"] = original_sinker_cell  # Restore original sinker position
	context["target_position"] = original_target_position  # Restore original target position
	
	# Apply damage if specified
	var applied_damage = 0
	if damage_amount > 0:
		applied_damage = CombatManager.apply_damage_with_checks(damage_amount, "", is_player_turn, false, bypass_shields, false)

	# Apply buff if specified
	if buff_path != "":
		var buff = load(buff_path)
		if buff and is_player_turn:
			# Apply buff to player
			if GDM.player and GDM.player.has_method("apply_buff"):
				GDM.player.apply_buff(buff)

	# Prepare log message
	var sinker_ability = context.get("sinker_ability")
	var attacker_name = GDM.player.character.name if is_player_turn else GDM.monster_to_fight.name
	var log_vars = {
		"row_cleared": row_cleared,
		"damage": applied_damage,
		"ability_name": sinker_ability.name if sinker_ability else name,
		"attacker": attacker_name
	}
	last_log_message = get_formatted_log_message(log_vars)
	last_log_icon = texture

func _execute_sinker_v_formation(context: Dictionary) -> void:
	# Handle Coral Burst-style effect: V-formation clear + bypass damage
	var grid = context.get("grid")
	var position = context.get("position", Vector2.ZERO)
	var damage_amount = effects.get("damage", amount)
	var bypass = effects.get("bypass_shields", true)
	var is_player_turn = context.get("is_player_turn", GDM.game_manager.turn_manager.is_player_turn())

	if not grid or not grid.has_method("apply_v_formation_clear"):
		push_warning("Grid context missing or doesn't support V-formation clear")
		return

	# PRESERVE original sinker position for visual effects targeting
	var original_sinker_cell = context.get("grid_cell", Vector2.ZERO)
	var original_target_position = context.get("target_position", Vector2.ZERO)

	# Apply V-formation clear
	var tiles_destroyed = grid.apply_v_formation_clear(position)

	# Populate grid_cells for visuals created by the V-formation so effects
	# that accept multi-target coordinates can project correctly.
	var center_col = int(position.x)
	var start_row = int(position.y)
	var gc_v: Array = []
	for level in range(GDM.grid.height - start_row):
		var current_row = start_row + level
		if current_row >= GDM.grid.height:
			break
		var left_col = center_col - level
		var right_col = center_col + level
		# center only at the apex
		if level == 0 and GDM.grid.is_in_grid(Vector2(center_col, current_row)):
			gc_v.append(Vector2(float(center_col), float(current_row)))
		# left
		if left_col != center_col and GDM.grid.is_in_grid(Vector2(left_col, current_row)):
			gc_v.append(Vector2(float(left_col), float(current_row)))
		# right
		if right_col != center_col and right_col != left_col and GDM.grid.is_in_grid(Vector2(right_col, current_row)):
			gc_v.append(Vector2(float(right_col), float(current_row)))
	context["grid_cells"] = gc_v
	
	# For visual effects: keep the original sinker position, not the V-formation average
	# Override the canonical target computation to use sinker position
	context["grid_cell"] = original_sinker_cell  # Restore original sinker position
	context["target_position"] = original_target_position  # Restore original target position
	
	# Apply bypass damage if specified
	var applied_damage = 0
	if damage_amount > 0:
		applied_damage = CombatManager.apply_damage_with_checks(damage_amount, "", is_player_turn, false, bypass, false)

	# Prepare log message
	var sinker_ability = context.get("sinker_ability")
	var attacker_name = GDM.player.character.name if is_player_turn else GDM.monster_to_fight.name
	var log_vars = {
		"tiles_destroyed": tiles_destroyed,
		"damage": applied_damage,
		"ability_name": sinker_ability.name if sinker_ability else name,
		"attacker": attacker_name
	}
	last_log_message = get_formatted_log_message(log_vars)
	last_log_icon = texture
