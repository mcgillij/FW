extends "res://Scripts/base_menu_panel.gd"

# Default settings for the MarginContainer2 view in layout/transform
# x 700
# y 1172
# pos x 10
# pos y 9


signal back_button
@onready var actual_margin_container: MarginContainer = %ActualMarginContainer

@onready var x_label: Label = %x_label
@onready var y_label: Label = %y_label
@onready var input_handler: Node = %InputHandler

@export var parallax_bg: PackedScene

const DEFAULT_ZOOM := Vector2(.5, .5)
const INCREASE_ZOOM_TEN_PERCENT := 1.1
const DECREASE_ZOOM_TEN_PERCENT := 0.9
# Zoom limits (approximately 4 clicks in each direction from default)
const MIN_ZOOM_LEVEL := 0.328  # 0.5 * (0.9^4) ≈ 0.328
const MAX_ZOOM_LEVEL := 0.732  # 0.5 * (1.1^4) ≈ 0.732
var zoom_level := Vector2(.5, .5)
var zoom_save_timer: Timer = null  # Debounce config saves

# Touch input variables for pinch-to-zoom
var touches := {}
var last_pinch_distance: float = 0.0
var is_pinching: bool = false
var _initial_skill_snapshot: Dictionary = {}

func _ready() -> void:
	GDM.safe_steam_set_rich_presence("#skill_tree")
	var bg = parallax_bg.instantiate()
	add_child(bg)
	SoundManager.wire_up_all_buttons()
	setup()  # Removed duplicate call

	# Create debounce timer for zoom config saves to reduce I/O on mobile
	zoom_save_timer = Timer.new()
	zoom_save_timer.wait_time = 0.5  # Save after 0.5s of no zoom changes
	zoom_save_timer.one_shot = true
	zoom_save_timer.timeout.connect(_save_zoom_to_config)
	add_child(zoom_save_timer)

	# Connect scroll signals to preserve zoom (find the ScrollContainer)
	var scroll_container = %MarginContainer2
	if scroll_container and scroll_container is ScrollContainer:
		var h_scroll = scroll_container.get_h_scroll_bar()
		var v_scroll = scroll_container.get_v_scroll_bar()
		if h_scroll:
			h_scroll.value_changed.connect(_on_scroll_changed)
		if v_scroll:
			v_scroll.value_changed.connect(_on_scroll_changed)

	# Load saved zoom level from config and apply it (delayed to ensure scene setup completes)
	call_deferred("_delayed_zoom_application")
	call_deferred("_capture_initial_skill_snapshot")

	slide_in()

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
					# Mark event as handled to prevent interference with skill tree node interactions
					get_viewport().set_input_as_handled()

			last_pinch_distance = current_distance
			is_pinching = true
		elif touches.size() == 1 and not is_pinching:
			# Allow single-touch scrolling when not pinching
			pass

	# Mouse wheel zoom for desktop (preserve existing functionality)
	#elif event is InputEventMouseButton and not is_pinching:
		#if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			#_apply_mouse_wheel_zoom(INCREASE_ZOOM_TEN_PERCENT, event.position)
			#get_viewport().set_input_as_handled()
		#elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			#_apply_mouse_wheel_zoom(DECREASE_ZOOM_TEN_PERCENT, event.position)
			#get_viewport().set_input_as_handled()

	# Trackpad pinch gesture for desktop
	elif event is InputEventMagnifyGesture and not is_pinching:
		_apply_mouse_wheel_zoom(event.factor, event.position)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	# Properly disconnect signals to prevent memory leaks
	var scroll_container = %MarginContainer2
	if scroll_container and is_instance_valid(scroll_container) and scroll_container is ScrollContainer:
		var h_scroll = scroll_container.get_h_scroll_bar()
		var v_scroll = scroll_container.get_v_scroll_bar()
		if h_scroll and h_scroll.value_changed.is_connected(_on_scroll_changed):
			h_scroll.value_changed.disconnect(_on_scroll_changed)
		if v_scroll and v_scroll.value_changed.is_connected(_on_scroll_changed):
			v_scroll.value_changed.disconnect(_on_scroll_changed)

