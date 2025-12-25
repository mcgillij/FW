extends CanvasLayer

@onready var level_up_button: Button = %level_up_button
@onready var level_backdrop_vs: MarginContainer = %level_backdrop_vs
@onready var zoom_container: Control = $ScrollContainer/ZoomContainer
@onready var scroll_container: ScrollContainer = $ScrollContainer

@onready var dice_viewport: SubViewport = %dice_viewport
@onready var viewport_display: TextureRect = %viewport_display
@onready var stats_holder: VBoxContainer = %StatsHolder
@onready var back_button: TextureButton = $back_button
@onready var level_name: Label = %level_name
@export var char_info_prefab: PackedScene
@export var loot_screen_scene: PackedScene = preload("res://LootManager/LootScreen.tscn")
@export var inventory_screen_scene: PackedScene = preload("res://Inventory/InventoryScreen.tscn")
@export var equipment_screen_scene: PackedScene = preload("res://Equipment/equipment.tscn")
@export var quest_viewer_scene: PackedScene = preload("res://Quest/QuestViewer.tscn")
@export var help_panel_scene: PackedScene = preload("res://Help/HelpTutorialGlossary.tscn")
@export var bestiary_panel_scene: PackedScene = preload("res://Scenes/bestiary_panel.tscn")
@export var mastery_tracker_scene: PackedScene = preload("res://MasteryTracker/MasteryTracker.tscn")

const DEFAULT_ZOOM := Vector2(1, 1)
const INCREASE_ZOOM_TEN_PERCENT := 1.1
const DECREASE_ZOOM_TEN_PERCENT := 0.9
const MIN_ZOOM_LEVEL := 0.6561  # About 4 zoom-out clicks (0.9^4)
const MAX_ZOOM_LEVEL := 1.4641  # About 4 zoom-in clicks (1.1^4)
var zoom_level := Vector2(1, 1)
var dice_results := {}
var loot_screen: CanvasLayer = null
var inventory_screen: CanvasLayer = null
var equipment_screen: CanvasLayer = null
var quest_viewer: CanvasLayer = null
var help_panel: CanvasLayer = null
var bestiary_panel: CanvasLayer = null
var mastery_tracker: CanvasLayer = null

# Touch input variables for pinch-to-zoom
var touches := {}
var last_pinch_distance: float = 0.0
var is_pinching: bool = false

func _ready() -> void:
	GDM.safe_steam_set_rich_presence("#level_select")
	viewport_display.texture = dice_viewport.get_texture()
	dice_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	SoundManager.wire_up_all_buttons()
	zoom_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var content_width = $ScrollContainer.get_h_scroll_bar().max_value
	var block = FW_Block.new()
	var x_pos = block.panel_dimensions.x + 50
	var y_pos = block.panel_dimensions.y
	var center = content_width/2
	var v_scroll = y_pos * GDM.world_state.get_current_level(GDM.current_info.world.world_hash)

	# Don't apply zoom adjustments here - let the system initialize normally first
	$ScrollContainer.scroll_horizontal = int(center - x_pos)
	$ScrollContainer.set_deferred("scroll_vertical", v_scroll)
	toggle_level_up_button()
	_connect_dice_signals()
	EventBus.hide_dice.connect(hide_dice_viewport)
	EventBus.show_dice.connect(show_dice_viewport)
	var char_info = char_info_prefab.instantiate()
	stats_holder.add_child(char_info)
	char_info.setup()
	level_name.text = GDM.current_info.level_to_generate["level_name"].capitalize()

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

	# Connect popup coordinator to EventBus signals
	var popup_coordinator = $LevelSelectPopupCoordinator
	EventBus.show_monster.connect(popup_coordinator._on_show_monster_popup)
	EventBus.show_player_combatant.connect(popup_coordinator._on_show_player_popup)
	EventBus.environment_inspect.connect(popup_coordinator._on_show_environment_popup)

	# Apply saved zoom level after everything is set up and trigger auto-scroll
	call_deferred("_delayed_zoom_application")

