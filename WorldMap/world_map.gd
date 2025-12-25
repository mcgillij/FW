extends CanvasLayer

@onready var dialogue_box = $DialogueBox
@onready var audio_player = $AudioStreamPlayer
@onready var stats_holder: VBoxContainer = %StatsHolder

@onready var world_1: TextureRect = %world1
@onready var world_2: TextureRect = %World2
@onready var world_3: TextureRect = %World3
@onready var world_4: TextureRect = %World4
@onready var world_5: TextureRect = %World5
@onready var world_6: TextureRect = %World6
@onready var world_7: TextureRect = %World7

@onready var act1: TextureRect = %act1
@onready var act2: TextureRect = %act2
@onready var act3: TextureRect = %act3
@onready var act4: TextureRect = %act4
@onready var act5: TextureRect = %act5
@onready var act6: TextureRect = %act6

@onready var monster_loading_label: RichTextLabel = %monster_loading_label
@onready var load_panel: Panel = %load_panel
@onready var back_button: TextureButton = $back_button

@export var char_info_prefab: PackedScene
@export var menu_prefab: PackedScene = preload("res://PopupMenu/custom_popup_menu.tscn")
@export var paw_print_scene: PackedScene = preload("res://Scenes/PawPrint.tscn")
@export var main_quest_registry: FW_QuestRegistry = preload("res://Quest/Resources/main_quest_registry.tres")
@export var loot_screen_scene: PackedScene = preload("res://LootManager/LootScreen.tscn")
@export var inventory_screen_scene: PackedScene = preload("res://Inventory/InventoryScreen.tscn")
@export var equipment_screen_scene: PackedScene = preload("res://Equipment/equipment.tscn")
@export var quest_viewer_scene: PackedScene = preload("res://Quest/QuestViewer.tscn")
@export var help_panel_scene: PackedScene = preload("res://Help/HelpTutorialGlossary.tscn")
@export var bestiary_panel_scene: PackedScene = preload("res://Scenes/bestiary_panel.tscn")
@export var mastery_tracker_scene: PackedScene = preload("res://MasteryTracker/MasteryTracker.tscn")
@export var victory_screen_scene: PackedScene = preload("res://VictoryScreen/VictoryScreen.tscn")
@export var transmogrify_scene: PackedScene = preload("res://Transmogrify/Transmogrify.tscn")

var unlock_particles = preload("res://Effects/unlock_level/unlock_effect.tscn")
var trippy_shader = preload("res://Shaders/trippy_wave_fade.gdshader")

var menu: Control
var last_mouse
var previous_node: FW_WorldNode = null
var current_npc_quest_manager: FW_NPCQuestManager
var transitioning = false
var _scroll_save_timer: Timer = null
var loot_screen: CanvasLayer = null
var inventory_screen: CanvasLayer = null
var equipment_screen: CanvasLayer = null
var quest_viewer: CanvasLayer = null
var help_panel: CanvasLayer = null
var bestiary_panel: CanvasLayer = null
var mastery_tracker: CanvasLayer = null
var victory_screen: CanvasLayer = null
var transmogrify_panel: CanvasLayer = null

@onready var world_nodes = [world_1, world_2, world_3, world_4, world_5, world_6, world_7]
@onready var act_nodes = [act1, act2, act3, act4, act5, act6]

enum MENU_DIALOG_ENTRIES {
	ABANDONED_MISSION,
	CHAT_WITH_ROYALTY,
	SPECIAL_MISSION,
	SHOPS,
	ADVENTURERS_GUILD,
	SPECIAL_NPC,
	CRAFTING,
	CAVE_MISSION,
	CHAT_WITH_CITY,
	EXTRA_LONG_MISSION,
	VENDOR,
	MAGIC_SHOP,
	CHURCH_MISSION,
	FOREST_MISSION,
	DUNGEON_MISSION,
	CHAT_WITH_FARMER,
	FARM_MISSION,
	FOREST_PATH_MISSION,
	FOREST_RIVER_MISSION,
	ICE_LAKE_MISSION,
	ICE_STREAM_MISSION,
	RUINS_MISSION,
	RUINS_VILLAGE_MISSION,
	SNOW_CAVE_MISSION,
	SNOW_FOREST_MISSION,
	SNOW_PATH_MISSION,
	SNOW_VILLAGE_MISSION,
	SNOW_VILLAGE_CHAT,
	SNOW_VILLAGE_QUEST,
	CHAT_WITH_TOWN,
	TOWN_MISSION,
	BLACKSMITH,
	CHAT_WITH_VILLAGE,
	VILLAGE_MISSION,
	VILLAGERS_QUEST,
	# PvP Arena Entries
	PVP_ARENA_LINEAR,
	PVP_ARENA_BRANCHING,
	PVP_TOURNAMENT,
	PVP_GAUNTLET,
	PVP_CHAMPIONS_LEAGUE,
	# Themed Dungeon Entries
	VAMPIRE_LAIR,
	ORC_STRONGHOLD,
	SKELETON_CRYPT,
	DOGHOUSE,
	SNOWMAN,
	UNLOCK,
	NOT_ENOUGH_MONEY
}

var levels_completed := 0
var _monster_loading = false
var _loading_start_time = 0.0
var _min_loading_display_time = 1.5  # Minimum time to show loading UI in seconds

func _ready() -> void:
	_init_unlock_flags()
	_init_monster_loading()
	_init_ui()
	_init_character_info()
	_init_world_nodes()
	_init_act_visibility()
	# Update prize wheel visibility based on existing progress/run state
	call_deferred("_update_prize_wheel_visibility")
	_check_and_handle_world_unlocks()
	_connect_signals()
	_setup_scroll_save_timer()
	call_deferred("update_doghouse_texture")
	call_deferred("_show_combined_stats_if_needed")

	# TODO: Testing inventory
	#var lm = FW_LootManager.new()
	#lm.give_test_consumables_to_player(3)
	#lm.give_consumable_slot_equipment()

