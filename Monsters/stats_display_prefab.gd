extends Control

static var setup_call_counter = 0

@onready var name_label: RichTextLabel = %name_label
@onready var hp_label: RichTextLabel = %hp_label
@onready var shields_label: RichTextLabel = %shields_label
@onready var image: TextureRect = %image

@onready var red_affinity: MarginContainer = %red_affinity
@onready var blue_affinity: MarginContainer = %blue_affinity
@onready var green_affinity: MarginContainer = %green_affinity
@onready var orange_affinity: MarginContainer = %orange_affinity
@onready var pink_affinity: MarginContainer = %pink_affinity

@onready var bark_value: Label = %bark_value
@onready var reflex_value: Label = %reflex_value
@onready var alertness_value: Label = %alertness_value
@onready var vigor_value: Label = %vigor_value
@onready var enthusiasm_value: Label = %enthusiasm_value

@onready var red_mana_bonus_value: Label = %red_mana_bonus_value
@onready var red_mana_max_value: Label = %red_mana_max_value
@onready var blue_mana_bonus_value: Label = %blue_mana_bonus_value
@onready var blue_mana_max_value: Label = %blue_mana_max_value
@onready var green_mana_bonus_value: Label = %green_mana_bonus_value
@onready var green_mana_max_value: Label = %green_mana_max_value
@onready var orange_mana_bonus_value: Label = %orange_mana_bonus_value
@onready var orange_mana_max_value: Label = %orange_mana_max_value
@onready var pink_mana_bonus_value: Label = %pink_mana_bonus_value
@onready var pink_mana_max_value: Label = %pink_mana_max_value

@onready var crit_chance_value: Label = %crit_chance_value
@onready var crit_mult_value: Label = %crit_mult_value
@onready var bomb_bonus_value: Label = %bomb_bonus_value
@onready var cooldown_reduction_value: Label = %cooldown_reduction_value
@onready var tenacity_value: Label = %tenacity_value
@onready var luck_value: Label = %luck_value
@onready var shield_recovery_value: Label = %shield_recovery_value
@onready var lifesteal_value: Label = %lifesteal_value
@onready var damage_resistance_value: Label = %damage_resistance_value
@onready var evasion_value: Label = %evasion_value

# labels
@onready var bark_label: Label = %bark_label
@onready var reflex_label: Label = %reflex_label
@onready var alertness_label: Label = %alertness_label
@onready var vigor_label: Label = %vigor_label
@onready var enthusiasm_label: Label = %enthusiasm_label
@onready var crit_chance_label: Label = %crit_chance_label
@onready var crit_mult_label: Label = %crit_mult_label
@onready var bomb_bonus_label: Label = %bomb_bonus_label
@onready var cooldown_reduction_label: Label = %cooldown_reduction_label
@onready var tenacity_label: Label = %tenacity_label
@onready var luck_label: Label = %luck_label
@onready var shield_recovery_label: Label = %shield_recovery_label
@onready var lifesteal_label: Label = %lifesteal_label
@onready var damage_resistance_label: Label = %damage_resistance_label
@onready var evasion_label: Label = %evasion_label
@onready var affinity_bonus_label: Label = %affinity_bonus_label
@onready var affinity_bonus_value: Label = %affinity_bonus_value

# manas
@onready var red_mana_bonus_label: Label = %red_mana_bonus_label
@onready var red_mana_max_label: Label = %red_mana_max_label
@onready var blue_mana_bonus_label: Label = %blue_mana_bonus_label
@onready var blue_mana_max_label: Label = %blue_mana_max_label
@onready var green_mana_bonus_label: Label = %green_mana_bonus_label
@onready var green_mana_max_label: Label = %green_mana_max_label
@onready var orange_mana_bonus_label: Label = %orange_mana_bonus_label
@onready var orange_mana_max_label: Label = %orange_mana_max_label
@onready var pink_mana_bonus_label: Label = %pink_mana_bonus_label
@onready var pink_mana_max_label: Label = %pink_mana_max_label
# mana boxes
@onready var red_mana_bonus_box: MarginContainer = %red_mana_bonus_box
@onready var red_mana_max_box: MarginContainer = %red_mana_max_box
@onready var blue_mana_bonus_box: MarginContainer = %blue_mana_bonus_box
@onready var blue_mana_max_box: MarginContainer = %blue_mana_max_box
@onready var green_mana_bonus_box: MarginContainer = %green_mana_bonus_box
@onready var green_mana_max_box: MarginContainer = %green_mana_max_box
@onready var orange_mana_bonus_box: MarginContainer = %orange_mana_bonus_box
@onready var orange_mana_max_box: MarginContainer = %orange_mana_max_box
@onready var pink_mana_bonus_box: MarginContainer = %pink_mana_bonus_box
@onready var pink_mana_max_box: MarginContainer = %pink_mana_max_box

