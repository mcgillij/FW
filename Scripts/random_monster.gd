extends RefCounted
class_name FW_RandomMonster

# Static cache for loaded monsters - shared across all instances
static var _cached_monsters: Dictionary = {}
static var _cached_by_subtype: Dictionary = {}
static var _cache_initialized: bool = false
static var _loading_requests: Dictionary = {}
static var _loading_complete: bool = false

static func start_loading():
	"""Start asynchronous loading of monster cache"""
	if _cache_initialized:
		return

	_cached_monsters = {}
	_cached_by_subtype = {}
	_loading_requests = {}
	_loading_complete = false

	var paths_dict = _get_monster_dict()

	for monster_type in paths_dict.keys():
		_cached_monsters[monster_type] = []
		_cached_by_subtype[monster_type] = {}

		var monster_paths = paths_dict[monster_type]

		for path in monster_paths:
			var err = ResourceLoader.load_threaded_request(path, "", true)
			if err == OK:
				_loading_requests[path] = monster_type
			else:
				printerr("Failed to request threaded load for: ", path)

	_cache_initialized = true

static func reset_loading_state() -> void:
	"""Force reset the loading state - useful for debugging or ensuring clean state"""
	_cached_monsters = {}
	_cached_by_subtype = {}
	_cache_initialized = false
	_loading_requests = {}
	_loading_complete = false

static func is_loading_complete() -> bool:
	"""Poll loading status and finalize cache when complete"""
	# If we haven't started loading yet, return false to trigger loading
	if not _cache_initialized:
		return false

	if _loading_complete and not _cached_monsters.is_empty():
		return true

	var still_loading = false
	for path in _loading_requests.keys():
		var status = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			still_loading = true
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			var monster = ResourceLoader.load_threaded_get(path) as FW_Monster_Resource
			if monster:
				var monster_type = _loading_requests[path]
				_cached_monsters[monster_type].append(monster)
			_loading_requests.erase(path)
		else:
			# Handle error or failed load
			printerr("Failed to load monster: ", path)
			_loading_requests.erase(path)

	if not still_loading and _loading_requests.is_empty():
		_loading_complete = true
		# Finalize subtype organization
		for monster_type in _cached_monsters.keys():
			for monster in _cached_monsters[monster_type]:
				var subtype = monster.subtype
				if not _cached_by_subtype[monster_type].has(subtype):
					_cached_by_subtype[monster_type][subtype] = []
				_cached_by_subtype[monster_type][subtype].append(monster)
		return true

	return false

