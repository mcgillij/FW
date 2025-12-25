extends RefCounted

class_name FW_RunArchiver

static func archive_run(cause_of_death: String, change_scene_to: String) -> void:
	var now = Time.get_datetime_string_from_system(true)
	var stats = FW_RunStatistics.new()
	stats.character_name = GDM.player.character.name
	stats.ascension_level = UnlockManager.get_ascension_level(GDM.player.character.name)
	stats.level_reached = GDM.player.current_level
	stats.xp = GDM.player.xp
	stats.gold = GDM.player.gold
	stats.character_image_path = GDM.player.character.image.resource_path
	# Prefer to store the Character resource path for later lookup (affinities, name, and image)
	if GDM.player.character and GDM.player.character.resource_path:
		stats.character_resource_path = GDM.player.character.resource_path
	# Copy affinities for history display (simple serializable form)
	stats.affinities = []
	if GDM.player.character and GDM.player.character.affinities:
		# Save as ints (ABILITY_TYPES enum values), serialize as JSON array
		stats.affinities = GDM.player.character.affinities.duplicate(true)
	stats.monsters_encountered = GDM.player.monster_kills.size()
	stats.floors_cleared = GDM.world_state.count_total_completed_levels()
	stats.difficulty = GDM.player.difficulty
	# Do not record the 'Unassigned' job name; treat it as no-job
	stats.job_name = ""
	if GDM.player and GDM.player.job and GDM.player.job.get("name") != null and str(GDM.player.job.name).to_lower() != "unassigned":
		stats.job_name = GDM.player.job.name
	var jc := Color.WHITE
	if GDM.player and GDM.player.job and GDM.player.job.job_color:
		jc = FW_Utils.normalize_color(GDM.player.job.job_color)
	stats.job_color = jc.to_html()
	stats.datetime = now
	stats.game_version = FW_Utils.get_version_info()
	stats.cause_of_death = cause_of_death
	stats.append_run_to_archive(stats.to_dict())

	# nuke the game data and archive the run
	GDM.delete_vs_save_data()
	GDM.player = null
	GDM.level_scroll_value = 0
	# Reset cooldowns when archiving run
	if GDM.game_manager:
		if GDM.game_manager.player_cooldown_manager:
			GDM.game_manager.player_cooldown_manager.reset_cooldowns()
		if GDM.game_manager.monster_cooldown_manager:
			GDM.game_manager.monster_cooldown_manager.reset_cooldowns()
	ScreenRotator.change_scene(change_scene_to)