func _process(_delta: float) -> void:
	if _monster_loading:
		update_loading_ui()
		if FW_RandomMonster.is_loading_complete():
			var current_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60.0
			var elapsed_time = current_time - _loading_start_time

			if elapsed_time >= _min_loading_display_time:
				_monster_loading = false
				# Show completion message
				monster_loading_label.text = "[center][b]Monsters Loaded![/b]\n[color=green]🐉🐉🐉🐉🐉🐉🐉🐉🐉🐉[/color]\nReady to adventure![/center]"
				# Start timer to hide panel
				var timer = get_tree().create_timer(2.0)
				timer.timeout.connect(_on_hide_panel_timeout)
func _init_unlock_flags() -> void:
	UnlockManager.clear_just_unlocked_act()  # Clear any leftover unlock flags to prevent repeated animations

func _init_monster_loading() -> void:
	# Only reset loading state if monsters haven't been loaded yet
	# This ensures caching works across scene changes
	if not FW_RandomMonster.is_loading_complete():
		FW_RandomMonster.reset_loading_state()

	GDM.setup_level_manager()

	# Check if monsters are already loaded from previous session
	var already_loaded = FW_RandomMonster.is_loading_complete()

	if already_loaded:
		# Monsters already loaded, skip loading UI entirely
		load_panel.visible = false
		monster_loading_label.visible = false
		_monster_loading = false
	else:
		# Need to show loading UI
		load_panel.visible = true
		monster_loading_label.visible = true
		# Start loading monsters asynchronously
		FW_RandomMonster.start_loading()
		_monster_loading = true
		_loading_start_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60.0
		# Initial UI update
		update_loading_ui()

func _init_ui() -> void:
	SoundManager.wire_up_all_buttons()
	GDM.safe_steam_set_rich_presence("#adventure_map")
	dialogue_box.custom_effects[0].char_displayed.connect(_on_char_displayed)
	toggle_completed()
	# Safely get scroll position from player if available
	var scroll_pos = 0
	if GDM.player:
		scroll_pos = GDM.player.world_map_scroll_position
	$ScrollContainer.set_deferred("scroll_vertical", scroll_pos)
	$ScrollContainer.scroll_ended.connect(scroll)

func _init_character_info() -> void:
	var char_info = char_info_prefab.instantiate()
	stats_holder.add_child(char_info)
	char_info.setup()
	prepare_dialogue_character()
	set_player_position_on_map()

func _init_world_nodes() -> void:
	# Handle world active nodes for all worlds
	GDM.world_state.current_seed = GDM.get_current_run_seed()  # Sync seed
	for i in range(world_nodes.size()):
		var world_node = world_nodes[i]
		var world_id = "world" + str(i + 1)
		var node_list = []
		for node in world_node.get_children():
			# Skip non-world child nodes (e.g., tutorial button)
			if not node or not node.has_method("_update_quest_flag"):
				continue
			# Exclude special nodes like Doghouse and Snowman (static nodes) from random activation
			if node.loaded and node.loaded.type != FW_WorldNode.NODE_TYPE.DOG_HOUSE and node.loaded.type != FW_WorldNode.NODE_TYPE.PRIZE_WHEEL and node.loaded.type != FW_WorldNode.NODE_TYPE.SNOWMAN and node.loaded.type != FW_WorldNode.NODE_TYPE.TUTORIAL_SIGNPOST:
				node_list.append(node)
			elif node and node.loaded and node.loaded.type == FW_WorldNode.NODE_TYPE.SNOWMAN and OS.is_debug_build():
				FW_Debug.debug_log(["[world_map] static node detected and excluded from active node list:", node.name, "(SNOWMAN)"])
		if GDM.world_state.get_world_active_nodes(world_id).is_empty():
			GDM.world_state.regenerate_world_active_nodes(world_id, node_list)
		# Debug sanity check: ensure Snowman is not included in node_list for random generation
		if OS.is_debug_build():
			for n in node_list:
				if n.loaded and n.loaded.type == FW_WorldNode.NODE_TYPE.SNOWMAN:
					FW_Debug.debug_log(["[world_map] ERROR: Snowman should not be in the randomly regenerated node list for world:", world_id, "node:", n.name])
		# Apply visibility
		for node in world_node.get_children():
			# Skip non-world child nodes and visibility management for special nodes like Doghouse and Snowman
			if not node or not node.has_method("_update_quest_flag"):
				continue
			if node.loaded and (node.loaded.type == FW_WorldNode.NODE_TYPE.DOG_HOUSE or node.loaded.type == FW_WorldNode.NODE_TYPE.SNOWMAN or node.loaded.type == FW_WorldNode.NODE_TYPE.TUTORIAL_SIGNPOST):
				if OS.is_debug_build() and node.loaded.type == FW_WorldNode.NODE_TYPE.SNOWMAN:
					FW_Debug.debug_log(["[world_map] Skipping visibility management for static node:", node.name, "(SNOWMAN)"])
				continue

			if node.loaded and node.loaded.type == FW_WorldNode.NODE_TYPE.PRIZE_WHEEL:
				# Prize wheel visibility is handled by _update_prize_wheel_visibility() later.
				# Initially hide; visibility will be computed based on path_history and collected state.
				node.visible = false
				continue

			node.visible = GDM.world_state.is_world_node_active(world_id, node.name)
		# Initially hide worlds if not unlocked
		if world_id != "world1" and not GDM.world_state.is_world_unlocked(world_id):
			world_node.visible = false