func setup() -> void:
	# CRITICAL: Set stats_from_tree BEFORE loading saved data
	# because load_saved_data() needs it to calculate max_unlock_cost correctly
	input_handler.stats_from_tree = GDM.player.skill_tree
	_load_player_data()
	# If no saved data was loaded, still need to initialize max_unlock_cost
	if GDM.player.skill_tree_values == "":
		input_handler.skilltree.max_unlock_cost = GDM.player.skill_points - input_handler.sum_values(input_handler.stats_from_tree, input_handler.abilities_from_tree)
		input_handler._skillpoints_changed()

func _load_player_data() -> void:
	if GDM.player.skill_tree_values != "":
		input_handler.load_saved_data(GDM.player.skill_tree_values)
		GDM.player.skill_tree = input_handler.stats_from_tree

#func _process(_delta: float) -> void:
#	actual_margin_container.scale = zoom_level


# Function to zoom in
func _on_zoom_in_pressed() -> void:
	# Use center of viewport for button zoom
	var scroll_container = %MarginContainer2
	if scroll_container and scroll_container is ScrollContainer:
		var viewport_center = scroll_container.size / 2.0
		_apply_mouse_wheel_zoom(INCREASE_ZOOM_TEN_PERCENT, viewport_center)

# Function to zoom out
func _on_zoom_out_pressed() -> void:
	# Use center of viewport for button zoom
	var scroll_container = %MarginContainer2
	if scroll_container and scroll_container is ScrollContainer:
		var viewport_center = scroll_container.size / 2.0
		_apply_mouse_wheel_zoom(DECREASE_ZOOM_TEN_PERCENT, viewport_center)

# Function to reset the zoom to its original scale
func _on_reset_zoom_pressed() -> void:
	var scroll_container = %MarginContainer2
	if scroll_container and scroll_container is ScrollContainer:
		# Store the viewport center before resetting
		var viewport_center = scroll_container.size / 2.0
		var old_scroll = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
		var content_point = (old_scroll + viewport_center) / zoom_level.x

		# Reset zoom level
		zoom_level = DEFAULT_ZOOM
		actual_margin_container.scale = zoom_level

		# Maintain center position during reset
		var new_scroll = (content_point * zoom_level.x) - viewport_center
		scroll_container.scroll_horizontal = new_scroll.x
		scroll_container.scroll_vertical = new_scroll.y

		# Save zoom level
		_debounce_zoom_save()

# Debounce zoom saves to reduce I/O operations (important for mobile)
func _debounce_zoom_save() -> void:
	if zoom_save_timer and is_instance_valid(zoom_save_timer):
		zoom_save_timer.start()

# Save zoom level to config (called after debounce timer)
func _save_zoom_to_config() -> void:
	if not ConfigManager:
		return
	ConfigManager.skill_tree_zoom = zoom_level
	ConfigManager.save_config()

