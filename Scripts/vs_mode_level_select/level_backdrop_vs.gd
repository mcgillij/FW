class_name FW_LevelBackdropVS
extends MarginContainer

signal save_scroll_value

@export var block: PackedScene

# Animation and timing constants
const REFRESH_COOLDOWN_MS: int = 500  # Increased from 100ms for Steam Deck
const DEFAULT_SCROLL_DURATION: float = 0.5
const RETRY_SCROLL_DURATION: float = 0.3
const SMART_SCROLL_DURATION: float = 0.8

# Game constants
const STARTING_DEPTH: int = 0
const PVP_ARENA_THRESHOLD: float = 1.0

# (Debug prints removed for production)

# Configuration
var _config: FW_LevelMapConfig

# Core components
var _scroll_controller: FW_ScrollController = null
var _viewport_manager: FW_ViewportManager = null
var _state_sync: FW_StateSynchronizer = null
var _ui_block_manager: FW_UIBlockManager = null
var _line_drawing_manager: FW_LineDrawingManager = null

var _root_node: FW_LevelNode = null
var _level_tree_ui_container: VBoxContainer = VBoxContainer.new()
var _current_level_map_hash: int = 0
var _path_line: Line2D

# Viewport system variables (maintained for backward compatibility)
var _viewport_start_depth: int = 0
var _viewport_end_depth: int = 0
var _total_level_depth: int = 0
var _last_filtered_depth_map: Dictionary = {}

# Scroll position management
var _scroll_container: ScrollContainer = null

# Refresh throttling
var _last_refresh_time: int = 0
var _last_completed_level_name: String = ""
var _refresh_in_progress: bool = false

# --- Debug / Instrumentation ---
var _draw_calls_count: int = 0
var _last_draw_duration_ms: int = 0
var _last_blocks_count: int = 0
var _last_render_stats: Dictionary = {}
var _last_level_completed_time_ms: int = 0


func _ready() -> void:
	if not _initialize_system():
		return

	if not _setup_level_structure():
		return

	_initialize_level_map_ui()
	GDM.vs_save()

	# Defensive reset: clear any stale global action flags that could block UI
	GDM.player_action_in_progress = false
	GDM.skill_check_in_progress = false


func _initialize_system() -> bool:
	"""Initialize the system components"""
	# Initialize configuration
	_config = FW_LevelMapConfig.new()

	_level_tree_ui_container.set("theme_override_constants/separation", _config.V_SPACER)

	# Find the scroll container parent
	_find_scroll_container()

	# Initialize core components
	if not _initialize_components():
		return false

	# Setup event connections (ensure they're not already connected)
	if not EventBus.level_completed.is_connected(_on_level_completed):
		EventBus.level_completed.connect(_on_level_completed)

	return true

func _exit_tree() -> void:
	"""Clean up connections when the node is removed"""
	if EventBus.level_completed.is_connected(_on_level_completed):
		EventBus.level_completed.disconnect(_on_level_completed)

	if _state_sync and _state_sync.state_updated.is_connected(_on_game_state_updated):
		_state_sync.state_updated.disconnect(_on_game_state_updated)

func get_content_size() -> Vector2:
	# Returns the unscaled size of this MarginContainer itself.
	if scale.x != 0 and scale.y != 0:
		return size / scale
	else:
		return size

func _setup_level_structure() -> bool:
	"""Setup level structure by generating or loading"""
	var level_gen_params = GDM.current_info.level_to_generate
	_current_level_map_hash = level_gen_params["map_hash"]

	# Generate or load level structure
	if level_gen_params.has("arena_type") and level_gen_params["arena_type"] == "pvp":
		_generate_new_level_structure(level_gen_params)
	elif GDM.load_level_data(_current_level_map_hash):
		_root_node = GDM.world_state.get_level_data(_current_level_map_hash)
		# If data is null but we have generation params, regenerate
		if not _root_node or _root_node.name == "":
			var gen_params = GDM.world_state.get_level_gen_params(_current_level_map_hash)
			if gen_params.size() > 0:
				# Generate level structure but don't overwrite saved monster/event data
				_root_node = GDM.generate_new_level(_current_level_map_hash, gen_params, true)
				# CRITICAL: Apply saved progress to regenerated level
				if _root_node:
					GDM._apply_saved_progress_to_level(_root_node, _current_level_map_hash)
		if _root_node:
			_ensure_starting_node_in_history()
			_calculate_total_level_depth()
	else:
		_generate_new_level_structure(level_gen_params)

	# Ensure we have a valid root node
	if not _root_node:
		return false

	# Finalize component setup now that root node is available
	_finalize_component_setup()

	return true

