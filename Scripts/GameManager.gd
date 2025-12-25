extends Node

class_name FW_GameManager

signal set_game_type
signal set_score_info
signal set_counter_info
signal update_score_goal
signal update_combo
signal player_turn
signal enemy_turn
signal set_level
signal create_goal
signal create_monster
signal create_character
signal game_won
signal game_won_vs
signal game_lost
signal game_lost_vs
signal screen_fade_in
signal screen_fade_out
signal grid_change_move
signal publish_mana
signal publish_mana_bonus
signal refresh_boosters # buttons at the bottom if enough mana become active
signal reset_grid_vars

const ManaMatchVFXControllerScript := preload("res://Scripts/Combat/FW_ManaMatchVFXController.gd")

@export var width: int
@export var height: int
@export var level: int
@export var game_type: GDM.game_types
# if the level triggers story screen
@export var triggers_story: bool
@onready var goal_holder = $goal_holder
# buff bar
@onready var player_buff_bar: Node2D = %PlayerBuffBar
@onready var monster_buff_bar: Node2D = %MonsterBuffBar

# 3d loot roller
@onready var dice_viewport: SubViewport = %dice_viewport
@onready var viewport_display: TextureRect = %viewport_display
var dice_results := {}

@export var max_score: int
@export var points_per_piece: int
@export var is_moves: bool
@export var max_counter: int

var is_player_turn: bool = true
var board_stable: bool = true
var booster_active: bool = false
var game_is_won: bool = false
var game_is_lost: bool = false
var scoreboard = ScoreBoard.new()
var mana = FW_Mana.new()

var combo_multiplier: int = 1

var monster_dead: bool = false
var player_dead: bool = false

# Per-combat visual effects manager (set when entering vs_mode)
var vfx_manager: FW_CombatVisualEffectsManager = null

# Turn manager for centralized turn state management
var turn_manager: FW_TurnManager = null

# Popup coordinator for managing combat info popups
var popup_coordinator: FW_CombatPopupCoordinator = null

# Clickable highlight manager for player turn interactivity
var highlight_manager: FW_ClickableHighlightManager = null

# Mana match VFX controller (handles tile-to-mana visuals in VS mode)
var mana_match_vfx_controller: Node = null

# Centralized cooldown management
var player_cooldown_manager: FW_CooldownManager = null
var monster_cooldown_manager: FW_CooldownManager = null

var current_player_combatant: FW_Combatant = null

var _initial_turn_state: int = FW_TurnManager.TurnState.PLAYER_TURN

const MONSTER_MAX_MANA := {"red": 100, "blue": 100, "green": 100, "orange": 100, "pink": 100}
const DEFAULT_DOT_AMOUNT: int = 5
const BOMB_DAMAGE: int = 25
# Shared delay for monster actions (tile move and ability)
const MONSTER_ACTION_DELAY: float = 0.7

class ScoreBoard:
	var counter: int
	var high_score: int
	var score: int

func _ready() -> void:
	GDM.game_manager = self
	SoundManager.wire_up_all_buttons()
	GDM.game_mode = game_type

	# Initialize cooldown managers for this combat session
	player_cooldown_manager = FW_CooldownManager.new()
	monster_cooldown_manager = FW_CooldownManager.new()

	# Initialize popup coordinator for combat info panels
	popup_coordinator = FW_CombatPopupCoordinator.new()
	popup_coordinator.name = "PopupCoordinator"
	add_child(popup_coordinator)

	# Initialize clickable highlight manager for player turn
	highlight_manager = FW_ClickableHighlightManager.new()
	highlight_manager.name = "HighlightManager"
	add_child(highlight_manager)

	# Reset game state for new combat
	game_is_won = false
	monster_dead = false
	player_dead = false
	# Initialize TurnManager for normal mode (optional, for board state tracking)
	_initialize_turn_manager()
	if GDM.is_vs_mode():
		if vfx_manager == null:
			var _vfx_mgr = FW_CombatVisualEffectsManager.new()
			add_child(_vfx_mgr)
			self.vfx_manager = _vfx_mgr
			# Prefer to register the overlay from the CanvasLayer named 'screen' if present
			if has_node("CanvasLayer/screen"):
				var screen_node = get_node("CanvasLayer/screen")
				if screen_node:
					_vfx_mgr.register_fullscreen_overlay(screen_node)
			# Expose manager on GDM for wider discovery
			if Engine.has_singleton("GDM"):
				var g = Engine.get_singleton("GDM")
				if g:
					if g.has("combat_visual_effects_manager"):
						g.combat_visual_effects_manager = _vfx_mgr
					else:
						g.set("combat_visual_effects_manager", _vfx_mgr)
		if mana_match_vfx_controller == null:
			mana_match_vfx_controller = ManaMatchVFXControllerScript.new()
			mana_match_vfx_controller.name = "ManaMatchVFX"
			add_child(mana_match_vfx_controller)
		CombatManager.set_grid($"../Grid")
		connect_signals()
		create_player()
		create_mob()
		# Keep a reference on the GameManager for combat-scoped access
		# (manager already created above for all modes)
		# self.vfx_manager is already set
		# Instantiate BuffManagers for player and monster
		var player_buff_manager = FW_BuffManager.new()
		player_buff_manager.set_meta("owner_type", "player")
		GDM.player.buffs = player_buff_manager
		player_buff_bar.owner_buffs = GDM.player.buffs

		if GDM.monster_to_fight:
			var monster_buff_manager = FW_BuffManager.new()
			monster_buff_manager.set_meta("owner_type", "monster")
			GDM.monster_to_fight.buffs = monster_buff_manager
			monster_buff_bar.owner_buffs = GDM.monster_to_fight.buffs

		# Apply any pending combat buffs from events now that buff managers are initialized
		_apply_pending_combat_buffs()

		GDM.effect_manager.initialize_combat_state()
		setup_dice_viewport()
	else:
		create_goals()

	set_level_data()
	if !is_moves:
		$move_timer.start()
	scoreboard.counter = max_counter
	scoreboard.score = 0
	if GDM.level_info.has(level):
		if GDM.level_info[level].has("high_score"):
			scoreboard.high_score = GDM.level_info[level]["high_score"]
		else:
			scoreboard.high_score = max_score
	emit_signal("set_score_info", max_score, scoreboard.score)
	emit_signal("set_counter_info", scoreboard.counter)