func update_doghouse_texture() -> void:
	var key = "normal"
	# Use UnlockManager (persistent) as the source of truth so the map reflects saved state
	if UnlockManager.is_forge_unlocked() and UnlockManager.is_garden_unlocked():
		key = "forge_and_garden"
	elif UnlockManager.is_forge_unlocked():
		key = "forge"
	elif UnlockManager.is_garden_unlocked():
		key = "garden"
	var texture_path = DoghouseManager.dog_house_images[key]
	# Find the doghouse node and update its visual texture
	for wn in world_nodes:
		for node in wn.get_children():
			# Skip non-world child nodes
			if not node or not node.has_method("_update_quest_flag"):
				continue
			if node.loaded and node.loaded.type == FW_WorldNode.NODE_TYPE.DOG_HOUSE:
				var tex = load(texture_path)
				# Prefer prefab API
				if node.has_method("set_doghouse_texture"):
					node.call_deferred("set_doghouse_texture", tex)
					if OS.is_debug_build():
						FW_Debug.debug_log(["[world_map] update_doghouse_texture: applied '" + key + "' to node " + str(node)])
					return
				# Fallback: update visual child
				for child in node.get_children():
					if child is Sprite2D or child is TextureRect:
						child.texture = tex
						if OS.is_debug_build():
							FW_Debug.debug_log(["[world_map] update_doghouse_texture: applied '" + key + "' to child " + str(child)])
						return

func _init_act_visibility() -> void:
	# Set act visibility for already unlocked worlds
	for i in range(1, world_nodes.size()):
		var world_id = "world" + str(i + 1)
		if GDM.world_state.is_world_unlocked(world_id) and act_nodes[i - 1] != null:
			act_nodes[i - 1].visible = true

func _check_and_handle_world_unlocks() -> void:
	# Check for world unlocks and animate if just unlocked
	var last_unlocked_world: Control = null
	for i in range(1, world_nodes.size()):  # Start from world2
		var prev_world_id = "world" + str(i)
		var current_world_id = "world" + str(i + 1)
		if GDM.world_state.get_world_completion_percentage(prev_world_id) >= 1.0 and not GDM.world_state.is_world_unlocked(current_world_id):
			GDM.world_state.unlock_world(current_world_id)
			UnlockManager.set_just_unlocked_act(current_world_id)
			# Trigger achievement for unlocking this world
			var achievement_name = "adventure_act" + str(i)
			Achievements.unlock_achievement(achievement_name)
			GDM.safe_steam_set_achievement(achievement_name.capitalize())
			var current_world_node = world_nodes[i]
			current_world_node.visible = true
			if act_nodes[i - 1] != null:
				act_nodes[i - 1].visible = true
			last_unlocked_world = current_world_node
			# Mark as just unlocked for animation
			break  # Only one at a time

	# If a world was just unlocked, scroll and animate
	if last_unlocked_world:
		call_deferred("_scroll_and_animate_world", last_unlocked_world)
	else:
		# Check if a world was just unlocked via UnlockManager
		if UnlockManager.get_just_unlocked_act().begins_with("world"):
			var unlocked_world_id = UnlockManager.get_just_unlocked_act()
			for i in range(1, world_nodes.size()):
				var world_id = "world" + str(i + 1)
				if world_id == unlocked_world_id:
					last_unlocked_world = world_nodes[i]
					call_deferred("_scroll_and_animate_world", last_unlocked_world)
					break
		else:
			# Restore scroll safely
			var scroll_pos = 0
			if GDM.player:
				scroll_pos = GDM.player.world_map_scroll_position
			$ScrollContainer.set_deferred("scroll_vertical", scroll_pos)

func _connect_signals() -> void:
	# Connect MenuPanel signals to handler functions
	var menu_panel = $MenuPanel
	menu_panel.inventory_pressed.connect(_on_inventory_button_pressed)
	menu_panel.equipment_pressed.connect(_on_equipment_button_pressed)
	menu_panel.combined_stats_pressed.connect(_on_combined_stats_button_pressed)
	menu_panel.quests_pressed.connect(_on_quests_button_pressed)
	menu_panel.skilltree_pressed.connect(_on_skilltree_button_pressed)
	menu_panel.bestiary_pressed.connect(_on_bestiary_button_pressed)
	menu_panel.tutorial_pressed.connect(_on_tutorial_button_pressed)
	menu_panel.mastery_pressed.connect(_on_mastery_button_pressed)

	# Connect notification clearing signals
	menu_panel.equipment_screen_opened.connect(_on_equipment_screen_opened)
	menu_panel.inventory_screen_opened.connect(_on_inventory_screen_opened)

	EventBus.quest_added.connect(_on_global_quest_event)
	EventBus.quest_completed.connect(_on_global_quest_event)
	EventBus.quest_goal_completed.connect(_on_global_quest_goal_event)
	EventBus.ascension_triggered.connect(_on_ascension_triggered)
	EventBus.level_completed.connect(_on_level_completed)
	# doghouse related
	EventBus.forge_unlocked.connect(update_doghouse_texture)
	EventBus.garden_unlocked.connect(update_doghouse_texture)
	EventBus.doghouse_unlocked.connect(update_doghouse_texture)

func update_loading_ui() -> void:
	var progress = FW_RandomMonster.get_loading_progress()
	var percent = int(progress * 100)
	var bar = ""
	for i in range(10):
		if i < int(progress * 10):
			bar += "[color=green]🐉[/color]"
		else:
			bar += "⚪"
	monster_loading_label.text = "[center][b]Loading Monsters...[/b]\n" + str(percent) + "%\n" + bar + "[/center]"

func _on_hide_panel_timeout() -> void:
	load_panel.visible = false

func _setup_scroll_save_timer() -> void:
	_scroll_save_timer = Timer.new()
	_scroll_save_timer.wait_time = 0.5  # Wait 0.5 seconds after scrolling stops before saving
	_scroll_save_timer.one_shot = true
	_scroll_save_timer.timeout.connect(_on_scroll_save_timeout)
	add_child(_scroll_save_timer)

func _ensure_loot_screen() -> CanvasLayer:
	if loot_screen:
		return loot_screen
	if not loot_screen_scene:
		return null
	loot_screen = loot_screen_scene.instantiate()
	loot_screen.layer = 2
	loot_screen.connect("back_button", Callable(self, "_on_loot_screen_back_button"))
	add_child(loot_screen)
	SoundManager.wire_up_all_buttons()
	return loot_screen