func _initialize_components() -> bool:
	"""Initialize all core components"""
	_scroll_controller = FW_ScrollController.new(_scroll_container)
	_viewport_manager = FW_ViewportManager.new(_config)
	_state_sync = FW_StateSynchronizer.new(GDM.current_info.world.world_hash)
	_ui_block_manager = FW_UIBlockManager.new(_config, block, _level_tree_ui_container)

	# Initialize scroll controller with saved zoom level
	if _scroll_controller:
		var saved_zoom = ConfigManager.level_select_zoom if ConfigManager.level_select_zoom != Vector2.ZERO else Vector2.ONE
		_scroll_controller.set_zoom_level(saved_zoom)

	return _scroll_controller && _viewport_manager && _state_sync && _ui_block_manager

func _finalize_component_setup() -> void:
	"""Finalize component setup after root node is available"""
	if _ui_block_manager and _root_node:
		_ui_block_manager.set_root_node(_root_node)

	if _line_drawing_manager and _root_node:
		_line_drawing_manager.set_root_node(_root_node)

	if _state_sync:
		# Connect to state changes to update UI when needed (ensure not already connected)
		if not _state_sync.state_updated.is_connected(_on_game_state_updated):
			_state_sync.state_updated.connect(_on_game_state_updated)

func update_zoom_level(zoom_level: Vector2) -> void:
	"""Update zoom level for both the backdrop and line drawing manager with proper synchronization"""
	# Update scale first
	scale = zoom_level

	# Ensure line drawing manager zoom is synchronized
	if _line_drawing_manager:
		_line_drawing_manager.set_zoom_level(zoom_level)

	# Update scroll controller
	if _scroll_controller:
		_scroll_controller.set_zoom_level(zoom_level)

	# Force layout update after zoom change to ensure coordinates are recalculated
	call_deferred("_handle_zoom_change_layout_update")

func _handle_zoom_change_layout_update() -> void:
	"""Handle layout updates after zoom changes - SIMPLIFIED approach"""
	if not _line_drawing_manager or not _root_node:
		return

	# SIMPLIFIED: No complex layout forcing needed since we use relative coordinates
	# Just redraw lines with new zoom level
	if not _refresh_in_progress:
		var game_state = _state_sync.get_current_game_state()
		_line_drawing_manager.draw_all_lines(_root_node, game_state)

func trigger_auto_scroll() -> void:
	"""Public method to trigger auto-scroll to current position"""
	_smart_scroll_to_current_position(0.5)

func _on_game_state_updated(_current_level: int, _path_history: Dictionary) -> void:
	"""Handle game state updates"""
	# Prevent updates during refresh to avoid loops
	if _refresh_in_progress:
		return

	if _ui_block_manager:
		var game_state = _state_sync.get_current_game_state()
		_ui_block_manager.update_block_states(game_state)

func _ensure_starting_node_in_history() -> void:
	"""Ensure the starting node is always in the path history"""
	var path_history = GDM.world_state.get_path_history(GDM.current_info.world.world_hash)
	if not path_history.has(STARTING_DEPTH) and _root_node:
		GDM.world_state.update_path_history(
			GDM.current_info.world.world_hash,
			STARTING_DEPTH,
			_root_node
		)