func _unhandled_input(event: InputEvent) -> void:
	"""Handle touch input for pinch-to-zoom and mouse wheel zoom"""
	# Touch input handling for mobile devices
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
			if touches.size() < 2:
				last_pinch_distance = 0.0
				is_pinching = false

	elif event is InputEventScreenDrag:
		if event.index in touches:
			touches[event.index] = event.position

		# Handle pinch gesture with two touches
		if touches.size() == 2:
			var touch_positions = touches.values()
			var current_distance = touch_positions[0].distance_to(touch_positions[1])

			if last_pinch_distance > 0.0:
				var zoom_factor = current_distance / last_pinch_distance
				# Only apply zoom if the change is significant enough to avoid jitter
				if abs(zoom_factor - 1.0) > 0.01:
					var pinch_center = (touch_positions[0] + touch_positions[1]) * 0.5
					_apply_pinch_zoom(zoom_factor, pinch_center)

			last_pinch_distance = current_distance
			is_pinching = true
		elif touches.size() == 1 and not is_pinching:
			# Allow single-touch scrolling when not pinching
			pass

	# Mouse wheel zoom for desktop (preserve existing functionality)
	#elif event is InputEventMouseButton and not is_pinching:
		#if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			#_apply_mouse_wheel_zoom(INCREASE_ZOOM_TEN_PERCENT, event.position)
		#elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			#_apply_mouse_wheel_zoom(DECREASE_ZOOM_TEN_PERCENT, event.position)

	# Trackpad pinch gesture for desktop
	elif event is InputEventMagnifyGesture and not is_pinching:
		_apply_mouse_wheel_zoom(event.factor, event.position)

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

func toggle_level_up_button() -> void:
	if GDM.player.levelup:
		level_up_button.visible = true
	else:
		level_up_button.visible = false

func _on_back_button_pressed() -> void:
	GDM.vs_save()
	ScreenRotator.change_scene("res://WorldMap/world_map.tscn")

func scroll() -> void:
	"""Save scroll position"""
	GDM.level_scroll_value = $ScrollContainer.scroll_vertical

func _on_level_backdrop_vs_save_scroll_value() -> void:
	scroll()

# Function to zoom in
func _on_zoom_in_pressed() -> void:
	# Use center of viewport for button zoom
	var viewport_center = scroll_container.get_viewport_rect().size / 2.0
	_apply_mouse_wheel_zoom(INCREASE_ZOOM_TEN_PERCENT, viewport_center)

# Function to zoom out
func _on_zoom_out_pressed() -> void:
	# Use center of viewport for button zoom
	var viewport_center = scroll_container.get_viewport_rect().size / 2.0
	_apply_mouse_wheel_zoom(DECREASE_ZOOM_TEN_PERCENT, viewport_center)

# Function to reset the zoom to its original scale
func _on_reset_zoom_pressed() -> void:
	# Store the viewport center before resetting
	var viewport_center = scroll_container.get_viewport_rect().size / 2.0
	var old_scroll = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	var content_point = (old_scroll + viewport_center) / zoom_level

	# Reset zoom level
	zoom_level = DEFAULT_ZOOM
	level_backdrop_vs.scale = zoom_level
	var content_size = level_backdrop_vs.get_content_size()
	zoom_container.custom_minimum_size = content_size * zoom_level

	# Maintain center position during reset
	var new_scroll = (content_point * zoom_level) - viewport_center
	scroll_container.scroll_horizontal = new_scroll.x
	scroll_container.scroll_vertical = new_scroll.y

	# Update UI
	zoom_container.update_minimum_size()
	level_backdrop_vs.update_zoom_level(zoom_level)
	_save_zoom_to_config()