# Helper method for future PvP setup
func setup_pvp_match(opponent_player_data: Dictionary) -> void:
	"""Setup a PvP match against downloaded player data"""
	# Create combatants
	var player_combatant = FW_Combatant.from_current_player()
	self.current_player_combatant = player_combatant
	var opponent_combatant = FW_PlayerSerializer.deserialize_player_data(opponent_player_data)
	# Initialize combat
	initialize_generic_combat(player_combatant, opponent_combatant)

func setup_dice_viewport() -> void:
	viewport_display.texture = dice_viewport.get_texture()
	dice_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _initialize_turn_manager() -> void:
	"""Initialize the TurnManager for centralized turn state management"""
	turn_manager = FW_TurnManager.new()
	add_child(turn_manager)
	turn_manager.set_game_manager(self)
	turn_manager.set_grid($"../Grid")

	# Connect to TurnManager signals to keep is_player_turn synchronized
	turn_manager.turn_started.connect(_on_turn_manager_turn_started)

	var initiative_winner := GDM.consume_initiative_winner()
	call_deferred("_deferred_initialize_turns", initiative_winner)

func _deferred_initialize_turns(initiative_winner: GDM.Initiative) -> void:
	# Defer turn startup so UI listeners finish connecting before signals fire
	await get_tree().process_frame
	await get_tree().process_frame
	_initial_turn_state = _get_turn_state_for_initiative(initiative_winner)
	_log_initiative_outcome(initiative_winner)
	if turn_manager:
		turn_manager.start_game(_initial_turn_state)
	_emit_initial_legacy_turn_signal()

func _get_turn_state_for_initiative(initiative_winner: GDM.Initiative) -> int:
	if initiative_winner == GDM.Initiative.MONSTER:
		return FW_TurnManager.TurnState.MONSTER_TURN
	return FW_TurnManager.TurnState.PLAYER_TURN

func _log_initiative_outcome(initiative_winner: GDM.Initiative) -> void:
	var player_name := "Player"
	if GDM.player and GDM.player.character:
		player_name = GDM.player.character.name
	var opponent_name := "Opponent"
	if GDM.monster_to_fight:
		opponent_name = GDM.monster_to_fight.name
	var message := ""
	if initiative_winner == GDM.Initiative.MONSTER:
		message = "%s seizes the initiative! %s will act second." % [opponent_name, player_name]
	else:
		message = "%s wins the initiative! %s prepares to respond." % [player_name, opponent_name]
	EventBus.publish_combat_log.emit(message)

func _emit_initial_legacy_turn_signal() -> void:
	if _initial_turn_state == FW_TurnManager.TurnState.MONSTER_TURN:
		emit_signal("enemy_turn")
	else:
		emit_signal("player_turn")

func _on_turn_manager_turn_started(turn_state: int) -> void:
	"""Update is_player_turn boolean to match TurnManager state and emit legacy signals"""
	if turn_state == FW_TurnManager.TurnState.PLAYER_TURN:
		is_player_turn = true
		emit_signal("player_turn")  # Emit legacy signal for scene connections
	elif turn_state == FW_TurnManager.TurnState.MONSTER_TURN:
		is_player_turn = false
		emit_signal("enemy_turn")   # Emit legacy signal for scene connections