func _generate_new_level_structure(level_gen_params: Dictionary) -> void:
	"""Generate new level structure"""
	# Check if this is a pure PvP arena (pvp_probability = 1.0)
	if level_gen_params.get("pvp_probability", 0.0) >= PVP_ARENA_THRESHOLD:
		FW_PvPCache.refresh_for_new_game()

	# Generate the level structure
	_root_node = GDM.get_or_generate_level(_current_level_map_hash, level_gen_params)

	# Calculate total level depth and initialize path history
	_calculate_total_level_depth()
	_ensure_starting_node_in_history()

# --- Viewport System ---
func _calculate_total_level_depth() -> void:
	"""Calculate the maximum depth in the level tree using the viewport manager"""
	_viewport_manager.calculate_total_depth(_root_node)
	# Update local variable for backward compatibility
	_total_level_depth = _viewport_manager.get_viewport_bounds().total_depth

func _calculate_viewport_range() -> void:
	"""Calculate the current viewport range based on player position"""
	var game_state = _state_sync.get_current_game_state()
	_viewport_manager.calculate_viewport_range(game_state.current_level)
	# Update local variables for backward compatibility
	var bounds = _viewport_manager.get_viewport_bounds()
	_viewport_start_depth = bounds.start
	_viewport_end_depth = bounds.end
	_total_level_depth = bounds.total_depth

func _is_depth_in_viewport(depth: int) -> bool:
	"""Check if a depth level is within the current viewport"""
	return _viewport_manager.is_depth_in_viewport(depth)

func _create_viewport_indicators() -> void:
	"""Create UI indicators for levels above/below the viewport"""
	# Prefer to pass the last filtered depth map so the indicator counts reflect
	# actual depth layers with nodes rather than index math.
	_viewport_manager.create_viewport_indicators(_level_tree_ui_container, _last_filtered_depth_map)

func _clear_viewport_indicators() -> void:
	"""Remove existing viewport indicators"""
	_viewport_manager.clear_indicators()

func _filter_depth_map_by_viewport(depth_map: Dictionary) -> Dictionary:
	"""Filter the depth map to only include levels within the viewport"""
	return _viewport_manager.filter_depth_map_by_viewport(depth_map)

# --- Scroll Position Management ---
func _find_scroll_container() -> void:
	"""Find the parent ScrollContainer for smooth scrolling"""
	var current_parent = get_parent()
	while current_parent:
		if current_parent is ScrollContainer:
			_scroll_container = current_parent
			return
		current_parent = current_parent.get_parent()

func _save_scroll_position() -> void:
	"""Save the current scroll position"""
	if _scroll_controller:
		_scroll_controller.save_current_position()
		save_scroll_value.emit()

func _restore_scroll_position_immediately() -> void:
	"""Restore scroll position immediately without smooth tweening"""
	if _scroll_controller:
		_scroll_controller.restore_position_immediately()

func _restore_scroll_position_smooth(duration: float = DEFAULT_SCROLL_DURATION) -> void:
	"""Restore scroll position with smooth tweening"""
	if _scroll_controller:
		_scroll_controller.restore_position_smooth(duration)

func _smart_scroll_to_current_position(duration: float = SMART_SCROLL_DURATION) -> void:
	"""Intelligently scroll to show the current player position"""
	if not _scroll_controller:
		return

	# Ensure layout and scrollbars are up-to-date before calculating positions
	await get_tree().process_frame

	var game_state = _state_sync.get_current_game_state()
	var current_node = _state_sync.get_current_position_node(
		game_state.current_level, game_state.path_history, _root_node
	)

	if not current_node or not _ui_block_manager.has_block(current_node.name):
		return

	var current_block: Control = _ui_block_manager.get_block_by_name(current_node.name)
	if not current_block:
		return

	var optimal_position = _scroll_controller.calculate_optimal_scroll_position(current_block, self)
	_scroll_controller.scroll_to_position(optimal_position, duration)