const STAT_DISPLAY = [
	# Core stats
	{ "key": "bark", "label": "bark_label", "value": "bark_value", "format": "int" },
	{ "key": "reflex", "label": "reflex_label", "value": "reflex_value", "format": "int" },
	{ "key": "alertness", "label": "alertness_label", "value": "alertness_value", "format": "int" },
	{ "key": "vigor", "label": "vigor_label", "value": "vigor_value", "format": "int" },
	{ "key": "enthusiasm", "label": "enthusiasm_label", "value": "enthusiasm_value", "format": "int" },

	# Mana bonuses and max
	{ "key": "red_mana_bonus", "label": "red_mana_bonus_label", "value": "red_mana_bonus_value", "box": "red_mana_bonus_box", "format": "percent" },
	{ "key": "red_mana_max", "label": "red_mana_max_label", "value": "red_mana_max_value", "box": "red_mana_max_box", "format": "int" },
	{ "key": "blue_mana_bonus", "label": "blue_mana_bonus_label", "value": "blue_mana_bonus_value", "box": "blue_mana_bonus_box", "format": "percent" },
	{ "key": "blue_mana_max", "label": "blue_mana_max_label", "value": "blue_mana_max_value", "box": "blue_mana_max_box", "format": "int" },
	{ "key": "green_mana_bonus", "label": "green_mana_bonus_label", "value": "green_mana_bonus_value", "box": "green_mana_bonus_box", "format": "percent" },
	{ "key": "green_mana_max", "label": "green_mana_max_label", "value": "green_mana_max_value", "box": "green_mana_max_box", "format": "int" },
	{ "key": "orange_mana_bonus", "label": "orange_mana_bonus_label", "value": "orange_mana_bonus_value", "box": "orange_mana_bonus_box", "format": "percent" },
	{ "key": "orange_mana_max", "label": "orange_mana_max_label", "value": "orange_mana_max_value", "box": "orange_mana_max_box", "format": "int" },
	{ "key": "pink_mana_bonus", "label": "pink_mana_bonus_label", "value": "pink_mana_bonus_value", "box": "pink_mana_bonus_box", "format": "percent" },
	{ "key": "pink_mana_max", "label": "pink_mana_max_label", "value": "pink_mana_max_value", "box": "pink_mana_max_box", "format": "int" },

	# Combat stats
	{ "key": "critical_strike_chance", "label": "crit_chance_label", "value": "crit_chance_value", "format": "percent" },
	{ "key": "critical_strike_multiplier", "label": "crit_mult_label", "value": "crit_mult_value", "format": "percent" },
	{ "key": "bomb_tile_bonus", "label": "bomb_bonus_label", "value": "bomb_bonus_value", "format": "percent" },
	{ "key": "cooldown_reduction", "label": "cooldown_reduction_label", "value": "cooldown_reduction_value", "format": "percent" },
	{ "key": "tenacity", "label": "tenacity_label", "value": "tenacity_value", "format": "percent" },
	{ "key": "luck", "label": "luck_label", "value": "luck_value", "format": "int" },
	{ "key": "shield_recovery", "label": "shield_recovery_label", "value": "shield_recovery_value", "format": "int" },
	{ "key": "lifesteal", "label": "lifesteal_label", "value": "lifesteal_value", "format": "percent" },
	{ "key": "damage_resistance", "label": "damage_resistance_label", "value": "damage_resistance_value", "format": "percent" },
	{ "key": "evasion_chance", "label": "evasion_label", "value": "evasion_value", "format": "percent" },
	{ "key": "affinity_damage_bonus", "label": "affinity_bonus_label", "value": "affinity_bonus_value", "format": "int" }
]

# Debug toggle removed

func _safe_temp_bonuses(obj) -> Dictionary:
	if obj and obj.has_method("get") and obj.get("temporary_bonuses") != null:
		return obj.temporary_bonuses
	return {}