func _ensure_inventory_screen() -> CanvasLayer:
	if inventory_screen:
		return inventory_screen
	if not inventory_screen_scene:
		return null
	inventory_screen = inventory_screen_scene.instantiate()
	inventory_screen.layer = 2
	inventory_screen.connect("back_button", Callable(self, "_on_inventory_screen_back_button"))
	add_child(inventory_screen)
	SoundManager.wire_up_all_buttons()
	return inventory_screen

func _ensure_equipment_screen() -> CanvasLayer:
	if equipment_screen:
		return equipment_screen
	if not equipment_screen_scene:
		return null
	equipment_screen = equipment_screen_scene.instantiate()
	equipment_screen.layer = 2
	equipment_screen.connect("back_button", Callable(self, "_on_equipment_back_button"))
	add_child(equipment_screen)
	SoundManager.wire_up_all_buttons()
	return equipment_screen

func _ensure_quest_viewer() -> CanvasLayer:
	if quest_viewer:
		return quest_viewer
	if not quest_viewer_scene:
		return null
	quest_viewer = quest_viewer_scene.instantiate()
	quest_viewer.layer = 2
	quest_viewer.connect("back_button", Callable(self, "_on_quest_viewer_back_button"))
	add_child(quest_viewer)
	SoundManager.wire_up_all_buttons()
	return quest_viewer

func _ensure_help_panel() -> CanvasLayer:
	if help_panel:
		return help_panel
	if not help_panel_scene:
		return null
	help_panel = help_panel_scene.instantiate()
	help_panel.layer = 2
	help_panel.connect("back_button", Callable(self, "_on_help_panel_back_button"))
	add_child(help_panel)
	SoundManager.wire_up_all_buttons()
	return help_panel

func _ensure_bestiary_panel() -> CanvasLayer:
	if bestiary_panel:
		return bestiary_panel
	if not bestiary_panel_scene:
		return null
	bestiary_panel = bestiary_panel_scene.instantiate()
	bestiary_panel.layer = 2
	bestiary_panel.connect("back_pressed", Callable(self, "_on_bestiary_panel_back_pressed"))
	add_child(bestiary_panel)
	SoundManager.wire_up_all_buttons()
	return bestiary_panel

func _ensure_mastery_tracker() -> CanvasLayer:
	if mastery_tracker:
		return mastery_tracker
	if not mastery_tracker_scene:
		return null
	mastery_tracker = mastery_tracker_scene.instantiate()
	mastery_tracker.layer = 2
	mastery_tracker.connect("back_button", Callable(self, "_on_mastery_tracker_back_button"))
	add_child(mastery_tracker)
	SoundManager.wire_up_all_buttons()
	return mastery_tracker

func _ensure_victory_screen() -> CanvasLayer:
	if victory_screen:
		return victory_screen
	if not victory_screen_scene:
		return null
	victory_screen = victory_screen_scene.instantiate()
	victory_screen.layer = 5
	victory_screen.connect("back_button", Callable(self, "_on_victory_screen_back_button"))
	add_child(victory_screen)
	SoundManager.wire_up_all_buttons()
	return victory_screen

func _ensure_transmogrify_panel() -> CanvasLayer:
	if transmogrify_panel:
		return transmogrify_panel
	if not transmogrify_scene:
		return null
	transmogrify_panel = transmogrify_scene.instantiate()
	transmogrify_panel.layer = 5
	transmogrify_panel.connect("back_button_pressed", Callable(self, "_on_transmogrify_back_button_pressed"))
	add_child(transmogrify_panel)
	SoundManager.wire_up_all_buttons()
	return transmogrify_panel

func _open_prize_wheel(world_node: FW_WorldNode) -> void:
	GDM.current_prize_wheel_hash = world_node.world_hash
	# Save scroll position before leaving
	scroll()
	if GDM.player:
		GDM.vs_save()
	GDM.previous_scene_path = "res://WorldMap/world_map.tscn"
	ScreenRotator.change_scene("res://Wheel/Wheel.tscn")

func _on_scroll_save_timeout() -> void:
	# Save the player data to persist the scroll position
	if GDM.player:
		GDM.vs_save()

func _on_global_quest_event(_quest: FW_Quest) -> void:
	# Update all quest flags when any quest state changes globally
	update_all_quest_flags()

func _on_global_quest_goal_event(_quest: FW_Quest, _goal) -> void:
	# Update all quest flags when any quest goal is completed
	update_all_quest_flags()

func set_player_position_on_map() -> void:
	if GDM.current_info.level_to_generate and GDM.current_info.level_to_generate.has("level_name"):
		for wn in world_nodes:
			for node in wn.get_children():
				# Skip non-world child nodes
				if not node or not node.has_method("set_player_location"):
					continue
				if node.loaded and node.loaded.world_hash == GDM.current_info.level_to_generate["map_hash"]:
					node.set_player_location(true)
				else:
					node.set_player_location(false)

func _on_back_button_pressed() -> void:
	# Save scroll position before leaving
	scroll()
	GDM.vs_save()
	# Reset cooldowns when starting new adventure
	if GDM.game_manager:
		if GDM.game_manager.player_cooldown_manager:
			GDM.game_manager.player_cooldown_manager.reset_cooldowns()
		if GDM.game_manager.monster_cooldown_manager:
			GDM.game_manager.monster_cooldown_manager.reset_cooldowns()
	ScreenRotator.change_scene("res://Scenes/game_menu2.tscn")

func scroll() -> void:
	# Safely update player scroll position
	if GDM.player:
		GDM.player.world_map_scroll_position = $ScrollContainer.scroll_vertical
		# Use debounced saving to avoid excessive saves during scrolling
		if _scroll_save_timer:
			_scroll_save_timer.start()

func _on_world_save_scroll_value() -> void:
	scroll()

func _on_char_displayed(_idx):
	# you can use the idx parameter to check the index of the character displayed
	audio_player.play()