# --- UI Initialization and Drawing ---
func _initialize_level_map_ui() -> void:
	"""Initialize the level map UI with error handling and validation"""
	# Calculate the viewport range first
	_calculate_viewport_range()

	# Create and setup path line
	_create_path_line()

	# Initialize line drawing manager
	_line_drawing_manager = FW_LineDrawingManager.new(_config, self)

	# Set initial zoom level from config
	var saved_zoom = ConfigManager.level_select_zoom if ConfigManager.level_select_zoom != Vector2.ZERO else Vector2.ONE
	if _line_drawing_manager:
		_line_drawing_manager.set_zoom_level(saved_zoom)

	# Keep container and scroll controller in sync with saved zoom from the start
	scale = saved_zoom
	if _scroll_controller:
		_scroll_controller.set_zoom_level(saved_zoom)

	add_child(_level_tree_ui_container)

	# Create UI blocks
	_create_validated_ui_blocks()

	# Add viewport indicators
	_create_viewport_indicators()

	# SIMPLIFIED: Just wait one frame and draw - no complex layout synchronization needed
	await get_tree().process_frame
	_draw_all_lines()

func _create_path_line() -> void:
	"""Create and configure the path line - no longer needed with optimized renderer"""
	# The optimized renderer handles path drawing through mesh rendering
	# No need to create a separate Line2D for the path
	_path_line = null

func _create_validated_ui_blocks() -> bool:
	"""Create UI blocks from depth map"""
	var nodes_by_depth_map = FW_LevelGenerator.collect_nodes_by_depth(_root_node)
	var filtered_depth_map = _filter_depth_map_by_viewport(nodes_by_depth_map)
	# Store for indicator computations
	_last_filtered_depth_map = filtered_depth_map

	# Create UI blocks using the manager
	var game_state = _state_sync.get_current_game_state()
	var ui_blocks_map = _ui_block_manager.create_blocks_from_depth_map(filtered_depth_map, game_state)

	# Apply performance optimizations based on reachability and viewport position
	_apply_performance_optimizations_to_blocks(ui_blocks_map, game_state)

	return ui_blocks_map.size() > 0

func _apply_performance_optimizations_to_blocks(ui_blocks_map: Dictionary, game_state: Dictionary) -> void:
	"""Apply performance optimizations to blocks based on their state and viewport position"""
	if not ui_blocks_map:
		return

	var current_level = game_state.get("current_level", 0)
	var path_history = game_state.get("path_history", {})

	# Get current position node and available nodes
	var current_node = null
	var _available_nodes = []
	if _root_node:
		current_node = _state_sync.get_current_position_node(current_level, path_history, _root_node)
		if current_node:
			# Use the children of current node as available next nodes
			_available_nodes = current_node.children if current_node.children else []

	for block_name in ui_blocks_map:
		var ui_block = ui_blocks_map[block_name]
		if not ui_block or not ui_block.has_method("enable_performance_optimization"):
			continue

		# Check if this is the current position block
		var is_current_position = current_node and ui_block.level_node and current_node.level_hash == ui_block.level_node.level_hash

		# Mark current position using existing set_current_tile function
		if ui_block.has_method("set_current_tile"):
			ui_block.set_current_tile(is_current_position)

		# Determine if this block is an active choice (current node's children)
		var is_active_choice := false
		if not is_current_position and ui_block.level_node and current_node:
			for child in current_node.children:
				if child and child.level_hash == ui_block.level_node.level_hash:
					is_active_choice = true
					break

		# Pass through the choice flag so Block can gate fog shader usage
		if "is_active_choice_block" in ui_block:
			ui_block.is_active_choice_block = is_active_choice

		# Active choices and current position should run full effects; others optimized
		var should_optimize = not (is_current_position or is_active_choice)
		ui_block.enable_performance_optimization(should_optimize)

func _ensure_zoom_synchronization() -> void:
	"""Ensure zoom level is properly synchronized between backdrop and line drawing manager"""
	if _line_drawing_manager and _line_drawing_manager._current_zoom_level != scale:
		_line_drawing_manager.set_zoom_level(scale)

func _force_ui_layout_update() -> void:
	"""No-op layout update (was forcing canvas refresh and causing redraws)."""
	return