func monster_check_if_enough_mana(ability: FW_Ability) -> bool:
	return FW_AbilityManager.check_sufficient_mana(ability.cost, mana.enemy)

func check_usable_ability(ability: FW_Ability) -> bool:
	return FW_AbilityManager.check_ability_usable(ability, mana.enemy, monster_cooldown_manager)

func get_usable_abilities(abilities: Array[FW_Ability]) -> Array[FW_Ability]:
	return FW_AbilityManager.filter_usable_abilities(abilities, mana.enemy, monster_cooldown_manager)

func monster_turn_process() -> void:
	# Validate turn state through TurnManager
	if not turn_manager.is_monster_turn():
		return

	# Check if monster exists
	if not GDM.monster_to_fight:
		turn_manager.force_end_current_turn()
		return

	# Get usable abilities
	var usable_abilities = get_usable_abilities(GDM.monster_to_fight.abilities)

	if usable_abilities.size() > 0:
		# Randomly select an ability
		var ability_to_use = usable_abilities[randi() % usable_abilities.size()]

		# Use TurnManager to handle the action with proper state checking
		turn_manager.request_monster_action(func():
			EventBus.play_sound_for_booster.emit()
			monster_use_ability(ability_to_use)
		)
	else:
		# Request tile move through EventBus
		EventBus.monster_request_tile_move.emit()

func monster_use_ability(ability: FW_Ability) -> void:
	# Use TurnManager for state validation
	if not turn_manager.can_perform_action():
		return

	booster_active = true
	board_stable = false

	CombatManager.resolve_ability_usage(ability, mana)

	booster_active = false

	EventBus.trigger_refill.emit()

func _on_grid_end_monster_turn() -> void:
	# Use TurnManager to handle turn transitions
	turn_manager.end_monster_turn()

func _on_grid_end_player_turn() -> void:
	# Use TurnManager to handle turn transitions
	turn_manager.end_player_turn()

func change_board_state(state: bool) -> void:
	board_stable = state
	# Notify TurnManager of board state changes (if it exists)
	if turn_manager:
		turn_manager.set_board_stable(state)