static func _get_monster_dict() -> Dictionary:
	"""Return the monster dictionary - needed since we can't access instance vars from static methods"""
	return {
		FW_Monster_Resource.monster_type.SCRUB: ["res://Monsters/Resources/acid_monster.tres",
			"res://Monsters/Resources/bear_person2.tres",
			"res://Monsters/Resources/bear_person.tres",
			"res://Monsters/Resources/dragon_folk1.tres",
			"res://Monsters/Resources/dragon_folk2.tres",
			"res://Monsters/Resources/dragon_folk.tres",
			"res://Monsters/Resources/elf_archer.tres",
			"res://Monsters/Resources/elf_warrior.tres",
			"res://Monsters/Resources/gnoll_warrior3.tres",
			"res://Monsters/Resources/nagakin.tres",
			"res://Monsters/Resources/naga_fighter.tres",
			"res://Monsters/Resources/naga_warrior.tres",
			"res://Monsters/Resources/ogre_mage.tres",
			"res://Monsters/Resources/ogre_priest.tres",
			"res://Monsters/Resources/ogre_warrior.tres",
			"res://Monsters/Resources/orc_shaman.tres",
			"res://Monsters/Resources/orc_shaman_boss.tres",
			"res://Monsters/Resources/orc_spirit.tres",
			"res://Monsters/Resources/orc_warrior2.tres",
			"res://Monsters/Resources/orc_warrior3.tres",
			"res://Monsters/Resources/orc_wizard.tres",
			"res://Monsters/Resources/skeletal_reaper.tres",
			"res://Monsters/Resources/skeletal_wanderer2.tres",
			"res://Monsters/Resources/skeleton_samurai.tres",
			"res://Monsters/Resources/skeleton_warrior.tres",
			"res://Monsters/Resources/troll_shaman.tres",
			"res://Monsters/Resources/wubs.tres",
			"res://Monsters/Resources/zombie_ninja.tres",
			"res://Monsters/Resources/elf_thrall.tres",
			"res://Monsters/Resources/darkelf_fighter.tres",
			"res://Monsters/Resources/elf_paladin.tres",
			"res://Monsters/Resources/elf_knight.tres",
			"res://Monsters/Resources/darkelf_skirmisher.tres",
			"res://Monsters/Resources/elf_paladin_thrall.tres",
			"res://Monsters/Resources/evil_elf_paladin.tres",
			"res://Monsters/Resources/darkelf_knight.tres",
			"res://Monsters/Resources/darkelf_paladin.tres",
			"res://Monsters/Resources/darkelf_blackguard.tres",
			"res://Monsters/Resources/darkelf_blackguard2.tres",
			"res://Monsters/Resources/orc_witchdoctor.tres",
			"res://Monsters/Resources/minotaur_skirmisher.tres",
			"res://Monsters/Resources/skulking_vampire_spawn.tres",
			"res://Monsters/Resources/ravenous_vampire_spawn.tres",
			"res://Monsters/Resources/decaying_vampire_spawn.tres",
			"res://Monsters/Resources/crazed_vampire_spawn.tres",
			"res://Monsters/Resources/happy_vampire.tres",
			"res://Monsters/Resources/vampire_cultist.tres",
			"res://Monsters/Resources/forest_spirit.tres",
			"res://Monsters/Resources/corrupted_dryad.tres",
			"res://Monsters/Resources/lightning_spirit.tres",
			"res://Monsters/Resources/decaying_elf.tres",
			"res://Monsters/Resources/animatrice.tres",
			"res://Monsters/Resources/evil_water_sprite.tres",
			"res://Monsters/Resources/lightning_sprite.tres",
			"res://Monsters/Resources/ice_elemental.tres",
			"res://Monsters/Resources/fire_sprite.tres",
			"res://Monsters/Resources/fire_mage.tres",
			"res://Monsters/Resources/fire_knight.tres",
			"res://Monsters/Resources/shadow_spirit.tres",
			"res://Monsters/Resources/skeletal_reapers_helper.tres",
			"res://Monsters/Resources/vampire_elf.tres",
			"res://Monsters/Resources/vampire_spawn_stalker.tres",
			"res://Monsters/Resources/vampire_thinblood.tres",
			"res://Monsters/Resources/blooded_fighter.tres",
			"res://Monsters/Resources/bloodfighter.tres",
			"res://Monsters/Resources/vampire_ambusher.tres",
			"res://Monsters/Resources/priest_of_undeath.tres",
			"res://Monsters/Resources/vampire_lamenter.tres",
			"res://Monsters/Resources/vampire_neophyte.tres",
			"res://Monsters/Resources/armored_evil_elf.tres",
			"res://Monsters/Resources/elf_fighter.tres",
			"res://Monsters/Resources/corrupted_elf_warrior.tres",
			"res://Monsters/Resources/thrall_fighter.tres",
			"res://Monsters/Resources/thrall_neophyte.tres",
			"res://Monsters/Resources/blackguard.tres",
			"res://Monsters/Resources/reaper_fighter.tres",
			"res://Monsters/Resources/thrall.tres",
			"res://Monsters/Resources/reapers_apprentice.tres",
			"res://Monsters/Resources/busted_skeleton.tres",
			"res://Monsters/Resources/decaying_skeleton.tres",
			"res://Monsters/Resources/skeletal_priest.tres",
			"res://Monsters/Resources/skeletal_acolyte.tres",
			"res://Monsters/Resources/skeletal_fashion_designer.tres",
			"res://Monsters/Resources/skeletal_cultist.tres",
			"res://Monsters/Resources/reanimated_thrall.tres",
			"res://Monsters/Resources/lich_apprentice.tres",
			"res://Monsters/Resources/skeleton_librarian.tres",
			"res://Monsters/Resources/thrall_cultist.tres",
			"res://Monsters/Resources/thrall_sister.tres",
			"res://Monsters/Resources/thrall_acolyte.tres",
			"res://Monsters/Resources/lichess_apprentice.tres",
			"res://Monsters/Resources/orc_occultist.tres",
			"res://Monsters/Resources/orc_cultist.tres",
			"res://Monsters/Resources/orc_acolyte.tres",
			"res://Monsters/Resources/orc_ambusher.tres",
			"res://Monsters/Resources/orc_barbarian.tres",
			"res://Monsters/Resources/orc_assailant.tres",
			"res://Monsters/Resources/elf_armored_warrior.tres",
			"res://Monsters/Resources/elf_blackguard.tres",
			"res://Monsters/Resources/orc_fighter.tres",
			"res://Monsters/Resources/ogre_fighter.tres",
			"res://Monsters/Resources/ogre_goon.tres",
			"res://Monsters/Resources/ogre_fighter_thrall.tres",
			"res://Monsters/Resources/goblin_knight.tres",
			"res://Monsters/Resources/goblin_armored_fighter.tres",
			"res://Monsters/Resources/goblin_skulker.tres",
			"res://Monsters/Resources/goblin_ambusher.tres",
			"res://Monsters/Resources/goblin_thief.tres",
			"res://Monsters/Resources/ogre_brute.tres",
			"res://Monsters/Resources/ogre_herder.tres",
			"res://Monsters/Resources/goblin_businessman.tres",
			"res://Monsters/Resources/orc_monk.tres",
			"res://Monsters/Resources/goblin_fanatic.tres",
			"res://Monsters/Resources/elf_wizard.tres",
			],
		FW_Monster_Resource.monster_type.GRUNT: ["res://Monsters/Resources/evil_elf2.tres",
			"res://Monsters/Resources/evil_elf.tres",
			"res://Monsters/Resources/evil_sorcerer.tres",
			"res://Monsters/Resources/gnoll_warrior2.tres",
			"res://Monsters/Resources/gnoll_warrior.tres",
			"res://Monsters/Resources/goblin_champ.tres",
			"res://Monsters/Resources/goblin_deathknight.tres",
			"res://Monsters/Resources/goblin_shaman2.tres",
			"res://Monsters/Resources/goblin_shaman.tres",
			"res://Monsters/Resources/goblin_warrior.tres",
			"res://Monsters/Resources/minotaur.tres",
			"res://Monsters/Resources/minotaur_fighter.tres",
			"res://Monsters/Resources/minotaur_loner.tres",
			"res://Monsters/Resources/necromancer2.tres",
			"res://Monsters/Resources/necromancer.tres",
			"res://Monsters/Resources/protomancer.tres",
			"res://Monsters/Resources/root_wraith.tres",
			"res://Monsters/Resources/shadow_wizard.tres",
			"res://Monsters/Resources/skeletal_solar_wizard.tres",
			"res://Monsters/Resources/skeletal_wanderer.tres",
			"res://Monsters/Resources/skeletal_wizard.tres",
			"res://Monsters/Resources/skeleton_warriors2.tres",
			"res://Monsters/Resources/skeleton_warriors.tres",
			"res://Monsters/Resources/troll_shaman2.tres",
			"res://Monsters/Resources/troll_shaman3.tres",
			"res://Monsters/Resources/troll_shaman4.tres",
			"res://Monsters/Resources/troll_warrior2.tres",
			"res://Monsters/Resources/troll_warrior.tres",
			"res://Monsters/Resources/witch.tres",
			"res://Monsters/Resources/zombie_gang.tres",
			"res://Monsters/Resources/zombie_horde.tres",
			"res://Monsters/Resources/undead_elf_knight.tres",
			"res://Monsters/Resources/darkelf_deathknight.tres",
			"res://Monsters/Resources/evil_elf_knight.tres",
			"res://Monsters/Resources/orc_mutant.tres",
			"res://Monsters/Resources/minotaur_brute.tres",
			"res://Monsters/Resources/minotaur_gladiator.tres",
			"res://Monsters/Resources/skeletal_wizard2.tres",
			"res://Monsters/Resources/ghoul_mutant.tres",
			"res://Monsters/Resources/vampire_sorceress.tres",
			"res://Monsters/Resources/elemental_wraith.tres",
			"res://Monsters/Resources/vile_forest_spirit.tres",
			"res://Monsters/Resources/vile_lightning_spirit.tres",
			"res://Monsters/Resources/deathknight.tres",
			"res://Monsters/Resources/battle_mage.tres",
			"res://Monsters/Resources/reanimator.tres",
			"res://Monsters/Resources/evil_water_spirit.tres",
			"res://Monsters/Resources/shocking_spirit.tres",
			"res://Monsters/Resources/ice_spirit.tres",
			"res://Monsters/Resources/fire_spirit.tres",
			"res://Monsters/Resources/fire_sorceress.tres",
			"res://Monsters/Resources/wraith_controller.tres",
			"res://Monsters/Resources/vengeance_spirit.tres",
			"res://Monsters/Resources/shadow_controller.tres",
			"res://Monsters/Resources/skeletal_sorcerer.tres",
			"res://Monsters/Resources/demon_avenger.tres",
			"res://Monsters/Resources/vampire_knight.tres",
			"res://Monsters/Resources/vampire_stalker.tres",
			"res://Monsters/Resources/exsanguinator.tres",
			"res://Monsters/Resources/vampire_magician.tres",
			"res://Monsters/Resources/vampire_priest.tres",
			"res://Monsters/Resources/vampire_tormentor.tres",
			"res://Monsters/Resources/thrall_controller.tres",
			"res://Monsters/Resources/darkelf_blackknight.tres",
			"res://Monsters/Resources/corrupted_elf.tres",
			"res://Monsters/Resources/corrupted_darkelf_knight.tres",
			"res://Monsters/Resources/demon_warrior.tres",
			"res://Monsters/Resources/thrall_warrior.tres",
			"res://Monsters/Resources/evil_elf_knight_warrior.tres",
			"res://Monsters/Resources/reapers_helper.tres",
			"res://Monsters/Resources/reapers_apprentice.tres",
			"res://Monsters/Resources/reaper_assistant_manager.tres",
			"res://Monsters/Resources/skeletal_mage.tres",
			"res://Monsters/Resources/broken_skeleton_warrior.tres",
			"res://Monsters/Resources/skeletal_bishop.tres",
			"res://Monsters/Resources/skeleton_bishop.tres",
			"res://Monsters/Resources/skeleton_sorcerer.tres",
			"res://Monsters/Resources/skeletal_necromancer.tres",
			"res://Monsters/Resources/lich_assistant.tres",
			"res://Monsters/Resources/skeletal_sorceress.tres",
			"res://Monsters/Resources/orc_knight.tres",
			"res://Monsters/Resources/orc_enforcer.tres",
			"res://Monsters/Resources/ogre_warrior_captain.tres",
			"res://Monsters/Resources/ogre_brawler.tres",
			"res://Monsters/Resources/evil_goblin_fighter.tres",
			"res://Monsters/Resources/goblin_drill_sergeant.tres",
			"res://Monsters/Resources/goblin_mechanic.tres",
			"res://Monsters/Resources/goblin_mage.tres",
			"res://Monsters/Resources/goblin_soothsayer.tres",
			],
		FW_Monster_Resource.monster_type.ELITE: ["res://Monsters/Resources/evil_sorcerers.tres",
			"res://Monsters/Resources/goblin_queen.tres",
			"res://Monsters/Resources/goblin_reaper.tres",
			"res://Monsters/Resources/minotaur_warrior.tres",
			"res://Monsters/Resources/spirit_of_the_night.tres",
			"res://Monsters/Resources/fire_heart.tres",
			"res://Monsters/Resources/vampire_empress.tres",
			"res://Monsters/Resources/vampire_queen.tres",
			"res://Monsters/Resources/vampire_elder.tres",
			"res://Monsters/Resources/queens_protector.tres",
			"res://Monsters/Resources/nightguard.tres",
			"res://Monsters/Resources/reaper_slayer.tres",
			"res://Monsters/Resources/reaper_battle_mage.tres",
			"res://Monsters/Resources/skeletal_archibishop.tres",
			"res://Monsters/Resources/skeletal_reanimator.tres",
			"res://Monsters/Resources/casual_lich.tres",
			"res://Monsters/Resources/thrall_channeler.tres",
			"res://Monsters/Resources/lichess.tres",
			"res://Monsters/Resources/goblin_lord.tres",
			"res://Monsters/Resources/goblin_enchantress.tres",
			"res://Monsters/Resources/goblin_necromancer.tres",
			],
		FW_Monster_Resource.monster_type.BOSS: ["res://Monsters/Resources/archa.tres",
			"res://Monsters/Resources/demon_lord.tres",
			"res://Monsters/Resources/nightlord.tres",
			"res://Monsters/Resources/night_queen.tres",
			"res://Monsters/Resources/dark_queen.tres",
			"res://Monsters/Resources/blackguard_empress.tres",
			"res://Monsters/Resources/demon_queen.tres",
			"res://Monsters/Resources/thrall_dominator.tres",
			"res://Monsters/Resources/goblin_king.tres",
		]
	}