func _format_stat(value: float, format: String) -> String:
	match format:
		"percent":
			return FW_Utils.to_percent(value)
		"int":
			return str(int(value))
		_:
			return str(value)

func setup(res: Resource) -> void:
	# Show job name in parentheses if the monster resource has a job assigned
	var display_name: String = str(res.name)
	if res.get("job") != null:
		var job_res = res.job
		if job_res and job_res.get("name") != null and str(job_res.name) != "":
			# Prefer computing color from abilities (jobs are derived from abilities). Fall back to resource color.
			var jc = Color.WHITE
			# If we have an abilities array on the resource, use it to compute a blended color
			if res.get("abilities") != null and res.abilities.size() > 0:
				jc = FW_Utils.job_color_from_ability_types(res.abilities)
			elif job_res.get("job_color") != null:
				jc = FW_Utils.normalize_color(job_res.job_color)
			# Append job name with BBCode using computed color
			name_label.bbcode_enabled = true
			display_name = "%s [color=%s]- %s[/color]" % [display_name, jc.to_html(false), str(job_res.name)]
	name_label.text = display_name
	image.texture = res.texture
	show_hide_affinities(res)

	# If this resource is the player character, append the player's job name in color
	if is_instance_of(res, Character):
		var jc := Color.WHITE
		if GDM.player.job and GDM.player.job.name.to_lower() != "unassigned":
			jc = FW_Utils.job_color_from_ability_types(GDM.player.abilities)
			name_label.text = "%s [color=%s]- %s[/color]" % [name_label.text, jc.to_html(false), str(GDM.player.job.name)]
	var effects
	var base_stats
	var temp_bonuses = {}
	var env_effects = {}
	var is_char = is_instance_of(res, Character)
	var is_pvp_monster = false
	var is_regular_monster = false

	# Debug monster type detection
	setup_call_counter += 1
	# Check if this is a Monster_Resource with combatant stats (PvP opponent)
	if is_instance_of(res, Monster_Resource) and res.get("is_pvp_monster") == true and res.stats and res.stats.has_method("get_stat_values"):
		is_pvp_monster = true
	elif is_instance_of(res, Monster_Resource):
		is_regular_monster = true

	if is_char:
		effects = GDM.effect_manager.get_modifier_effects()
		base_stats = GDM.player.stats
		if GDM.player.stats.has_method("get") and GDM.player.stats.get("temporary_bonuses") != null:
			temp_bonuses = GDM.player.stats.temporary_bonuses
		env_effects = GDM.env_manager.get_environmental_effects()
	elif is_pvp_monster:
		# For PvP opponents, use the EffectManager merging logic so
		# environmental and character overlays are applied to the
		# snapshot without re-applying temporary bonuses.
		if GDM.effect_manager:
			effects = GDM.effect_manager.collect_effects(res.stats, {}, GDM.env_manager.get_environmental_effects())
		else:
			effects = res.stats.get_stat_values()
		base_stats = res.stats
		# For PvP opponents, use the StatsManager's temporary bonuses so buffs/debuffs are reflected
		temp_bonuses = _safe_temp_bonuses(res.stats)
		# env_effects already applied via collect_effects; keep reference for per-stat deltas
		env_effects = GDM.env_manager.get_environmental_effects() if GDM.env_manager else {}
	elif is_regular_monster:
		# For regular monsters, use the Monster_Resource's StatsManager
		# (all regular monsters should have stats after level generation)
		if res.stats and res.stats.has_method("get_stat_values"):
			# Use the StatsManager's computed values as the baseline (these include job/equipment bonuses)
			effects = res.stats.get_stat_values()
			base_stats = res.stats
			# Preserve temporary bonuses if the StatsManager exposes them
			temp_bonuses = _safe_temp_bonuses(res.stats)
		else:
			# This should not happen with the new system, but provide minimal fallback
			# Ensure monster has stats for this session
			if res.get("is_pvp_monster") != true:
				res.stats = FW_StatsManager.new()

			effects = {
				"hp": res.max_hp, "shields": res.shields,
				"bark": 0, "reflex": 0, "alertness": 0, "vigor": 0, "enthusiasm": 0,
				"red_mana_bonus": 0, "red_mana_max": 0, "blue_mana_bonus": 0, "blue_mana_max": 0,
				"green_mana_bonus": 0, "green_mana_max": 0, "orange_mana_bonus": 0, "orange_mana_max": 0,
				"pink_mana_bonus": 0, "pink_mana_max": 0, "critical_strike_chance": 0, "critical_strike_multiplier": 0,
				"bomb_tile_bonus": 0, "cooldown_reduction": 0, "tenacity": 0, "luck": 0, "shield_recovery": 0,
				"lifesteal": 0, "damage_resistance": 0, "evasion_chance": 0, "affinity_damage_bonus": 0
			}
			base_stats = res.stats  # Use the newly created stats
			temp_bonuses = {}
		env_effects = GDM.env_manager.get_environmental_effects() if GDM.env_manager else {}
	else:
		# This should primarily be for legacy compatibility when neither is_char, is_pvp_monster, or is_regular_monster are true
		# This suggests the monster type detection logic above is failing

		effects = GDM.effect_manager.get_monster_modifier_effects()
		base_stats = GDM.monster_to_fight.stats if GDM.monster_to_fight else null
		if base_stats and base_stats.has_method("get") and base_stats.get("temporary_bonuses") != null:
			temp_bonuses = base_stats.temporary_bonuses
		else:
			temp_bonuses = {}
		env_effects = GDM.env_manager.get_environmental_effects() if GDM.env_manager else {}

	# HP display: show current/max, and show only environmental/temporary modifier
	# Get max HP with all modifiers
	var hp_max = 0
	if is_char:
		# Use StatsManager as the baseline (no env) and show env/temp as modifiers
		if base_stats and base_stats.has_method("get_stat"):
			hp_max = int(base_stats.get_stat("hp"))
		else:
			# fallback to effect_manager value
			hp_max = int(GDM.effect_manager.get_player_max_hp()) if GDM.effect_manager.has_method("get_player_max_hp") else 0
	elif is_pvp_monster:
		# For PvP monsters, get HP directly from stats (combined values)
		hp_max = int(effects.get("hp", 1))
	elif is_regular_monster:
		# For regular monsters, use base HP + environmental effects
		hp_max = int(res.max_hp + env_effects.get("hp", 0))
	else:
		hp_max = int(GDM.effect_manager.get_monster_max_hp()) if GDM.effect_manager else 1

	var hp_env = env_effects.get("hp", 0)
	var hp_temp = temp_bonuses.get("hp", 0)
	var hp_mod = int(hp_env) + int(hp_temp)
	var hp_main = str(hp_max)
	if hp_mod > 0:
		var hp_mod_str = " (" + "+" + str(hp_mod) + ")"
		var hp_rich = hp_main + " [color=#22cc22]" + hp_mod_str + "[/color]"
		hp_label.text = ""
		hp_label.bbcode_enabled = true
		hp_label.text = hp_rich
	elif hp_mod < 0:
		var hp_mod_str = " (" + str(hp_mod) + ")"
		var hp_rich = hp_main + " [color=#cc2222]" + hp_mod_str + "[/color]"
		hp_label.text = ""
		hp_label.bbcode_enabled = true
		hp_label.text = hp_rich
	else:
		hp_label.bbcode_enabled = true
		hp_label.text = hp_main

	# Shields display: show current, and show only environmental/temporary modifier
	# Get max shields with all modifiers
	var shields_max = 0
	if is_char:
		# shields baseline from StatsManager (no env)
		if base_stats and base_stats.has_method("get_stat"):
			shields_max = int(base_stats.get_stat("shields"))
		else:
			shields_max = int(GDM.effect_manager.get_shields()) if GDM.effect_manager else 0
	elif is_pvp_monster:
		# For PvP monsters, get shields directly from stats (combined values)
		shields_max = int(effects.get("shields", 0))
	elif is_regular_monster:
		# For regular monsters, use base shields + environmental effects
		shields_max = int(res.shields + env_effects.get("shields", 0))
	else:
		shields_max = int(GDM.effect_manager.get_monster_shields()) if GDM.effect_manager else 0

	# Get current shields, clamp to max
	var shields_current = shields_max
	if is_char and GDM.player.stats.has_method("get") and GDM.player.stats.get("current_shields") != null:
		shields_current = clamp(int(GDM.player.stats.current_shields), 0, shields_max)
	elif is_pvp_monster:
		# For PvP monsters, shields_current is the same as shields_max (no combat state tracking in preview)
		shields_current = shields_max
	elif is_regular_monster:
		# For regular monsters, shields_current is the same as shields_max (no combat state tracking in preview)
		shields_current = shields_max
	elif GDM.monster_to_fight and GDM.monster_to_fight.stats.has_method("get") and GDM.monster_to_fight.stats.get("current_shields") != null:
		shields_current = clamp(int(GDM.monster_to_fight.stats.current_shields), 0, shields_max)

	var shields_env = env_effects.get("shields", 0)
	var shields_temp = temp_bonuses.get("shields", 0)
	var shields_mod = int(shields_env) + int(shields_temp)
	var shield_emoji = "🛡️"
	var shields_main = str(shields_current) + " " + shield_emoji
	if shields_mod > 0:
		var shields_mod_str = " (" + "+" + str(shields_mod) + ")"
		var shields_rich = shields_main + " [color=#22cc22]" + shields_mod_str + "[/color]"
		shields_label.text = ""
		shields_label.bbcode_enabled = true
		shields_label.text = shields_rich
	elif shields_mod < 0:
		var shields_mod_str = " (" + str(shields_mod) + ")"
		var shields_rich = shields_main + " [color=#cc2222]" + shields_mod_str + "[/color]"
		shields_label.text = ""
		shields_label.bbcode_enabled = true
		shields_label.text = shields_rich
	else:
		shields_label.bbcode_enabled = true
		shields_label.text = shields_main

	for stat in STAT_DISPLAY:
		var serialized_value = effects.get(stat.key, 0.0)
		# For actual player characters, prefer the StatsManager baseline (which excludes env)
		if is_char and base_stats and base_stats.has_method("get_stat"):
			serialized_value = base_stats.get_stat(stat.key)
		var temp_bonus = temp_bonuses.get(stat.key, 0.0)
		var env_bonus = env_effects.get(stat.key, 0.0)
		# Compute combined value. Declare once to avoid scope issues.
		var combined_value = 0.0
		if is_pvp_monster:
			# PvP snapshot produced via FW_EffectManager.collect_effects already
			# includes environmental overlays; do not add env_bonus again
			combined_value = serialized_value
		else:
			# Combined value shown = serialized (base) + env + temp
			combined_value = serialized_value + float(env_bonus) + float(temp_bonus)
		var base_value = 0.0

		if is_pvp_monster:
			# For PvP monsters, prefer explicit base stat if available
			if base_stats and base_stats.has_method("get_stat_base"):
				base_value = base_stats.get_stat_base(stat.key)
			else:
				# Fall back to serialized_value as the baseline
				base_value = serialized_value
		elif is_regular_monster:
			# Regular monsters don't have base stats; show env effects added
			base_value = 0.0
		elif base_stats and base_stats.has_method("get_stat_base"):
			base_value = base_stats.get_stat_base(stat.key)
		else:
			base_value = 0.0

		var value_label = get_node("%" + stat.value)
		value_label.text = _format_stat(combined_value, stat.format)
		# Coloring: red if combined < base, green if any positive temp/env bonus, else white
		if combined_value < base_value:
			value_label.self_modulate = Color(1,0.2,0.2) # red
		elif temp_bonus > 0.0 or env_bonus > 0.0:
			value_label.self_modulate = Color(0.2,1,0.2) # green
		else:
			value_label.self_modulate = Color(1,1,1) # default

# This should work for both char and monsters since they should be close to the same
func show_hide_affinities(character: Resource) -> void:
	if !red_affinity:
		red_affinity = %red_affinity
	if !blue_affinity:
		blue_affinity = %blue_affinity
	if !green_affinity:
		green_affinity = %green_affinity
	if !orange_affinity:
		orange_affinity = %orange_affinity
	if !pink_affinity:
		pink_affinity = %pink_affinity

	var aff_list = [%red_affinity, %blue_affinity, %green_affinity, %orange_affinity, %pink_affinity]
	for a in aff_list:
		a.set_visible(false)
	for aff in character.affinities:
		match aff:
			FW_Ability.ABILITY_TYPES.Bark:
				red_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Alertness:
				blue_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Reflex:
				green_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Vigor:
				orange_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Enthusiasm:
				pink_affinity.set_visible(true)
