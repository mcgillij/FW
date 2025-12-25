extends Resource

class_name FW_Buff

enum buff_type { discrete, scaling }
enum buff_category { beneficial, harmful }

@export var name: String
@export var duration: int # Duration in turns
@export var duration_left: int
@export var effect_strength: float # Strength of the effect
@export var stat_target: String # The stat this buff affects (e.g., "bark", "vigor")
@export var texture: Texture2D
@export var type: buff_type
@export var category: buff_category = buff_category.beneficial # Whether this buff helps or harms
@export var owner_type: String = "player" # "player" or "monster"
@export var caster_type: String = "player" # "player" or "monster" - who cast this buff
@export var log_message: String = ""  # Templated log message for buff application/expiration
var applied: bool = false

func get_formatted_log_message(vars: Dictionary = {}) -> String:
	# Default vars
	var default_vars = {
		"caster": get_caster_name(),
		"effect_strength": str(self.effect_strength),
		"duration": str(self.duration),
		"effect_strength_percent": str(int(self.effect_strength * 100)) + "%"
	}
	# Merge with provided vars
	for key in vars.keys():
		var key_str := str(key)
		default_vars[key_str] = vars[key]
	if log_message and log_message.strip_edges() != "":
		var formatted = log_message.format(default_vars)
		return formatted.strip_edges()
	return ""

func get_owner_name() -> String:
	if owner_type == "monster":
		return GDM.monster_to_fight.name
	else:
		return GDM.player.character.name

func get_caster_name() -> String:
	# Use the explicit caster_type if set, otherwise fall back to inference
	if caster_type != "":
		if caster_type == "monster":
			return GDM.monster_to_fight.name if GDM.monster_to_fight else "Monster"
		else:
			return GDM.player.character.name if GDM.player else "Player"
	else:
		# Fallback to old inference logic for backward compatibility
		if category == buff_category.harmful:
			# For harmful buffs, caster is the opposite of owner
			if owner_type == "monster":
				return GDM.player.character.name
			else:
				return GDM.monster_to_fight.name
		else:
			# For beneficial buffs, caster is the owner
			return get_owner_name()

func _get_stats_target() -> FW_StatsManager:
	# Centralized logic to choose the correct StatsManager for this buff's owner.
	var stats_target: FW_StatsManager = null
	if GDM.effect_manager and GDM.effect_manager.is_using_generic_combatants():
		if owner_type == "monster":
			stats_target = GDM.effect_manager.opponent_combatant.stats
		else:
			stats_target = GDM.effect_manager.player_combatant.stats
	else:
		if owner_type == "monster":
			stats_target = GDM.monster_to_fight.stats
		else:
			stats_target = GDM.player.stats
	return stats_target

func activate() -> void:
	applied = true
	if stat_target and type == buff_type.discrete:
		@warning_ignore("narrowing_conversion")
		var stats_target: FW_StatsManager = _get_stats_target()
		if stats_target:
			stats_target.apply_temporary_bonus(self.stat_target, self.effect_strength)
	# Emit log if message is set (deferred to ensure CombatLogBus is ready)
	if log_message:
		# Defer the signal emission until all nodes are ready
		call_deferred("_emit_booster_effect_signal")

# Function to apply the buff effect per turn, if needed
func apply_per_turn_effects() -> void:
	duration_left -= 1
	if stat_target and type == buff_type.scaling:
		@warning_ignore("narrowing_conversion")
		var stats_target: FW_StatsManager = _get_stats_target()
		if stats_target:
			stats_target.apply_temporary_bonus(self.stat_target, self.effect_strength)
	if duration_left <= 0:
		on_expire()

# Function to call when the buff expires
func on_expire() -> void:
	# Remove the buff effect from the player or monster
	if owner_type == "player":
		EventBus.player_remove_buff.emit(self)
		EventBus.player_publish_buff_expire.emit(self)
	elif owner_type == "monster":
		EventBus.monster_remove_buff.emit(self)
		EventBus.monster_publish_buff_expire.emit(self)
	# Emit generic log if message is set
	if log_message:
		EventBus.do_booster_effect.emit(self, "expired")
	# reduce state appropriately
	if stat_target:
		@warning_ignore("narrowing_conversion")
		var stats_target: FW_StatsManager = _get_stats_target()
		if stats_target:
			if type == buff_type.discrete:
				stats_target._on_temporary_bonus_timeout(stat_target, effect_strength)
			elif type == buff_type.scaling:
				stats_target._on_temporary_bonus_timeout(stat_target, (effect_strength * duration))
	applied = false

func _to_string() -> String:
	return "[Buff: %s]" % [name]

# Helper method to emit owner-specific healing signals
func emit_heal_effect(amount: int) -> void:
	if owner_type == "monster":
		GDM.effect_manager.heal_monster(amount)
		EventBus.do_monster_regenerate.emit(amount)
	else:
		GDM.effect_manager.heal_player(amount)
		EventBus.do_player_regenerate.emit(amount)

# Helper method to emit owner-specific shield gain signals
func emit_shield_effect(amount: int) -> void:
	if owner_type == "monster":
		GDM.effect_manager.add_shields(amount, false)
		EventBus.do_monster_gain_shields.emit(amount, texture, GDM.monster_to_fight.name)
	else:
		GDM.effect_manager.add_shields(amount, true)
		EventBus.do_player_gain_shields.emit(amount, texture, GDM.player.character.name)

# Helper method to emit owner-specific damage over time signals
func emit_damage_over_time_effect(amount: int, reason: String) -> void:
	if category == buff_category.harmful:
		# Apply damage directly to the owner (bypass regular damage system for DoT)
		if owner_type == "monster":
			GDM.effect_manager.apply_damage(false, amount)
		else:
			GDM.effect_manager.apply_damage(true, amount)
		
		# Publish custom damage over time log message
		var target_name = get_owner_name()
		var text = "%s takes [color=orange]%d[/color] damage%s" % [target_name, amount, reason]
		EventBus.publish_combat_log.emit(text)
		
		# Check for game win/loss after damage
		GDM.game_manager.check_game_win()
	else:
		# For beneficial buffs, heal the owner instead of damage
		if owner_type == "monster":
			GDM.effect_manager.heal_monster(amount)
			EventBus.do_monster_regenerate.emit(amount)
		else:
			GDM.effect_manager.heal_player(amount)
			EventBus.do_player_regenerate.emit(amount)

# Virtual method for buffs to react to damage taken by the owner
func on_damage_taken(_amount: int) -> void:
	pass

# Function to call when the buff owner evades an attack
func on_evasion() -> void:
	pass

# Deferred signal emission helper for combat log
func _emit_booster_effect_signal() -> void:
	# Let CombatLogBus format/publish this via the centralized bus to preserve queue order and aggregation
	EventBus.do_booster_effect.emit(self, "applied")