func toggle_completed() -> void:
	levels_completed = 0
	for wn in world_nodes:
		for node in wn.get_children():
			# Only process world node instances that implement quest/level helpers
			if not node or not node.has_method("_update_quest_flag"):
				continue
			# Safely reference loaded resource
			if node.loaded and node.loaded.world_hash and GDM.world_state.save.has(node.loaded.world_hash):
				if GDM.world_state.get_completed(node.loaded.world_hash):
					levels_completed += 1 # use this to key off the level unlocks
					GDM.world_state.update_completed(node.loaded.world_hash, true)
			# Update quest flags for all nodes
			if node.has_method("_update_quest_flag"):
				node._update_quest_flag()
			if node.has_method("_update_levels_completed_label"):
				node._update_levels_completed_label()

func process_quest_vars() -> void:
	# Generic quest variable processing using NPCQuestManager
	if current_npc_quest_manager:
		var quest_vars = current_npc_quest_manager.get_dialogue_variables()
		for key in quest_vars.keys():
			# Update the dialogue box variables with current quest state
			dialogue_box.variables[key] = quest_vars[key]
			dialogue_box.variables[key] = quest_vars[key]

func map_node_clicked(index: int, world_node: FW_WorldNode, menu_keys: Array):
	GDM.current_info.world = world_node
	var entry_key = menu_keys[index]

	if entry_key == "PRIZE_WHEEL":
		_open_prize_wheel(world_node)
		return

	# Log debug info for static nodes like SNOWMAN when clicked
	if OS.is_debug_build() and entry_key == "SNOWMAN":
		FW_Debug.debug_log(["[world_map] Menu entry clicked: SNOWMAN for world node:", world_node.name, "world_hash=", world_node.world_hash])

	# Now you can use entry_key to decide what to do
	if entry_key in MENU_DIALOG_ENTRIES.keys():
		process_quest_vars()
		if entry_key == "UNLOCK":
			dialogue_box.variables["unlock_cost"] = DoghouseManager.get_unlock_cost()
			dialogue_box.variables["money"] = GDM.player.gold
		dialogue_box.start(entry_key)

func create_menu_from_node(world_node: FW_WorldNode) -> void:
	if menu:
		menu.queue_free()
	menu = menu_prefab.instantiate()
	# Defensive: do not create a popup for static tutorial signpost nodes
	if world_node and world_node.type == FW_WorldNode.NODE_TYPE.TUTORIAL_SIGNPOST:
		# No menu entries for tutorial signpost
		return
	var menu_keys = []  # Add a property to store keys
	var index := 0

	# Get menu entries - use DoghouseManager for doghouse, otherwise use world_node entries
	var menu_entries: Array = []
	if world_node.type == FW_WorldNode.NODE_TYPE.DOG_HOUSE:
		menu_entries = DoghouseManager.get_menu_entries()
	else:
		menu_entries = world_node.menu_entries

	for entry in menu_entries:
		var entry_data := _normalize_menu_entry(entry)
		if entry_data == null:
			continue
		var key_name = entry_data.get_key()
		if key_name == null:
			continue
		var key = String(key_name)
		if key == "":
			continue
		var label = entry_data.get_label()
		var icon = entry_data.get_icon()
		menu.add_item(label, icon)
		var disabled = false

		# Check for level completion (existing logic) - skip for doghouse
		if world_node.type != FW_WorldNode.NODE_TYPE.DOG_HOUSE and world_node.type != FW_WorldNode.NODE_TYPE.PRIZE_WHEEL:
			if GDM.world_state.save.has(world_node.world_hash):
				if GDM.world_state.get_completed(world_node.world_hash) and (key.contains("MISSION") or key.contains("PVP")):
					disabled = true

		if world_node.type == FW_WorldNode.NODE_TYPE.PRIZE_WHEEL:
			if GDM.world_state.is_prize_wheel_collected(world_node.world_hash):
				disabled = true

		# Check for quest completion - skip for doghouse
		if world_node.type != FW_WorldNode.NODE_TYPE.DOG_HOUSE:
			if world_node.quest_registry and world_node.npc_id:
				var quests = world_node.quest_registry.get_quests_for_npc(world_node.npc_id)
				for quest in quests:
					if quest.dialogue_id == key:
						# Only disable if quest is already cashed in, not just completed
						if QuestManager.is_already_cashed_in(quest):
							disabled = true
						break

		if disabled:
			menu.set_item_disabled(index, true)
		menu_keys.append(key)
		index += 1
	menu.index_pressed.connect(map_node_clicked.bind(world_node, menu_keys))
	add_child(menu)

func _normalize_menu_entry(raw_entry) -> FW_MenuEntryData:
	if raw_entry is FW_MenuEntryData:
		return raw_entry
	if raw_entry is Dictionary:
		var entry := FW_MenuEntryData.new()
		entry.key = raw_entry.get("key", "")
		entry.label_override = raw_entry.get("label", "")
		if raw_entry.has("icon"):
			var icon_resource = raw_entry["icon"]
			if icon_resource is Texture2D and icon_resource.resource_path != "":
				entry.icon_path = icon_resource.resource_path
				entry._cached_icon_path = icon_resource.resource_path
				entry._cached_icon = icon_resource
		return entry
	return null