# Clamp zoom level to prevent extreme values
func _clamp_zoom_level() -> void:
	zoom_level.x = clamp(zoom_level.x, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	zoom_level.y = clamp(zoom_level.y, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)

# Save zoom level to config
func _save_zoom_to_config() -> void:
	ConfigManager.level_select_zoom = zoom_level
	ConfigManager.save_config()

# Load zoom level from config and apply it (called deferred)
func _load_and_apply_zoom() -> void:
	zoom_level = ConfigManager.level_select_zoom
	_clamp_zoom_level()
	_apply_zoom()

# Delayed zoom application to wait for level regeneration
func _delayed_zoom_application() -> void:
	# Wait a few frames for level regeneration to complete
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# CRITICAL FIX: Only load zoom from config if we don't have a current zoom level
	# This prevents resetting zoom when returning from failed events
	if zoom_level == DEFAULT_ZOOM:
		_load_and_apply_zoom()
	else:
		# We already have a zoom level, just apply it
		_clamp_zoom_level()
		_apply_zoom()

	# After zoom is applied, trigger a proper auto-scroll to current position
	if level_backdrop_vs and level_backdrop_vs.has_method("trigger_auto_scroll"):
		level_backdrop_vs.trigger_auto_scroll()

	call_deferred("_show_combined_stats_if_needed")

# Apply the zoom level to the actual node
func _apply_zoom() -> void:
	if not (level_backdrop_vs and zoom_container and scroll_container):
		printerr("Cannot apply zoom: required nodes are null")
		return

	# 1. Get properties before zoom
	var old_zoom = level_backdrop_vs.scale
	var old_scroll = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	var viewport_center = scroll_container.get_viewport_rect().size / 2.0

	# 2. Find the point in the content that is at the center of the viewport
	var point_in_content = (old_scroll + viewport_center) / old_zoom

	# 3. Apply the new zoom
	level_backdrop_vs.scale = zoom_level
	var content_size = level_backdrop_vs.get_content_size()
	zoom_container.custom_minimum_size = content_size * zoom_level

	# 4. Calculate the new scroll position to keep the point centered
	var new_scroll = (point_in_content * zoom_level) - viewport_center

	# 5. Set the new scroll position
	scroll_container.scroll_horizontal = new_scroll.x
	scroll_container.scroll_vertical = new_scroll.y

	# 6. Update other parts
	zoom_container.update_minimum_size()
	level_backdrop_vs.update_zoom_level(zoom_level)

func _apply_pinch_zoom(zoom_factor: float, pinch_center: Vector2) -> void:
	"""Apply zoom from pinch gesture, maintaining zoom around the pinch center"""
	if not (level_backdrop_vs and zoom_container and scroll_container):
		return

	# Calculate new zoom level
	var new_zoom = zoom_level * zoom_factor
	new_zoom.x = clamp(new_zoom.x, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	new_zoom.y = clamp(new_zoom.y, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)

	# Only apply if zoom actually changed
	if new_zoom.is_equal_approx(zoom_level):
		return

	# Get current scroll position and convert pinch center to content space
	var old_scroll = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	var content_point = (old_scroll + pinch_center) / zoom_level

	# Apply new zoom
	zoom_level = new_zoom
	level_backdrop_vs.scale = zoom_level
	var content_size = level_backdrop_vs.get_content_size()
	zoom_container.custom_minimum_size = content_size * zoom_level

	# Calculate new scroll position to keep the pinch center stable
	var new_scroll = (content_point * zoom_level) - pinch_center
	scroll_container.scroll_horizontal = new_scroll.x
	scroll_container.scroll_vertical = new_scroll.y

	# Update UI
	zoom_container.update_minimum_size()
	level_backdrop_vs.update_zoom_level(zoom_level)
	_save_zoom_to_config()

func _apply_mouse_wheel_zoom(zoom_factor: float, mouse_position: Vector2) -> void:
	"""Apply zoom from mouse wheel, maintaining zoom around the mouse position"""
	if not (level_backdrop_vs and zoom_container and scroll_container):
		return

	# Calculate new zoom level
	var new_zoom = zoom_level * zoom_factor
	new_zoom.x = clamp(new_zoom.x, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	new_zoom.y = clamp(new_zoom.y, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)

	# Only apply if zoom actually changed
	if new_zoom.is_equal_approx(zoom_level):
		return

	# Get current scroll position and convert mouse position to content space
	var old_scroll = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	var content_point = (old_scroll + mouse_position) / zoom_level

	# Apply new zoom
	zoom_level = new_zoom
	level_backdrop_vs.scale = zoom_level
	var content_size = level_backdrop_vs.get_content_size()
	zoom_container.custom_minimum_size = content_size * zoom_level

	# Calculate new scroll position to keep the mouse position stable
	var new_scroll = (content_point * zoom_level) - mouse_position
	scroll_container.scroll_horizontal = new_scroll.x
	scroll_container.scroll_vertical = new_scroll.y

	# Update UI
	zoom_container.update_minimum_size()
	level_backdrop_vs.update_zoom_level(zoom_level)
	_save_zoom_to_config()

func _on_level_up_button_pressed() -> void:
	GDM.previous_scene_path = "res://Scenes/level_select2.tscn"
	ScreenRotator.change_scene("res://Skills/skill_tree_bmp.tscn")

func _on_loot_screen_back_button() -> void:
	if not loot_screen:
		return
	loot_screen.slide_out()

func _connect_dice_signals():
	"""Connect to dice roll events"""
	dice_results.clear()
	var dice_nodes = []
	_find_dice_nodes(dice_viewport, dice_nodes)
	for die in dice_nodes:
		die.connect("roll_finished", Callable(self, "_on_die_roll_finished"))

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

func _find_dice_nodes(node: Node, dice_nodes: Array) -> void:
	if node.has_method("trigger_roll") and node.has_signal("roll_finished"):
		dice_nodes.append(node)
	for child in node.get_children():
		_find_dice_nodes(child, dice_nodes)

func _on_die_roll_finished(value: int, die_type, roll_for: String):
	"""Handle dice roll completion"""
	dice_results[die_type] = value
	if dice_results.size() == 2:
		var result = FW_Utils._combine_percentile_dice(dice_results.get(1, 0), dice_results.get(0, 0))
		EventBus.dice_roll_result.emit(result)
		EventBus.dice_roll_result_for.emit(result, roll_for)
		# Keep dice visible briefly after roll
		await get_tree().create_timer(2.0).timeout
		EventBus.hide_dice.emit()

func get_used_slots() -> int:
	var total = 0
	for i in GDM.player.abilities:
		if i:
			total += 1
	return total

func _on_equipment_back_button() -> void:
	if not equipment_screen:
		return
	equipment_screen.slide_out()

func _on_inventory_screen_back_button() -> void:
	if not inventory_screen:
		return
	inventory_screen.slide_out()

func _on_inventory_button_pressed() -> void:
	var inventory := _ensure_inventory_screen()
	if not inventory:
		return
	inventory.setup()
	inventory.slide_in()

func _on_equipment_button_pressed() -> void:
	var equipment := _ensure_equipment_screen()
	if not equipment:
		return
	equipment.setup()
	equipment.slide_in()

func _on_quests_button_pressed() -> void:
	var quests := _ensure_quest_viewer()
	if not quests:
		return
	quests.setup()
	quests.slide_in()

func _on_quest_viewer_back_button() -> void:
	if not quest_viewer:
		return
	quest_viewer.slide_out()

func _on_skilltree_button_pressed() -> void:
	GDM.previous_scene_path = "res://Scenes/level_select2.tscn"
	ScreenRotator.change_scene("res://Skills/skill_tree_bmp.tscn")

func _on_stat_screen_back_button() -> void:
	$StatScreen.slide_out()

func _on_help_panel_back_button() -> void:
	if not help_panel:
		return
	help_panel.slide_out()

func _on_tutorial_button_pressed() -> void:
	var help := _ensure_help_panel()
	if not help:
		return
	help.slide_in()

func _on_mastery_button_pressed() -> void:
	var tracker := _ensure_mastery_tracker()
	if not tracker:
		return
	tracker.slide_in()

func _on_bestiary_button_pressed() -> void:
	var bestiary := _ensure_bestiary_panel()
	if not bestiary:
		return
	bestiary.slide_in()

func _on_bestiary_panel_back_pressed() -> void:
	if not bestiary_panel:
		return
	bestiary_panel.slide_out()

func _on_mastery_tracker_back_button() -> void:
	if not mastery_tracker:
		return
	mastery_tracker.slide_out()


func _show_combined_stats_if_needed() -> void:
	if not GDM:
		return
	if not GDM.pending_combined_stats_review:
		return
	GDM.pending_combined_stats_review = false
	_on_combined_stats_button_pressed()


func _on_combined_stats_abilities_panel_back_button() -> void:
	$CombinedStatsAbilitiesPanel.slide_out()
	$MenuPanel.update_button_alerts()
	back_button.disabled = false

func _on_combined_stats_button_pressed() -> void:
	back_button.disabled = true
	$CombinedStatsAbilitiesPanel.setup()
	$CombinedStatsAbilitiesPanel.load_abilities()
	$CombinedStatsAbilitiesPanel.slide_in()

func _on_equipment_screen_opened() -> void:
	# Clear equipment notifications when equipment screen is opened
	if GDM.notification_manager:
		var NotificationManagerScript = load("res://Scripts/FW_NotificationManager.gd")
		GDM.notification_manager.clear_notification(NotificationManagerScript.NOTIFICATION_TYPE.EQUIPMENT)

func _on_inventory_screen_opened() -> void:
	# Clear inventory notifications when inventory screen is opened
	if GDM.notification_manager:
		var NotificationManagerScript = load("res://Scripts/FW_NotificationManager.gd")
		GDM.notification_manager.clear_notification(NotificationManagerScript.NOTIFICATION_TYPE.INVENTORY)
		GDM.notification_manager.clear_notification(NotificationManagerScript.NOTIFICATION_TYPE.CONSUMABLES)
