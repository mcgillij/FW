extends RefCounted
class_name FW_PlayerSerializer

static func serialize_player_for_upload(player: FW_Player) -> Dictionary:
	var data := {
		"version": "1.0",
		"timestamp": Time.get_unix_time_from_system(),
		"character": {
			"name": player.character.name,
			"texture_path": (player.character.texture.resource_path if player.character and player.character.texture else ""),
			"description": (str(player.character.description) if player.character and typeof(player.character.description) == TYPE_STRING and str(player.character.description) != "" else ""),
			"affinities": [],
			"effects": (player.character.effects if player.character and typeof(player.character.effects) == TYPE_DICTIONARY and player.character.effects else {})
		},
		"abilities": [],
		"stats": serialize_combined_stats(player.stats),
		"level": player.current_level,
		"difficulty": FW_Player.DIFFICULTY.keys()[player.difficulty],
		"job": serialize_job(player.job),
		"ascension_level": player.current_ascension_level
	}

	for affinity in player.character.affinities:
		data["character"]["affinities"].append(FW_Ability.ABILITY_TYPES.keys()[affinity])

	for ability in player.abilities:
		if ability != null:
			var entry := {"name": ability.name}
			if ability.resource_path and ability.resource_path != "":
				entry["resource_path"] = ability.resource_path
			else:
				entry["resource_path"] = null
			data["abilities"].append(entry)

	return data

static func serialize_combined_stats(stats: FW_StatsManager) -> Dictionary:
	var combined: Dictionary = {}
	for stat_name in FW_StatsManager.STAT_NAMES:
		combined[stat_name] = stats.get_stat(stat_name)
	return combined

static func serialize_job(job: FW_Job) -> Dictionary:
	if job == null:
		return {"name": "", "color": "#ffffff"}
	var color_str := "#ffffff"
	if job and job.job_color:
		# normalize to Color then convert to HTML
		color_str = FW_Utils.normalize_color(job.job_color).to_html()
	var name_out = ""
	if job and job.name and str(job.name).to_lower() != "unassigned":
		name_out = job.name
	return {"name": name_out, "color": color_str}

static func deserialize_player_data(data: Dictionary) -> FW_Combatant:
	var combatant := FW_Combatant.new()

	if data.has("character"):
		var ch = data.character
		combatant.name = ch.get("name", "Unknown")
		combatant.description = ch.get("description", "A fellow adventurer")
		if ch.has("texture_path") and typeof(ch.texture_path) == TYPE_STRING and ch.texture_path != "":
			var tex = load(ch.texture_path)
			if tex is Texture2D:
				combatant.texture = tex
		if ch.has("affinities") and typeof(ch.affinities) == TYPE_ARRAY:
			for affinity_name in ch.affinities:
				var v = FW_Ability.ABILITY_TYPES.get(affinity_name, -1)
				if v != -1:
					combatant.affinities.append(v)

	if data.has("abilities") and typeof(data.abilities) == TYPE_ARRAY:
		for ability_data in data.abilities:
			if typeof(ability_data) == TYPE_DICTIONARY and ability_data.has("resource_path") and ability_data.resource_path != null and ability_data.resource_path != "":
				var res = load(ability_data.resource_path)
				if res:
					combatant.abilities.append(res)

	# Stats: store combined values into a special pvp map
	combatant.stats = FW_StatsManager.new()
	combatant.stats._pvp_final_values = {}
	if data.has("stats") and typeof(data.stats) == TYPE_DICTIONARY:
		for stat_name in data.stats.keys():
			combatant.stats._pvp_final_values[stat_name] = data.stats[stat_name]
			combatant.stats.set(stat_name, 0.0)
	combatant.stats._is_pvp_opponent = true

	combatant.base_hp = 0
	combatant.base_shields = 0

	combatant.is_ai_controlled = true
	combatant.ai_type = FW_MonsterAI.monster_ai.SENTIENT
	combatant.is_pvp_opponent = true
	combatant.character_effects = {}
	combatant.difficulty_level = data.get("level", 1)

	if data.has("job") and typeof(data.job) == TYPE_DICTIONARY and data.job.has("name") and data.job.name != "":
		combatant.job_name = data.job.name
		if data.job.has("color"):
			# data.job.color may be a hex string; normalize to a Color
			combatant.job_color = FW_Utils.normalize_color(data.job.color)

	combatant.ascension_level = data.get("current_ascension_level", 0)

	return combatant