func _should_optimize_block(ui_block, current_level: int, available_nodes: Array) -> bool:
	"""Determine if a block should have performance optimizations enabled - AGGRESSIVE CULLING"""
	if not ui_block or not ui_block.level_node:
		return true

	var block_depth = ui_block.level_node.level_depth

	# CRITICAL: Only preserve expensive rendering for the absolute minimum needed blocks
	# This is much more aggressive culling for Steam Deck performance

	# Never optimize current position
	var is_current_position = ui_block.has_method("is_current_player_position") and ui_block.is_current_player_position
	if is_current_position:
		return false

	# Only keep expensive shaders for immediate next choices (depth = current + 1)
	if block_depth == current_level + 1:
		# Check if it's actually an available choice
		for available_node in available_nodes:
			if available_node and available_node.level_hash == ui_block.level_node.level_hash:
				return false  # Don't optimize - this is an immediate player choice

	# AGGRESSIVE: Optimize everything else including:
	# - Current level blocks that aren't the player position
	# - All completed blocks
	# - Blocks more than 1 level away
	# - Unreachable blocks
	# - Blocks outside tight viewport bounds

	# Check viewport bounds more strictly
	if not _viewport_manager or not _viewport_manager.is_depth_in_viewport(block_depth):
		return true  # Optimize blocks outside viewport

	# Optimize if more than 1 level away from current
	if abs(block_depth - current_level) > 1:
		return true

	# Always optimize completed blocks (they don't need fancy shaders)
	var is_completed = ui_block._is_node_completed() if ui_block.has_method("_is_node_completed") else false
	if is_completed:
		return true

	# Optimize unreachable blocks
	var is_reachable = ui_block._is_node_reachable() if ui_block.has_method("_is_node_reachable") else true
	if not is_reachable:
		return true

	# Default to optimizing for Steam Deck performance
	return true

func _draw_all_lines() -> void:
	"""Draw all lines using optimized manager"""
	var game_state = _state_sync.get_current_game_state()
	var ui_blocks_map = _ui_block_manager.get_blocks_map()

	# Skip drawing if no root node or no UI blocks are available yet
	if not _root_node or ui_blocks_map.is_empty():
		return

	# Ensure zoom level is synchronized before drawing
	_ensure_zoom_synchronization()

	# Timing: measure draw cost
	var t0 = Time.get_ticks_msec()

	# Use optimized manager (already using OptimizedLineDrawingManager)
	_line_drawing_manager.update_context(ui_blocks_map, _viewport_start_depth, _viewport_end_depth)
	_line_drawing_manager.draw_all_lines(_root_node, game_state)

	# Collect stats
	_draw_calls_count += 1
	_last_blocks_count = ui_blocks_map.size()
	_last_render_stats = _line_drawing_manager.get_render_stats() if _line_drawing_manager else {}
	_last_draw_duration_ms = Time.get_ticks_msec() - t0

func _on_level_completed(_completed_level: FW_LevelNode) -> void:
	"""Called when a level is completed to refresh the UI"""
	_last_level_completed_time_ms = Time.get_ticks_msec()
	# Prevent overlapping refreshes
	if _refresh_in_progress:
		return

	_update_refresh_tracking(_completed_level)

	# Check if viewport needs to shift
	var old_viewport_start = _viewport_start_depth
	var old_viewport_end = _viewport_end_depth
	_calculate_viewport_range()

	var viewport_changed = (_viewport_start_depth != old_viewport_start or _viewport_end_depth != old_viewport_end)

	# Defer UI operations to next frame for stable updates
	call_deferred("_handle_deferred_ui_refresh", viewport_changed)

func _handle_deferred_ui_refresh(viewport_changed: bool) -> void:
	"""Handle UI refresh operations in a deferred manner to prevent CPU spikes"""
	# Prevent overlapping refreshes
	if _refresh_in_progress:
		return

	# Additional safety check - make sure we have valid components
	if not _ui_block_manager or not _root_node:
		return

	_refresh_in_progress = true

	if viewport_changed:
		await _refresh_level_map_ui()
	else:
		await _refresh_lines_only_with_stability()

	# After any refresh, ensure block states and visual policy reflect the new game state
	var game_state = _state_sync.get_current_game_state()
	if _ui_block_manager:
		# Update block states
		_ui_block_manager.update_block_states(game_state)
		# Re-apply performance optimizations and current/choice visuals
		_apply_performance_optimizations_to_blocks(_ui_block_manager.get_blocks_map(), game_state)

	# Try to scroll to the new current position (deferred to avoid blocking)
	call_deferred("_try_smart_scroll_with_fallback")

	_refresh_in_progress = false