func _on_world_node_level_button_pressed(world_node: FW_WorldNode) -> void:
	last_mouse = get_viewport().get_mouse_position()

	# Set up quest manager for this NPC if available
	current_npc_quest_manager = null
	if world_node.npc_id != "" and world_node.quest_registry != null:
		current_npc_quest_manager = FW_NPCQuestManager.new()
		current_npc_quest_manager.npc_id = world_node.npc_id
		current_npc_quest_manager.quest_registry = world_node.quest_registry
		current_npc_quest_manager.quest_state_changed.connect(_on_quest_state_changed)
	elif world_node.npc_id != "" and main_quest_registry != null:
		# Fallback to main quest registry
		current_npc_quest_manager = FW_NPCQuestManager.new()
		current_npc_quest_manager.npc_id = world_node.npc_id
		current_npc_quest_manager.quest_registry = main_quest_registry
		current_npc_quest_manager.quest_state_changed.connect(_on_quest_state_changed)

	# Find previous node (the one with current_location visible)
	var prev_pos: Vector2 = Vector2.ZERO
	var new_pos: Vector2 = Vector2.ZERO
	for wn in world_nodes:
		for node in wn.get_children():
			# Skip non-world child nodes
			if not node or not node.has_method("set_player_location"):
				continue
			if node.loaded == world_node:
				new_pos = node.global_position
			if node.current_location.visible:
				previous_node = node.loaded
				prev_pos = node.global_position
			node.set_player_location(node.loaded == world_node)
	# Animate paw prints if previous node exists and is different
	if previous_node and previous_node != world_node:
		show_paw_print_path(prev_pos, new_pos, 6)
	previous_node = world_node
	create_menu_from_node(world_node)
	menu.popup(Rect2(last_mouse, Vector2.ZERO))

func _on_dialogue_box_signal(value: String) -> void:
	# Handle doghouse unlock first
	if value == "UNLOCK":
		if DoghouseManager.can_afford_unlock():
			DoghouseManager.unlock_doghouse()
			# Could show a success message here
			FW_Debug.debug_log(["Doghouse unlocked successfully!"])
			return
		else:
			# Failed to unlock - show not enough money dialogue
			FW_Debug.debug_log(["Failed to unlock doghouse - not enough gold"])
			return

	# Try to handle quest-related signals first
	if current_npc_quest_manager and current_npc_quest_manager.handle_dialogue_signal(value):
		# Signal was handled by quest system
		if value.ends_with("_completed"):
			# Show loot screen for completed quests
			var loot := _ensure_loot_screen()
			if loot:
				loot.slide_in()
				loot.setup()
		return

	# Handle non-quest dialogue signals
	var params = null

	# Get params from the current world node's embedded mission_params
	if GDM.current_info.world and GDM.current_info.world.mission_params.has("max_depth"):
		params = GDM.current_info.world.mission_params

	if value == 'small_shop':
		GDM.npc_to_load = preload("res://Characters/Vendor_DraighlaPenn.tres")
		ScreenRotator.change_scene("res://Shop/basic_shop.tscn")
	elif value == "transmogrify_shop":
		GDM.npc_to_load = preload("res://Characters/MagicShop_ElizabethFirerose.tres")
		var transmog := _ensure_transmogrify_panel()
		if transmog:
			transmog.slide_in()
	elif value == "doghouse":
		ScreenRotator.change_scene("res://Doghouse/Doghouse.tscn")
	elif value == "blacksmith":
		GDM.npc_to_load = preload("res://Characters/Blacksmith_MinnaSunderer.tres")
		ScreenRotator.change_scene("res://Shop/blacksmith.tscn")
	elif params:
		# All missions now use the same unified generation system
		# possible mission params
		GDM.current_info.level_to_generate = {
			"level_name": value,
			"map_hash": GDM.current_info.world.world_hash,
			"max_depth": params.max_depth,
			"boss": params.boss,
			"elite": params.elite,
			"end_type": params.end_type,
			"scrub_levels": params.scrub_levels,
			"grunt_levels": params.grunt_levels,
			"elite_levels": params.elite_levels,
			"boss_level": params.boss_level,
			"pvp_probability": params.get("pvp_probability", 0.1),  # Default 10% PvP, 100% for arenas
			"event_probability": params.get("event_probability", 0.3),  # Default 30% events, 0% for arenas
			"monster_subtype": params.get("monster_subtype", null)  # Add monster subtype for themed dungeons
		}
		ScreenRotator.change_scene("res://Scenes/level_select2.tscn")
	else:
		printerr("Shouldn't get here ERROR!! Signal value: ", value)

func get_used_slots() -> int:
	var total = 0
	for i in GDM.player.abilities:
		if i:
			total += 1
	return total

func _on_loot_screen_back_button() -> void:
	if transitioning:
		return
	var loot := _ensure_loot_screen()
	if not loot:
		return
	transitioning = true
	loot.slide_out()
	await loot.slide_out_finished
	transitioning = false

func _on_equipment_back_button() -> void:
	if transitioning:
		return
	var equipment := _ensure_equipment_screen()
	if not equipment:
		return
	transitioning = true
	equipment.slide_out()
	await equipment.slide_out_finished
	transitioning = false

func _on_inventory_screen_back_button() -> void:
	if transitioning:
		return
	var inventory := _ensure_inventory_screen()
	if not inventory:
		return
	transitioning = true
	inventory.slide_out()
	await inventory.slide_out_finished
	transitioning = false

func _on_inventory_button_pressed() -> void:
	if transitioning:
		return
	var inventory := _ensure_inventory_screen()
	if not inventory:
		return
	transitioning = true
	inventory.setup()
	inventory.slide_in()
	await inventory.slide_in_finished
	transitioning = false

func _on_equipment_button_pressed() -> void:
	if transitioning:
		return
	var equipment := _ensure_equipment_screen()
	if not equipment:
		return
	transitioning = true
	equipment.setup()
	equipment.slide_in()
	await equipment.slide_in_finished
	transitioning = false

func _on_quests_button_pressed() -> void:
	if transitioning:
		return
	var quests := _ensure_quest_viewer()
	if not quests:
		return
	transitioning = true
	quests.setup()
	quests.slide_in()
	await quests.slide_in_finished
	transitioning = false

func _on_quest_viewer_back_button() -> void:
	if transitioning:
		return
	var quests := _ensure_quest_viewer()
	if not quests:
		return
	transitioning = true
	quests.slide_out()
	await quests.slide_out_finished
	transitioning = false

func _on_skilltree_button_pressed() -> void:
	scroll()
	# Ensure scroll position is saved immediately before scene change
	if GDM.player:
		GDM.vs_save()
	GDM.previous_scene_path = "res://WorldMap/world_map.tscn"
	ScreenRotator.change_scene("res://Skills/skill_tree_bmp.tscn")