# Load zoom level from config and apply it (called deferred)
func _load_and_apply_zoom() -> void:
	if ConfigManager:
		zoom_level = ConfigManager.skill_tree_zoom
	# Clamp zoom level inline
	var zoom_magnitude = zoom_level.x
	zoom_magnitude = clamp(zoom_magnitude, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	zoom_level = Vector2(zoom_magnitude, zoom_magnitude)
	_apply_zoom()

# Delayed zoom application to wait for scene setup to complete
func _delayed_zoom_application() -> void:
	# Wait a few frames for scene setup to complete
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_load_and_apply_zoom()
	_center_on_initial_node()

# Apply the zoom level to the actual node
func _apply_zoom() -> void:
	if actual_margin_container:
		actual_margin_container.scale = zoom_level

func _apply_pinch_zoom(zoom_factor: float, pinch_center: Vector2) -> void:
	"""Apply zoom from pinch gesture, maintaining zoom around the pinch center"""
	var scroll_container = %MarginContainer2
	if not (actual_margin_container and scroll_container and scroll_container is ScrollContainer):
		return

	# Calculate new zoom level
	var new_zoom = zoom_level * zoom_factor
	var zoom_magnitude = new_zoom.x
	zoom_magnitude = clamp(zoom_magnitude, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	new_zoom = Vector2(zoom_magnitude, zoom_magnitude)

	# Only apply if zoom actually changed
	if new_zoom.is_equal_approx(zoom_level):
		return

	# Get current scroll position and convert pinch center to content space
	var old_scroll = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	var content_point = (old_scroll + pinch_center) / zoom_level.x

	# Apply new zoom
	zoom_level = new_zoom
	actual_margin_container.scale = zoom_level

	# Calculate new scroll position to keep the pinch center stable
	var new_scroll = (content_point * zoom_level.x) - pinch_center
	scroll_container.scroll_horizontal = new_scroll.x
	scroll_container.scroll_vertical = new_scroll.y

	# Save zoom level
	_debounce_zoom_save()

func _apply_mouse_wheel_zoom(zoom_factor: float, mouse_position: Vector2) -> void:
	"""Apply zoom from mouse wheel, maintaining zoom around the mouse position"""
	var scroll_container = %MarginContainer2
	if not (actual_margin_container and scroll_container and scroll_container is ScrollContainer):
		return

	# Calculate new zoom level
	var new_zoom = zoom_level * zoom_factor
	var zoom_magnitude = new_zoom.x
	zoom_magnitude = clamp(zoom_magnitude, MIN_ZOOM_LEVEL, MAX_ZOOM_LEVEL)
	new_zoom = Vector2(zoom_magnitude, zoom_magnitude)

	# Only apply if zoom actually changed
	if new_zoom.is_equal_approx(zoom_level):
		return

	# Get current scroll position and convert mouse position to content space
	var old_scroll = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	var content_point = (old_scroll + mouse_position) / zoom_level.x

	# Apply new zoom
	zoom_level = new_zoom
	actual_margin_container.scale = zoom_level

	# Calculate new scroll position to keep the mouse position stable
	var new_scroll = (content_point * zoom_level.x) - mouse_position
	scroll_container.scroll_horizontal = new_scroll.x
	scroll_container.scroll_vertical = new_scroll.y

	# Save zoom level
	_debounce_zoom_save()

# Handle scroll bar changes to preserve zoom
func _on_scroll_changed(_value: float) -> void:
	# Preserve zoom during scrolling (but don't save to config)
	if actual_margin_container and is_instance_valid(actual_margin_container):
		zoom_level = actual_margin_container.scale
	call_deferred("_apply_zoom")

# Center the scroll container on the initial/starting node
# This function calculates the scroll position needed to center the viewport
# on the starting node (node 0) of the skill tree, accounting for zoom level
func _center_on_initial_node() -> void:
	var scroll_container = %MarginContainer2
	if not scroll_container or not scroll_container is ScrollContainer:
		FW_Debug.debug_log(["ScrollContainer not found or invalid"])
		return

	var worldmap_graph = %WorldmapGraph
	if not worldmap_graph or not is_instance_valid(worldmap_graph):
		FW_Debug.debug_log(["WorldmapGraph not found or invalid"])
		return

	# Get the initial node position (node 0 is the starting node)
	var initial_node_position = worldmap_graph.get_node_position(0)

	# Account for WorldmapGraph's position offset
	initial_node_position += worldmap_graph.position

	# Account for zoom level and the ActualMarginContainer's scaling
	var scaled_position = initial_node_position * zoom_level.x

	# Account for margins from ActualMarginContainer
	var margin_offset = Vector2(16, 16)  # From the theme override constants
	scaled_position += margin_offset * zoom_level.x

	# Get scroll container size
	var scroll_size = scroll_container.size

	# Calculate center offset (half of visible area)
	var center_offset = scroll_size * 0.5

	# Calculate desired scroll position to center the node
	var target_h_scroll = scaled_position.x - center_offset.x
	var target_v_scroll = scaled_position.y - center_offset.y

	# Clamp to valid scroll ranges and ensure we don't go negative
	target_h_scroll = max(0, target_h_scroll)
	target_v_scroll = max(0, target_v_scroll)

	# Set the scroll position
	scroll_container.scroll_horizontal = int(target_h_scroll)
	scroll_container.scroll_vertical = int(target_v_scroll)

func _save_player_data() -> void:
	if not GDM or not GDM.player or not input_handler:
		printerr("Cannot save player data - missing dependencies")
		return

	# Update unlocked abilities by combining skill tree abilities with existing default abilities
	_update_unlocked_abilities_properly()
	GDM.player.stats.set_stats_from_skilltree(input_handler.stats_from_tree)
	GDM.player.skill_tree_values = input_handler.get_save_data()
	GDM.player.skill_tree = input_handler.stats_from_tree

	# Validate and clean up ability assignments
	_validate_and_clean_ability_assignments()

func _update_unlocked_abilities_properly() -> void:
	"""
	Properly updates unlocked_abilities by combining:
	1. Default abilities (always available, never removed)
	2. Skill tree abilities (from abilities_from_tree)
	"""
	if not GDM or not GDM.player:
		return

	# Get current default abilities for the character
	var default_abilities = _get_default_abilities_for_current_character()

	# Start with default abilities
	var updated_unlocked_abilities: Array[FW_Ability] = []
	for default_ability in default_abilities:
		if default_ability:
			updated_unlocked_abilities.append(default_ability)

	# Add skill tree abilities (avoiding duplicates)
	for skill_ability in input_handler.abilities_from_tree:
		if skill_ability:
			# Check if this ability is already in the list (avoid duplicating defaults)
			var already_present = false
			for existing_ability in updated_unlocked_abilities:
				if existing_ability and existing_ability.name == skill_ability.name:
					already_present = true
					break

			if not already_present:
				updated_unlocked_abilities.append(skill_ability)

	# Update the player's unlocked abilities
	GDM.player.unlocked_abilities = updated_unlocked_abilities

func _validate_and_clean_ability_assignments() -> void:
	"""
	Validates that all assigned abilities in the action bar are still unlocked.
	Removes any abilities that are no longer available from the skill tree.
	"""
	if not GDM or not GDM.player or not input_handler:
		return

	var available_abilities = input_handler.abilities_from_tree
	var abilities_changed = false
	var character_default_abilities = _get_default_abilities_for_current_character()

	# Check each assigned ability slot
	for i in range(GDM.player.abilities.size()):
		var assigned_ability = GDM.player.abilities[i]
		if assigned_ability != null:
			# An ability is valid if it's either:
			# 1. From the skill tree (in available_abilities), OR
			# 2. A default ability for this character
			var is_valid = false

			# Check if it's from the skill tree
			for available_ability in available_abilities:
				if available_ability != null and assigned_ability != null:
					if available_ability.name == assigned_ability.name:
						is_valid = true
						break

			# If not from skill tree, check if it's a default ability
			if not is_valid:
				for default_ability in character_default_abilities:
					if default_ability and assigned_ability and default_ability.name == assigned_ability.name:
						is_valid = true
						break

			# Remove invalid abilities (not from skill tree and not default)
			if not is_valid:
				FW_Debug.debug_log(["Removing invalid ability from slot ", i, ": ", assigned_ability.name])
				GDM.player.abilities[i] = null
				abilities_changed = true

	# Update UI if abilities changed
	if abilities_changed:
		# Emit signal to notify other systems
		EventBus.calculate_job.emit()

func _get_default_abilities_for_current_character() -> Array[FW_Ability]:
	"""Get the default abilities for the current character based on their affinities"""
	var default_abilities: Array[FW_Ability] = []

	if not GDM.player.character:
		return default_abilities

	# Map affinities to their default ability paths (same as in FW_Player.gd)
	var affinity_to_default_ability = {
		FW_Ability.ABILITY_TYPES.Bark: "res://Abilities/Resources/default_red_attack.tres",
		FW_Ability.ABILITY_TYPES.Reflex: "res://Abilities/Resources/default_green_attack.tres",
		FW_Ability.ABILITY_TYPES.Alertness: "res://Abilities/Resources/default_blue_attack.tres",
		FW_Ability.ABILITY_TYPES.Vigor: "res://Abilities/Resources/default_orange_attack.tres",
		FW_Ability.ABILITY_TYPES.Enthusiasm: "res://Abilities/Resources/default_pink_attack.tres"
	}

	# Get default abilities for this character's affinities
	for affinity in GDM.player.character.affinities:
		if affinity_to_default_ability.has(affinity):
			var ability_path = affinity_to_default_ability[affinity]
			var ability = load(ability_path) as FW_Ability
			if ability:
				default_abilities.append(ability)

	return default_abilities

# Public function to manually center on the initial node
func center_on_starting_node() -> void:
	_center_on_initial_node()

# Snapshot helpers for combined stats auto-open
func _capture_initial_skill_snapshot() -> void:
	await get_tree().process_frame
	var snapshot = _capture_current_skill_snapshot()
	if snapshot.is_empty():
		await get_tree().process_frame
		snapshot = _capture_current_skill_snapshot()
	if snapshot.is_empty():
		return
	_initial_skill_snapshot = snapshot.duplicate(true)

func _capture_current_skill_snapshot() -> Dictionary:
	if not GDM or not GDM.player or not input_handler:
		return {}
	var snapshot: Dictionary = {}
	if input_handler.has_method("get_save_data"):
		snapshot["skill_data"] = input_handler.get_save_data()
	else:
		snapshot["skill_data"] = ""
	snapshot["unlocked"] = _extract_ability_signature(GDM.player.unlocked_abilities)
	snapshot["action_bar"] = _extract_ability_signature(GDM.player.abilities)
	return snapshot

func _extract_ability_signature(source: Array) -> Array[String]:
	var signature: Array[String] = []
	for entry in source:
		var identifier := ""
		if entry and entry is Resource:
			var res := entry as Resource
			identifier = res.resource_path
			if identifier == "":
				identifier = res.resource_name
		elif entry:
			identifier = str(entry)
		signature.append(identifier)
	return signature

func _evaluate_combined_stats_review() -> void:
	if not GDM:
		return
	var current_snapshot = _capture_current_skill_snapshot()
	if current_snapshot.is_empty():
		GDM.pending_combined_stats_review = false
		return
	if _initial_skill_snapshot.is_empty():
		_initial_skill_snapshot = current_snapshot.duplicate(true)
	var changed = _has_skill_snapshot_changed(_initial_skill_snapshot, current_snapshot)
	GDM.pending_combined_stats_review = changed
	_initial_skill_snapshot = current_snapshot.duplicate(true)

func _has_skill_snapshot_changed(original: Dictionary, current: Dictionary) -> bool:
	if original.is_empty():
		return false
	if original.get("skill_data", "") != current.get("skill_data", ""):
		return true
	var original_unlocked: Array = original.get("unlocked", [])
	var current_unlocked: Array = current.get("unlocked", [])
	if original_unlocked != current_unlocked:
		return true
	var original_action_bar: Array = original.get("action_bar", [])
	var current_action_bar: Array = current.get("action_bar", [])
	if original_action_bar != current_action_bar:
		return true
	return false

func _on_back_button_pressed() -> void:
	_save_player_data()
	_evaluate_combined_stats_review()

	# Null safety checks
	if not input_handler or not input_handler.skilltree:
		printerr("Cannot check skill tree state - missing dependencies")
		return

	if input_handler.skilltree.max_unlock_cost == 0:
		GDM.player.levelup = false
	else:
		GDM.player.levelup = true
	GDM.vs_save()
	var target_scene := GDM.previous_scene_path
	if target_scene == "" or not ResourceLoader.exists(target_scene):
		target_scene = "res://WorldMap/world_map.tscn"
		FW_Debug.debug_log(["Fallback scene path used for skill tree exit: " + target_scene])
	ScreenRotator.change_scene(target_scene)
	#emit_signal("back_button")