func _refresh_lines_only_with_stability() -> void:
	"""Refresh only the lines with simplified approach"""
	if not _line_drawing_manager or not _root_node:
		return

	# SIMPLIFIED: Just wait one frame, no complex layout checking needed
	await get_tree().process_frame

	# Get current game state
	var game_state = _state_sync.get_current_game_state()
	var ui_blocks_map = _ui_block_manager.get_blocks_map()

	# Update line drawing manager context
	_line_drawing_manager.update_context(ui_blocks_map, _viewport_start_depth, _viewport_end_depth)

	# Update block states
	_ui_block_manager.update_block_states(game_state)

	# Clear and redraw all lines with simplified synchronization
	var t0 = Time.get_ticks_msec()
	_line_drawing_manager.draw_all_lines(_root_node, game_state)
	_last_render_stats = _line_drawing_manager.get_render_stats() if _line_drawing_manager else {}
	_last_draw_duration_ms = Time.get_ticks_msec() - t0
	_draw_calls_count += 1

func _update_refresh_tracking(completed_level: FW_LevelNode) -> void:
	"""Update refresh tracking variables"""
	_last_refresh_time = Time.get_ticks_msec()
	_last_completed_level_name = completed_level.name if completed_level else "none"

func _refresh_lines_only() -> void:
	"""Light refresh that only redraws the lines without recreating UI blocks"""
	if not _line_drawing_manager:
		return

	# Ensure zoom level is synchronized before redrawing lines
	if _line_drawing_manager._current_zoom_level != scale:
		_line_drawing_manager.set_zoom_level(scale)

	var game_state = _state_sync.get_current_game_state()
	var ui_blocks_map = _ui_block_manager.get_blocks_map()

	_line_drawing_manager.update_context(ui_blocks_map, _viewport_start_depth, _viewport_end_depth)
	var t0 = Time.get_ticks_msec()
	_line_drawing_manager.draw_all_lines(_root_node, game_state)
	_last_render_stats = _line_drawing_manager.get_render_stats() if _line_drawing_manager else {}
	_last_draw_duration_ms = Time.get_ticks_msec() - t0
	_draw_calls_count += 1

	# Update block states efficiently
	_ui_block_manager.update_block_states(game_state)

	# Reapply performance optimizations after state updates
	_apply_performance_optimizations_to_blocks(ui_blocks_map, game_state)

func _refresh_level_map_ui() -> void:
	"""Refresh the level map UI to reflect current state using viewport system"""
	# Save scroll position for restoration
	_save_scroll_position()

	# Save current zoom level before clearing UI
	var current_zoom = scale

	# Clear existing UI and lines
	_clear_all_ui_elements()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Recalculate viewport range based on new current position
	_calculate_viewport_range()

	# Recreate the UI
	_recreate_ui_elements()

	# Restore zoom level immediately after UI recreation but before positioning
	scale = current_zoom
	if _line_drawing_manager:
		_line_drawing_manager.set_zoom_level(current_zoom)

	# Wait for UI layout to finish with zoom applied
	await get_tree().process_frame

	# CRITICAL FIX: Restore scroll position BEFORE drawing lines
	# This ensures UI blocks are positioned correctly when lines are calculated
	_restore_scroll_position_immediately()

	# Use simplified layout synchronization before drawing lines
	await get_tree().process_frame
	_draw_all_lines()

	# Handle final scrolling adjustments if needed
	_handle_post_refresh_scrolling()

func _clear_all_ui_elements() -> void:
	"""Clear all UI elements"""
	if _line_drawing_manager:
		_line_drawing_manager.clear_all_lines()

	if _ui_block_manager:
		_ui_block_manager.clear_blocks()

	_clear_viewport_indicators()