func _on_stat_screen_back_button() -> void:
	if transitioning: return
	transitioning = true
	$StatScreen.slide_out()
	await $StatScreen.slide_out_finished
	transitioning = false

func _on_help_panel_back_button() -> void:
	if transitioning:
		return
	var help := _ensure_help_panel()
	if not help:
		return
	transitioning = true
	help.slide_out()
	await help.slide_out_finished
	transitioning = false

func _on_tutorial_button_pressed() -> void:
	if transitioning:
		return
	var help := _ensure_help_panel()
	if not help:
		return
	transitioning = true
	help.slide_in()
	await help.slide_in_finished
	transitioning = false

func _on_mastery_button_pressed() -> void:
	if transitioning:
		return
	var tracker := _ensure_mastery_tracker()
	if not tracker:
		return
	transitioning = true
	tracker.slide_in()
	await tracker.slide_in_finished
	transitioning = false

func _on_mastery_tracker_back_button() -> void:
	if transitioning:
		return
	var tracker := _ensure_mastery_tracker()
	if not tracker:
		return
	transitioning = true
	tracker.slide_out()
	await tracker.slide_out_finished
	transitioning = false

func _on_bestiary_button_pressed() -> void:
	if transitioning:
		return
	var bestiary := _ensure_bestiary_panel()
	if not bestiary:
		return
	transitioning = true
	bestiary.slide_in()
	await bestiary.slide_in_finished
	transitioning = false

func _on_bestiary_panel_back_pressed() -> void:
	if transitioning:
		return
	var bestiary := _ensure_bestiary_panel()
	if not bestiary:
		return
	transitioning = true
	bestiary.slide_out()
	await bestiary.slide_out_finished
	transitioning = false

func _on_combined_stats_abilities_panel_back_button() -> void:
	if transitioning: return
	transitioning = true
	$CombinedStatsAbilitiesPanel.slide_out()
	await $CombinedStatsAbilitiesPanel.slide_out_finished
	$MenuPanel.update_button_alerts()
	back_button.disabled = false
	transitioning = false

func _show_combined_stats_if_needed() -> void:
	if not GDM or not GDM.pending_combined_stats_review:
		return
	if transitioning:
		call_deferred("_show_combined_stats_if_needed")
		return
	GDM.pending_combined_stats_review = false
	_on_combined_stats_button_pressed()

func _on_combined_stats_button_pressed() -> void:
	if transitioning: return
	transitioning = true
	back_button.disabled = true
	$CombinedStatsAbilitiesPanel.setup()
	$CombinedStatsAbilitiesPanel.load_abilities()
	$CombinedStatsAbilitiesPanel.slide_in()
	await $CombinedStatsAbilitiesPanel.slide_in_finished
	transitioning = false

func prepare_dialogue_character() -> void:
	var dialogue_data: FW_DialogueData = dialogue_box.data
	var char_list: FW_CharacterList = load(dialogue_data.characters)

	if GDM.player and GDM.player.character:
		char_list.characters[0] = GDM.player.character
		char_list.emit_changed()

func show_paw_print_path(from_pos: Vector2, to_pos: Vector2, steps: int = 5):
	var paw_prints = []
	for i in range(steps):
		var t = float(i) / (steps - 1)
		var pos = from_pos.lerp(to_pos, t)
		var paw = paw_print_scene.instantiate()
		paw.position = pos
		paw.modulate.a = 0.0 # Start invisible
		# Rotate paw to point in direction of movement (adjust for 180 degree offset)
		var direction = (to_pos - from_pos).normalized()
		paw.rotation = direction.angle() + PI / 2
		add_child(paw)
		paw_prints.append(paw)
		# Animate fade-in with a Tween
		var tween = create_tween()
		tween.tween_property(paw, "modulate:a", 1.0, 0.2).set_delay(i * 0.1)
		# Optionally fade out after a delay
		tween.tween_property(paw, "modulate:a", 0.0, 0.2).set_delay(steps * 0.1 + 0.5)
		# Optionally queue_free after fade out
		tween.tween_callback(Callable(paw, "queue_free"))

func _on_quest_state_changed(_quest: FW_Quest) -> void:
	# Handle quest state changes (e.g., show rewards, update UI)
	# Update quest flags for all nodes when quest state changes
	update_all_quest_flags()

func update_all_quest_flags() -> void:
	# Update quest flags on all world nodes
	for wn in world_nodes:
		for node in wn.get_children():
			if node.has_method("_update_quest_flag"):
				node._update_quest_flag()
			if node.has_method("_update_levels_completed_label"):
				node._update_levels_completed_label()

func _update_prize_wheel_visibility() -> void:
	# Iterate through all worlds and set prize wheel nodes visible only after a sibling node is fully completed
	for wn in world_nodes:
		if not wn:
			continue
		for node in wn.get_children():
			# Skip non-world child nodes
			if not node or not node.has_method("_update_quest_flag"):
				continue
			if node.loaded and node.loaded.type == FW_WorldNode.NODE_TYPE.PRIZE_WHEEL:
				var collected = GDM.world_state.is_prize_wheel_collected(node.loaded.world_hash)
				var world_has_completed_node = false
				for sibling in wn.get_children():
					# Skip non-world children
					if not sibling or not sibling.has_method("_update_quest_flag"):
						continue
					if not sibling.loaded:
						continue
					var sibling_type = sibling.loaded.type
					# Exclude prize wheel, static doghouse, and static snowman nodes from completion checks
					if sibling_type == FW_WorldNode.NODE_TYPE.PRIZE_WHEEL or sibling_type == FW_WorldNode.NODE_TYPE.DOG_HOUSE or sibling_type == FW_WorldNode.NODE_TYPE.SNOWMAN or sibling_type == FW_WorldNode.NODE_TYPE.TUTORIAL_SIGNPOST:
						continue
					# Require the world node to be fully completed (not just visited) before unlocking the wheel
					if GDM.world_state.get_completed(sibling.loaded.world_hash):
						world_has_completed_node = true
						break
				node.visible = world_has_completed_node and not collected
				if OS.is_debug_build():
					FW_Debug.debug_log(["[world_map] Prize wheel visibility check: world=", wn.name, "wheel_hash=", node.loaded.world_hash, "collected=", collected, "world_has_completed_node=", world_has_completed_node, "visible=", node.visible])