static func _get_total_cached_count() -> int:
	"""Helper to count total cached monsters for logging"""
	var total = 0
	for type_key in _cached_monsters.keys():
		total += _cached_monsters[type_key].size()
	return total

static func get_total_monster_count() -> int:
	"""Get the total number of monster resources to load"""
	var total = 0
	var paths_dict = _get_monster_dict()
	for type_key in paths_dict.keys():
		total += paths_dict[type_key].size()
	return total

static func get_loading_progress() -> float:
	"""Get the current loading progress as a float between 0.0 and 1.0"""
	if _loading_complete:
		return 1.0
	var total = get_total_monster_count()
	var loaded = total - _loading_requests.size()
	return float(loaded) / total if total > 0 else 1.0

# Static helper method for getting random monsters without creating instances
static func get_random_monster_static(type: FW_Monster_Resource.monster_type = FW_Monster_Resource.monster_type.GRUNT, subtype_filter: Variant = null) -> FW_Monster_Resource:
	"""Get a random monster using the static cache without needing to create a RandomMonster instance"""
	# Ensure loading is started
	start_loading()

	# Check if loading is complete
	if not is_loading_complete():
		printerr("Monster cache not yet loaded. Call is_loading_complete() before using.")
		return null

	if type in _cached_monsters:
		var selected_monster: FW_Monster_Resource

		# If no subtype filter is specified, return random monster from cache
		if subtype_filter == null:
			var available_monsters = _cached_monsters[type]
			selected_monster = available_monsters[randi() % available_monsters.size()]
			var duplicated = selected_monster.duplicate(true)  # Deep duplicate to avoid shared state
			return duplicated

		# Use pre-filtered cache for better performance
		if _cached_by_subtype.has(type) and _cached_by_subtype[type].has(subtype_filter):
			var filtered_monsters = _cached_by_subtype[type][subtype_filter]
			if not filtered_monsters.is_empty():
				selected_monster = filtered_monsters[randi() % filtered_monsters.size()]
				return selected_monster.duplicate(true)  # Deep duplicate to avoid shared state

		# If no monsters match the subtype, fall back to unfiltered
		var fallback_monsters = _cached_monsters[type]
		selected_monster = fallback_monsters[randi() % fallback_monsters.size()]
		return selected_monster.duplicate(true)  # Deep duplicate to avoid shared state
	else:
		printerr("Monster type not found:", type)
		# Fallback - shouldn't happen with static cache
		return null