func _recreate_ui_elements() -> bool:
	"""Recreate UI elements after clearing"""
	var nodes_by_depth_map = FW_LevelGenerator.collect_nodes_by_depth(_root_node)
	var filtered_depth_map = _filter_depth_map_by_viewport(nodes_by_depth_map)
	_last_filtered_depth_map = filtered_depth_map

	var game_state = _state_sync.get_current_game_state()
	var ui_blocks_map = _ui_block_manager.create_blocks_from_depth_map(filtered_depth_map, game_state)

	# Add viewport indicators
	_create_viewport_indicators()

	# Update line drawing manager context
	_line_drawing_manager.update_context(ui_blocks_map, _viewport_start_depth, _viewport_end_depth)

	return ui_blocks_map.size() > 0

func _handle_post_refresh_scrolling() -> void:
	"""Handle scrolling after UI refresh with improved logic"""
	# Defer scroll handling to avoid blocking the main thread
	call_deferred("_try_smart_scroll_with_fallback")

func _try_smart_scroll_with_fallback() -> void:
	"""Try to scroll to current position with fallback, in a non-blocking way"""
	var game_state = _state_sync.get_current_game_state()
	var current_node = _state_sync.get_current_position_node(
		game_state.current_level, game_state.path_history, _root_node
	)

	# Try to scroll to current position, with fallback logic
	if not await _try_scroll_to_current_position(current_node):
		_restore_scroll_position_smooth(RETRY_SCROLL_DURATION)

func _try_scroll_to_current_position(current_node: FW_LevelNode) -> bool:
	"""Attempt to scroll to current position with retry logic"""
	if not current_node or not _ui_block_manager.has_block(current_node.name):
		return false

	var current_block = _ui_block_manager.get_block_by_name(current_node.name)
	if not current_block:
		return false

	# Check if block is positioned, with one retry after frame processing
	if current_block.global_position != Vector2.ZERO:
		_smart_scroll_to_current_position(DEFAULT_SCROLL_DURATION)
		return true

	# Wait one frame and try again
	await get_tree().process_frame
	if current_block.global_position != Vector2.ZERO:
		_smart_scroll_to_current_position(DEFAULT_SCROLL_DURATION)
		return true

	return false

# --- Static Helper Functions (maintained for backward compatibility) ---
static func _find_node_by_name(root: FW_LevelNode, target_name: String) -> FW_LevelNode:
	if not root:
		return null
	if root.name == target_name:
		return root
	for child in root.children:
		var found = _find_node_by_name(child, target_name)
		if found:
			return found
	return null

static func is_node_in_available_list(target_node: FW_LevelNode, available_nodes: Array) -> bool:
	if not target_node:
		return false
	for available_node in available_nodes:
		if available_node and available_node.level_hash == target_node.level_hash:
			return true
	return false

func debug_rendering_state() -> Dictionary:
	"""Debug method to check rendering state and identify potential issues"""
	var debug_info = {
		"current_zoom": scale,
		"viewport_range": {
			"start": _viewport_start_depth,
			"end": _viewport_end_depth,
			"total": _total_level_depth
		},
		"ui_blocks_count": _ui_block_manager.get_blocks_map().size() if _ui_block_manager else 0,
		"line_drawing_zoom": _line_drawing_manager._current_zoom_level if _line_drawing_manager else Vector2.ONE,
		"zoom_synchronized": (_line_drawing_manager._current_zoom_level == scale) if _line_drawing_manager else false
	}

	if _line_drawing_manager:
		debug_info.merge(_line_drawing_manager.debug_coordinate_system(), true)

	return debug_info

static func find_node_in_tree_by_hash(target_level_hash: int, root_node: FW_LevelNode) -> FW_LevelNode:
	if not root_node:
		return null
	var queue = [root_node]
	var visited = {}
	while queue.size() > 0:
		var node = queue.pop_front()
		if not node or visited.has(node.get_instance_id()):
			continue
		visited[node.get_instance_id()] = true
		if node.level_hash == target_level_hash:
			return node
		for child in node.children:
			if child and not visited.has(child.get_instance_id()):
				queue.append(child)
	return null