func create_delayed_timer(delay: float, callback: Callable) -> void:
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(func():
		callback.call()
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

func set_level_data() -> void:
	GDM.grid.width = width
	GDM.grid.height = height
	GDM.level = level
	emit_signal("set_level", level)

func show_hide_boosters() -> void:
	for i in range(GDM.player.abilities.size()):
		var booster_data = GDM.player.abilities[i]
		if booster_data != null:
			var enough_mana = FW_AbilityManager.check_sufficient_mana(booster_data.cost, mana.player)
			EventBus.refresh_boosters.emit(enough_mana, booster_data.name)

func connect_signals() -> void:
	# Connect owner-specific damage over time signals
	EventBus.do_damage_to_player.connect(do_damage_to_player)
	EventBus.do_damage_to_monster.connect(do_damage_to_monster)
	# Connect owner-specific shield signals
	EventBus.do_player_gain_shields.connect(do_player_gain_shields)
	EventBus.do_monster_gain_shields.connect(do_monster_gain_shields)
	# Connect owner-specific mana gain signals
	EventBus.do_player_gain_mana.connect(do_player_gain_mana)
	EventBus.do_monster_gain_mana.connect(do_monster_gain_mana)
	EventBus.trigger_show_hide_boosters.connect(show_hide_boosters)
	# Connect monster turn start to monster turn process
	EventBus.start_of_monster_turn.connect(monster_turn_process)
	# Remove duplicate monster_turn connections - TurnManager handles this now
	EventBus.sinker_destroyed.connect(_on_sinker_destroyed_damage)
	EventBus.hide_dice.connect(hide_dice_viewport)
	EventBus.show_dice.connect(show_dice_viewport)
	_connect_dice_signals()

func create_player() -> void:
	GDM.safe_steam_set_rich_presence("#combat", GDM.player.character.name)
	emit_signal("create_character", GDM.player.character)
	# Register player abilities with the VFX manager so their effects are known for this combat
	if vfx_manager and is_instance_valid(vfx_manager):
		vfx_manager.register_effects_for_combatant(GDM.player)

func check_goals(value: String) -> void:
	for child in goal_holder.get_children():
		if child.is_piece_goal:
			child.check_goal(value)
		else:
			child.check_goal("points", scoreboard.score)
	check_game_win()

func create_mob() -> void:
	# Check if monster_to_fight is set
	if not GDM.monster_to_fight:
		return

	# For PvP monsters, stats are pre-configured, no need to modify
	# For regular monsters, stats should already be set up during level generation

	# Only call setup() if monster doesn't already have abilities (to avoid re-randomization)
	if GDM.monster_to_fight.abilities.size() == 0 or not GDM.monster_to_fight.abilities_initialized:
		GDM.monster_to_fight.setup()
	else:
		# Still need to initialize AI even if abilities are already set
		match GDM.monster_to_fight.ai_type:
			FW_MonsterAI.monster_ai.RANDOM:
				GDM.monster_to_fight.ai = FW_RandomSelector.new()
			FW_MonsterAI.monster_ai.SENTIENT:
				GDM.monster_to_fight.ai = FW_SentientSelector.new()
			FW_MonsterAI.monster_ai.BOMBER:
				GDM.monster_to_fight.ai = FW_BomberSelector.new()
				GDM.monster_to_fight.ai.next_selector = FW_SentientSelector.new()
				GDM.monster_to_fight.ai.next_selector.next_selector = FW_RandomSelector.new()
			FW_MonsterAI.monster_ai.SELF_AWARE:
				GDM.monster_to_fight.ai = FW_SelfAwareSelector.new()
				GDM.monster_to_fight.ai.next_selector = FW_BomberSelector.new()
				GDM.monster_to_fight.ai.next_selector.next_selector = FW_SentientSelector.new()
				GDM.monster_to_fight.ai.next_selector.next_selector.next_selector = FW_RandomSelector.new()
			_:
				printerr("AI type not implemented for this archetype")

	emit_signal("create_monster", GDM.monster_to_fight)

	# Register effects used by the monster (so CVEM can cache/load only needed VFX)
	if vfx_manager and is_instance_valid(vfx_manager):
		vfx_manager.register_effects_for_combatant(GDM.monster_to_fight)
		# Also ensure the player abilities are registered at this point in case
		# the player was created/updated after create_player() or abilities were
		# modified during setup. This guarantees both sides are scanned.
		if GDM.player:
			# var p_abils = null
			# if typeof(GDM.player) == TYPE_OBJECT:
			# 	p_abils = GDM.player.get("abilities")
			#var pcount = 0
			# if p_abils and typeof(p_abils) == TYPE_ARRAY:
			# 	pcount = p_abils.size()
			vfx_manager.register_effects_for_combatant(GDM.player)
		vfx_manager.preload_combat_cache()
func initialize_generic_combat(player_combatant: FW_Combatant, opponent_combatant: FW_Combatant) -> void:
	"""Initialize combat using generic combatant system"""
	self.current_player_combatant = player_combatant
	# Setup combatants
	player_combatant.setup()
	opponent_combatant.setup()

	# Ensure BuffManagers exist and have correct metadata
	if not player_combatant.buffs:
		player_combatant.buffs = FW_BuffManager.new()
	player_combatant.buffs.set_meta("owner_type", "player")

	if not opponent_combatant.buffs:
		opponent_combatant.buffs = FW_BuffManager.new()
	opponent_combatant.buffs.set_meta("owner_type", "monster")

	# Initialize the centralized combat state with generic combatants
	GDM.effect_manager.initialize_combat_state_generic(player_combatant, opponent_combatant)

	# Apply any pending combat buffs from events
	_apply_pending_combat_buffs()

	emit_signal("create_character", _extract_character_from_combatant(player_combatant))
	emit_signal("create_monster", _extract_monster_from_combatant(opponent_combatant))

	# Register VFX for the combatants so CVEM can cache what it needs for this fight
	if vfx_manager and is_instance_valid(vfx_manager):
		vfx_manager.register_effects_for_combatant(player_combatant)
		vfx_manager.register_effects_for_combatant(opponent_combatant)
		vfx_manager.preload_combat_cache()

# Helper method to extract Character resource from Combatant for UI compatibility
func _extract_character_from_combatant(combatant: FW_Combatant) -> FW_Character:
	"""Extract a Character resource from a Combatant for backward compatibility"""
	var character = FW_Character.new()
	character.name = combatant.name
	character.texture = combatant.texture
	character.description = combatant.description
	character.affinities = combatant.affinities
	character.effects = combatant.character_effects
	return character

# Helper method to extract Monster_Resource from Combatant for UI compatibility
func _extract_monster_from_combatant(combatant: FW_Combatant) -> FW_Monster_Resource:
	"""Extract a Monster_Resource from a Combatant for backward compatibility"""
	var monster = FW_Monster_Resource.new()
	monster.name = combatant.name
	monster.texture = combatant.texture
	monster.description = combatant.description
	monster.affinities = combatant.affinities
	monster.abilities = combatant.abilities
	monster.max_hp = combatant.get_max_hp()
	monster.shields = combatant.get_max_shields()
	monster.stats = combatant.stats
	monster.buffs = combatant.buffs
	monster.ai_type = combatant.ai_type

	# Mark as PvP monster to prevent random ability assignment
	monster.is_pvp_monster = combatant.is_pvp_opponent

	return monster

func do_damage_over_time(amount: int = DEFAULT_DOT_AMOUNT, reason: String = "") -> void: # TODO: Change the default back to 1, just testing
	CombatManager.resolve_dot(amount, reason)
	check_game_win()

func do_damage(amount: int = DEFAULT_DOT_AMOUNT, reason: String = "", bomb: bool = false) -> void: # TODO: Change the default back to 1, just testing
	var attacker_is_player = turn_manager.is_player_turn() if turn_manager else true
	CombatManager.apply_damage_with_checks(amount, reason, attacker_is_player, bomb, false)
	check_game_win()

# Owner-specific damage over time methods
func do_damage_to_player(amount: int, reason: String) -> void:
	GDM.effect_manager.apply_damage(true, amount)
	if reason and reason.strip_edges() != "":
		EventBus.publish_damage.emit(amount, reason, false)  # false = monster is attacker
	check_game_win()

func do_damage_to_monster(amount: int, reason: String) -> void:
	GDM.effect_manager.apply_damage(false, amount)
	if reason and reason.strip_edges() != "":
		EventBus.publish_damage.emit(amount, reason, true)  # true = player is attacker
	check_game_win()

# Owner-specific shield gain methods
func do_player_gain_shields(_amount: int, _ability_texture: Texture2D = null, _target_name: String = "") -> void:
	# CombatManager is the single writer for shield changes. This handler
	# exists for UI/compatibility hooks only and should not modify state.
	# Keep it minimal so duplicate adds don't occur.
	return

func do_monster_gain_shields(_amount: int, _ability_texture: Texture2D = null, _target_name: String = "") -> void:
	# CombatManager is the single writer for shield changes. This handler
	# exists for UI/compatibility hooks only and should not modify state.
	return

# Owner-specific mana gain methods (for buffs like Rage)
func do_player_gain_mana(mana_dict: Dictionary) -> void:
	# The mana has already been added to the pool by CombatManager
	# Here we can handle UI updates, logging, etc.
	GDM.tracker.gain_mana(mana_dict)
	emit_signal("publish_mana_bonus", mana_dict)

func do_monster_gain_mana(mana_dict: Dictionary) -> void:
	# Monster mana gain (less tracked than player)
	# The mana has already been added to the pool by CombatManager
	emit_signal("publish_mana_bonus", mana_dict)

func set_state_for_save() -> void:
	# Mark node as cleared for persistent level state
	var map_hash = GDM.current_info.world.world_hash
	GDM.mark_node_cleared(map_hash, GDM.current_info.level.level_hash, true)

	GDM.world_state.update_path_history(
		GDM.current_info.world.world_hash,
		GDM.current_info.level.level_depth,
		GDM.current_info.level
	)
	if OS.is_debug_build():
		FW_Debug.debug_log(["[GameManager] update_path_history - world_hash=", GDM.current_info.world.world_hash, "level_depth=", GDM.current_info.level.level_depth, "level_hash=", GDM.current_info.level.level_hash])
	GDM.player.monster_kills.append(GDM.monster_to_fight)
	if GDM.current_info.level.level_depth == GDM.current_info.level_to_generate["max_depth"]:
		# FIXED: Use consistent map_hash (world.world_hash) for completion tracking
		GDM.world_state.update_completed(GDM.current_info.world.world_hash, true)
		if OS.is_debug_build():
			FW_Debug.debug_log(["[GameManager] update_completed - world_hash=", GDM.current_info.world.world_hash])
	var new_level := GDM.world_state.get_current_level(GDM.current_info.world.world_hash) + 1
	GDM.world_state.update_current_level(GDM.current_info.world.world_hash, new_level)

	# Emit signal that this level was completed
	EventBus.level_completed.emit(GDM.current_info.level)

	# apply xp from monster
	GDM.level_manager.add_xp(GDM.monster_to_fight.xp)
	var xp = GDM.monster_to_fight.xp
	create_delayed_timer(FW_GameConstants.XP_GAIN_DELAY, func():
		EventBus.gain_xp.emit(xp)
	)
	GDM.vs_save()

func check_vs_game_win() -> void:
	if monster_dead and !game_is_won:
		emit_signal("game_won", 1, 1)
		game_is_won = true
		set_state_for_save()
		clean_up_buff_stats_cooldowns()
		emit_signal("game_won_vs")
		EventBus.publish_combat_log.emit(GDM.player.character.name + " won vs " + GDM.monster_to_fight.name + "!")
		if GDM.player.abilities.size() > 0:
			var job = FW_JobManager.get_job(GDM.player.abilities)
			if job:
				UnlockManager.mark_job_win(job.name)
		if turn_manager:
			turn_manager.set_game_won(true)
	elif player_dead:
		clean_up_buff_stats_cooldowns()
		emit_signal("grid_change_move")
		emit_signal("game_lost_vs")
		EventBus.publish_combat_log.emit(GDM.monster_to_fight.name + " won vs " + GDM.player.character.name + "!")
		if turn_manager:
			turn_manager.set_game_lost()

func clean_up_buff_stats_cooldowns() -> void:
	# cleanup buffs and cooldowns between rounds
	if player_cooldown_manager:
		player_cooldown_manager.reset_cooldowns()
	if monster_cooldown_manager:
		monster_cooldown_manager.reset_cooldowns()

	# Clear combat-only buffs (from event failures)
	clear_combat_only_buffs()

	if GDM.player.buffs:
		GDM.player.buffs.clear_buffs()
	if GDM.monster_to_fight and GDM.monster_to_fight.buffs:
		GDM.monster_to_fight.buffs.clear_buffs()
	# Reset temporary stat bonuses for both sides so retries start clean
	if GDM.player and GDM.player.stats:
		GDM.player.stats.reset_temporary_bonuses()
	if GDM.monster_to_fight and GDM.monster_to_fight.stats:
		GDM.monster_to_fight.stats.reset_temporary_bonuses()

func game_over() -> bool:
	if GDM.is_vs_mode():
		return false
	if scoreboard.counter > 0:
		return false
	scoreboard.counter = 0
	if !game_is_lost and board_stable:
		emit_signal("game_lost")
		game_is_lost = true
		$move_timer.one_shot = true
		return true
	return false

func create_goals() -> void:
	for i in goal_holder.get_child_count():
		var current = goal_holder.get_child(i)
		emit_signal("create_goal", current.max_needed, current.goal_texture, current.goal_string)

func check_game_win() -> void:
	if not board_stable:
		return
	if GDM.is_vs_mode():
		check_vs_game_win()
	else:
		check_normal_game_win()

func goals_met() -> bool:
	for i in goal_holder.get_child_count():
		if !goal_holder.get_child(i).goal_met:
			return false
	return true

func check_normal_game_win() -> void:
	if goals_met():
		var moves_taken = max_counter - scoreboard.counter
		emit_signal("game_won", scoreboard.score, moves_taken)
		var level_dict = GDM.level_info.get(level, {})
		var updates = update_level_info(level_dict, moves_taken)
		if updates:
			GDM.level_info[level] = level_dict
			unlock_next_level(level)
			GDM.save_data()
			game_is_won = true

func update_level_info(level_dict: Dictionary, moves_taken: int) -> bool:
	var updated = false
	if scoreboard.score >= scoreboard.high_score:
		level_dict["high_score"] = scoreboard.score
		updated = true
	if scoreboard.score > max_score:
		level_dict["stars_unlocked"] = 1
		updated = true
	elif level_dict.get("stars_unlocked", 0) < 1:
		level_dict["stars_unlocked"] = 0
	if level_dict.has("moves"):
		if level_dict["moves"] > moves_taken:
			level_dict["moves"] = moves_taken
			updated = true
	else:
		level_dict["moves"] = moves_taken
		updated = true
	level_dict["unlocked"] = true
	return updated

func unlock_next_level(current_level: int) -> void:
	if not GDM.level_info.has(current_level + 1):
		GDM.level_info[current_level + 1] = {"unlocked": true}

func update_counter(streak: int) -> void:
	if board_stable and streak == 1:
		scoreboard.counter -= 1
		if !game_over():
			emit_signal("set_counter_info", scoreboard.counter)

func _on_grid_update_score(streak_val: int) -> void:
	if GDM.is_vs_mode():
		var current_is_player_turn = turn_manager.is_player_turn() if turn_manager else true
		if current_is_player_turn:
			GDM.tracker.track_streak(streak_val)
		combo_multiplier = streak_val
		emit_signal("update_combo", streak_val)
	else:
		scoreboard.score += streak_val * points_per_piece
		emit_signal("update_combo", streak_val)
		emit_signal("update_score_goal", scoreboard.score)
		emit_signal("set_score_info", max_score, scoreboard.score)

func _on_grid_update_counter(streak: int = 1) -> void:
	if is_moves and !game_is_won:
		update_counter(streak)

func _on_move_timer_timeout(streak: int = 1) -> void:
	if !is_moves and !game_is_won:
		update_counter(streak)

func _on_grid_check_goal(value: String, _location: Vector2 = Vector2(0, 0)) -> void:
	if !GDM.is_vs_mode():
		check_goals(value)

func _on_grid_change_move_state(state: bool) -> void:
	change_board_state(state)
	check_game_win()

func add_mana_bonus_to_total(total_mana: Dictionary, bonus_mana: Dictionary) -> void:
	for color in bonus_mana.keys():
		total_mana[color] = total_mana.get(color, 0) + bonus_mana[color]

func greater_than_0(number):
	return number > 0


# Use CombatManager for affinity damage
func apply_affinity_damage(character: Resource, mana_dict: Dictionary) -> void:
	var attacker_is_player = turn_manager.is_player_turn() if turn_manager else true
	CombatManager.apply_affinity_damage(character, mana_dict, combo_multiplier, attacker_is_player)

func update_mana_for_actor(color_dict: Dictionary) -> void:
	var mana_update_data = get_mana_update_data()
	var update_dict = mana_update_data.mana_pool
	var max_mana = mana_update_data.max_mana
	var character = mana_update_data.character

	apply_affinity_damage(character, color_dict)
	CombatManager.process_queue()  # Process queued affinity damage commands
	handle_mana_bonus(color_dict)
	apply_mana_updates(update_dict, color_dict, max_mana)

	if is_player_turn:
		GDM.tracker.gain_mana(color_dict)

	EventBus.update_mana.emit(update_dict)
	emit_signal("publish_mana", color_dict)
	show_hide_boosters()

func get_mana_update_data() -> Dictionary:
	var current_is_player_turn = turn_manager.is_player_turn() if turn_manager else true
	if current_is_player_turn:
		return {
			"max_mana": GDM.player.stats.calculate_max_mana(),
			"character": GDM.player.character,
			"mana_pool": mana.player
		}
	else:
		return {
			"max_mana": MONSTER_MAX_MANA,
			"character": GDM.monster_to_fight,
			"mana_pool": mana.enemy
		}

func handle_mana_bonus(color_dict: Dictionary) -> void:
	var bonus_mana: Dictionary = GDM.effect_manager.process_mana_gain(color_dict)
	if bonus_mana.values().any(greater_than_0):
		emit_signal("publish_mana_bonus", bonus_mana)
		add_mana_bonus_to_total(color_dict, bonus_mana)

func apply_mana_updates(update_dict: Dictionary, color_dict: Dictionary, max_mana: Dictionary) -> void:
	for key in color_dict.keys():
		update_dict[key] = clampi(update_dict[key] + color_dict[key], 0, max_mana[key])

func _on_grid_update_mana(color_dict: Dictionary) -> void:
	update_mana_for_actor(color_dict)

func _on_grid_do_damage() -> void:
	do_damage(BOMB_DAMAGE, "damage from matching a bomb!", true)

func _on_sinker_destroyed_damage(_sinker_owner: FW_Piece.OWNER, _sinker_type: FW_Ability) -> void:
	# In theory sinker damage is now managed by the effect system, so we can gradually remove this
#	#var sinker_damage = sinker_type.effects["sinker_damage"]
#	# will need to make this generic when we add other types but for now it's ok
	#CombatManager.resolve_sinker(sinker_damage, "damage from a %s!" % sinker_type.name, sinker_owner)
	check_game_win()

func _on_grid_booster_inactive() -> void:
	booster_active = false
	if game_is_won:
		return
	emit_signal("grid_change_move")

func _on_top_ui_2_monster_dead() -> void:
	monster_dead = true

func _on_top_ui_2_player_dead() -> void:
	player_dead = true

func _on_bottom_ui_2_booster_pressed(ability: FW_Ability) -> void:
	# Guard against null abilities
	if not ability:
		return

	# Trace booster press path from UI
	if EventBus.has_signal("debug_log"):
		FW_Debug.debug_log(["FW_GameManager._on_bottom_ui_2_booster_pressed: ability=%s" % ability.name])
	var current_is_player_turn = turn_manager.is_player_turn() if turn_manager else true
	if board_stable and current_is_player_turn and !booster_active and !player_cooldown_manager.abilities.has(["player", ability.name]):
		if check_if_enough_mana(ability):
			booster_active = true
			board_stable = false
			emit_signal("grid_change_move")
			EventBus.play_sound_for_booster.emit()
			# Centralized combat resolver now handles ability logic
			CombatManager.resolve_ability_usage(ability, mana)
			EventBus.update_cooldowns.emit()

func check_if_enough_mana(ability: FW_Ability) -> bool:
	return FW_AbilityManager.check_sufficient_mana(ability.cost, mana.player)

func _on_pause_2_cleanup() -> void:
	clean_up_buff_stats_cooldowns()
	emit_signal("reset_grid_vars")

func show_dice_viewport() -> void:
	# Prevent redundant activation
	if viewport_display.visible:
		return
	# Enable viewport updates only when needed during the roll
	dice_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Prime the texture before showing to avoid a blank frame
	viewport_display.texture = dice_viewport.get_texture()
	await get_tree().process_frame
	viewport_display.show()

func hide_dice_viewport() -> void:
	# Fast-path: if already hidden, ensure viewport is disabled
	if not viewport_display.visible:
		dice_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# Disable rendering first to stop GPU work immediately
	dice_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Hide and release the texture reference to avoid unnecessary updates
	viewport_display.hide()
	viewport_display.texture = null

func _connect_dice_signals():
	dice_results.clear()
	# Recursively find all dice in the dice_viewport
	var dice_nodes = []
	_find_dice_nodes(dice_viewport, dice_nodes)
	for die in dice_nodes:
		die.connect("roll_finished", Callable(self, "_on_die_roll_finished"))

func _find_dice_nodes(node: Node, dice_nodes: Array) -> void:
	if node.has_method("trigger_roll") and node.has_signal("roll_finished"):
		dice_nodes.append(node)
	for child in node.get_children():
		_find_dice_nodes(child, dice_nodes)

func _on_die_roll_finished(value: int, die_type, roll_for: String):
	dice_results[die_type] = value
	if dice_results.size() == 2:
		var result = calculate_percentile_result()
		EventBus.dice_roll_result.emit(result)
		EventBus.dice_roll_result_for.emit(result, roll_for)
		create_delayed_timer(FW_GameConstants.DICE_ROLL_DELAY, func():
			EventBus.hide_dice.emit()
		)

func calculate_percentile_result() -> int:
	var percentile = dice_results.get(1, 0)
	var ones = dice_results.get(0, 0)
	return FW_Utils._combine_percentile_dice(percentile, ones)

func download_random_opponent() -> void:
	"""Download a random opponent - now uses the simplified caching system"""
	var opponent = FW_PvPCache.get_opponent()
	if opponent:
		_on_opponent_download_success(opponent)
	else:
		_on_opponent_download_failed()

func _on_opponent_download_success(opponent: FW_Combatant) -> void:
	"""Handle successful opponent download"""
	setup_pvp_match_with_opponent(opponent)

func _on_opponent_download_failed() -> void:
	"""Handle failed opponent download"""
	printerr("✗ Failed to download opponent from server")

func setup_pvp_match_with_opponent(opponent: FW_Combatant) -> void:
	"""Set up a PvP match with a downloaded opponent"""
	# Convert the opponent Combatant to a Monster_Resource for compatibility
	var monster_resource = _extract_monster_from_combatant(opponent)
	GDM.monster_to_fight = monster_resource

	# Initialize the PvP match using the generic combat system
	var player_combatant = FW_Combatant.from_current_player()
	self.current_player_combatant = player_combatant
	initialize_generic_combat(player_combatant, opponent)

func _exit_tree() -> void:
	# Ensure any active visual effects are cleaned up when leaving the scene
	if vfx_manager and is_instance_valid(vfx_manager):
		vfx_manager.clear_all_effects()

# Event failure effect management methods
func _apply_pending_combat_buffs() -> void:
	"""Apply any buffs that were queued from event failures to be applied at combat start"""
	if not GDM.has_meta("pending_combat_buffs"):
		return

	var pending_buffs = GDM.get_meta("pending_combat_buffs")
	if not pending_buffs or pending_buffs.size() == 0:
		return

	for buff in pending_buffs:
		if buff is FW_Buff:
			# Apply to player using the combat-only method
			if GDM.player and GDM.player.buffs:
				GDM.player.buffs.add_combat_only_buff(buff)
			elif GDM.effect_manager and GDM.effect_manager.is_using_generic_combatants():
				# For generic combat system
				var player_combatant = GDM.effect_manager.player_combatant
				if player_combatant and player_combatant.buffs:
					player_combatant.buffs.add_combat_only_buff(buff)

	# Clear the pending buffs since they've been applied
	GDM.set_meta("pending_combat_buffs", [])

func clear_combat_only_buffs() -> void:
	"""Clear all combat-only buffs when combat ends"""
	if GDM.player and GDM.player.buffs:
		GDM.player.buffs.clear_combat_only_buffs()

	if GDM.monster_to_fight and GDM.monster_to_fight.buffs:
		GDM.monster_to_fight.buffs.clear_combat_only_buffs()

	# Also clear from generic combatants if using that system
	if GDM.effect_manager and GDM.effect_manager.is_using_generic_combatants():
		var player_combatant = GDM.effect_manager.player_combatant
		var opponent_combatant = GDM.effect_manager.opponent_combatant

		if player_combatant and player_combatant.buffs:
			player_combatant.buffs.clear_combat_only_buffs()

		if opponent_combatant and opponent_combatant.buffs:
			opponent_combatant.buffs.clear_combat_only_buffs()