func _on_level_completed(_node: FW_LevelNode) -> void:
	# Refresh prize wheel visibility when a level completes (useful for runtime updates)
	if OS.is_debug_build():
		FW_Debug.debug_log(["[world_map] _on_level_completed received node=", _node, "map_hash=", _node.world_hash, "depth=", _node.level_depth])
	# Print summary of path history sizes for debugging
	if OS.is_debug_build():
		for wn in world_nodes:
			for sibling in wn.get_children():
				# Skip non-world child nodes
				if not sibling or not sibling.has_method("_update_quest_flag"):
					continue
				if not sibling.loaded:
					continue
				var history = GDM.world_state.get_path_history(sibling.loaded.world_hash)
				FW_Debug.debug_log(["[world_map] world=", wn.name, "node=", sibling.name, "hash=", sibling.loaded.world_hash, "path_history_count=", history.size(), "completed=", GDM.world_state.get_completed(sibling.loaded.world_hash)])
	_update_prize_wheel_visibility()

func _scroll_and_animate_world(world_node: Control) -> void:
	# Step 1: Scroll to the act separator above the world if available; act_nodes are guaranteed to exist
	var target_node: Control = world_node
	var idx := world_nodes.find(world_node)
	if idx > 0:
		target_node = act_nodes[idx - 1]

	var target_y = target_node.position.y

	var scroll_tween = create_tween()
	scroll_tween.set_trans(Tween.TRANS_CUBIC)
	scroll_tween.set_ease(Tween.EASE_IN_OUT)
	scroll_tween.tween_property($ScrollContainer, "scroll_vertical", target_y, 1).from_current()

	# Step 2: When scroll finishes, fire fade and particle effect
	scroll_tween.finished.connect(func():
		# Store original material
		var original_material = world_node.material

		# Create shader material for the unlock effect
		var mat = ShaderMaterial.new()
		mat.shader = trippy_shader
		world_node.material = mat
		mat.set_shader_parameter("fade_amount", 0.0)

		# Fire fade tween
		var fade_tween = create_tween()
		fade_tween.tween_property(mat, "shader_parameter/fade_amount", 1.0, 0.3)

		# Fireworks-style particles: spawn near the top of the ScrollContainer
		# horizontally aligned with the act separator (target_node)
		var viewport_rect = $ScrollContainer.get_global_rect()
		var target_global = target_node.get_global_rect()
		var center_x = target_global.position.x + target_global.size.x / 2
		# 80 px below the top of the viewport is a good default; tweak if needed
		var center = Vector2(center_x, viewport_rect.position.y + 80)
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		for i in range(5):
			await get_tree().create_timer(i * 0.15).timeout
			var particle_offset = Vector2(rng.randf_range(-120, 120), rng.randf_range(-45, 45))
			var particles = unlock_particles.instantiate()
			particles.global_position = center + particle_offset
			add_child(particles)
			move_child(particles, get_child_count() - 1)
		SoundManager._play_level_unlock_sound()  # Assuming similar function exists
		# Restore original material after animation
		await get_tree().create_timer(4.0).timeout
		world_node.material = original_material
	)
	# Clear the just_unlocked_act flag
	UnlockManager.clear_just_unlocked_act()

func _on_victory_screen_back_button() -> void:
	if transitioning:
		return
	var victory := _ensure_victory_screen()
	if not victory:
		return
	transitioning = true
	victory.slide_out()
	await victory.slide_out_finished
	transitioning = false

func _on_ascension_triggered(world_id: String) -> void:
	if not FW_AscensionHelper.is_final_world(world_id):
		return
	var victory := _ensure_victory_screen()
	if not victory:
		return
	var outcome := FW_AscensionHelper.handle_world_completion(world_id)
	if outcome.get("unlocked_next_act", false):
		var message := FW_AscensionHelper.build_act_unlock_message(outcome.get("next_act_label", ""))
		victory.set_act_unlock_message(message)
	else:
		victory.clear_act_unlock_message()
	victory.slide_in()

func _on_equipment_screen_opened() -> void:
	# Clear equipment notifications when equipment screen is opened
	if GDM.notification_manager:
		GDM.notification_manager.clear_notification(FW_NotificationManager.NOTIFICATION_TYPE.EQUIPMENT)

func _on_inventory_screen_opened() -> void:
	# Clear inventory notifications when inventory screen is opened
	if GDM.notification_manager:
		GDM.notification_manager.clear_notification(FW_NotificationManager.NOTIFICATION_TYPE.INVENTORY)
		GDM.notification_manager.clear_notification(FW_NotificationManager.NOTIFICATION_TYPE.CONSUMABLES)

func _on_transmogrify_back_button_pressed() -> void:
	var transmog := _ensure_transmogrify_panel()
	if not transmog:
		return
	transmog.slide_out()


func _on_button_pressed() -> void:
	ScreenRotator.change_scene("res://MemoryGame/MemoryGame.tscn")

func _on_slot_button_pressed() -> void:
	ScreenRotator.change_scene("res://SlotGame/SlotGame.tscn")

func _on_plinko_button_pressed() -> void:
	ScreenRotator.change_scene("res://Plinko/Plinko.tscn")


func _on_lights_off_dbutton_pressed() -> void:
	ScreenRotator.change_scene("res://LightsOff/LightsOff.tscn")


func _on_high_low_button_pressed() -> void:
	ScreenRotator.change_scene("res://HighLow/HighLow.tscn")


func _on_minesweep_button_pressed() -> void:
	ScreenRotator.change_scene("res://MineSweep/MineSweep.tscn")
