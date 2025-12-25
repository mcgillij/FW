extends Control

class_name FW_Block

# Visual state constants for better maintainability
const COMPLETED_NODE_COLOR = Color(0.3, 0.3, 0.3)  # Dim grey for completed nodes
const UNREACHABLE_NODE_COLOR = Color(0.5, 0.5, 0.5, 1)  # Semi-transparent grey for unreachable nodes
const NORMAL_NODE_COLOR = Color.WHITE  # Normal bright appearance

@onready var monster_block: Panel = %MonsterBlock
@onready var event_block: Panel = %EventBlock
@onready var starting_block: Panel = %StartingBlock
@onready var blacksmith_block: Panel = %BlacksmithBlock

@onready var mini_game_block: Panel = %MiniGameBlock
@onready var minigame_name: Label = %minigame_name
@onready var minigame_image: TextureRect = %minigame_image
@onready var minigame_button: Button = %minigame_button
@onready var minigame_fog_of_war_button: TextureButton = %minigame_fog_of_war_button


@onready var shader_rect: TextureRect = %shader_rect

@onready var node_type_image: TextureRect = %node_type_image

@onready var roll_dice_button: TextureButton = %roll_dice_button
@onready var level_name_label: Label = %level_name_label
@onready var level_depth_label: Label = %level_depth_label
@onready var environment_container: VBoxContainer = %EnvironmentContainer
@onready var enemy_image: TextureButton = %enemy_image
@onready var enemy_label: Label = %enemy_label
@onready var level_fog_of_war_button: TextureButton = %level_fog_of_war_button
@onready var event_fog_of_war_button: TextureButton = %event_fog_of_war_button
@onready var button_container: HBoxContainer = %button_container

@onready var start_button: Button = %start_button
@onready var skill_check: FW_SkillCheck = %SkillCheck

@onready var paws_image: TextureRect = %paws_image

@onready var event_button: Button = %event_button
@onready var event_name: Label = %event_name
@onready var event_image: TextureRect = %event_image

# blacksmith
@onready var blacksmith_label: Label = %blacksmith_label
@onready var blacksmith_fog_of_war_button: TextureButton = %blacksmith_fog_of_war_button
@onready var blacksmith_button: Button = %blacksmith_button

var panel_dimensions:= Vector2(265,185)
var monster_res: FW_Monster_Resource
var level_name: String
var level_depth: int
var level_node: FW_LevelNode
var event: FW_EventResource

# New unified data system
var block_data: FW_BlockDisplayData

# Path state management
var is_reachable: bool = true
var is_completed: bool = false
var path_difficulty: String = "normal"

# Performance optimization variables (always-on optimized baseline)
var is_performance_optimized: bool = true
var pulse_tween: Tween = null
var current_shader_materials: Array[ShaderMaterial] = []
var is_current_player_position: bool = false

# Fog button shader preservation
var fog_button_material: ShaderMaterial = null
var preserve_fog_shader: bool = false

# Signal optimization - track connections to prevent leaks
var _active_signal_connections: Array[Signal] = []

# Viewport visibility tracking for additional optimizations
var _is_in_viewport: bool = true

# Shader material caching for performance
static var _shader_cache: Dictionary = {}
static var _material_pool: Array[ShaderMaterial] = []

var is_drawer_open: bool = false
var should_drawer_be_open: bool = false # If true, drawer must stay open
var closed_position: Vector2
var open_position: Vector2

var noise := load("res://Noise/Noise.tres")

var pulse_duration: float = 1.5
# The minimum thickness of the outline during the pulse.
var min_thickness: float = 4.0
# The maximum thickness of the outline during the pulse.
var max_thickness: float = 20.0
# The first color for the outline gradient.
var color1: Color = Color("ffff00") # Yellow
# The second color for the outline gradient.
var color2: Color = Color("ff00ff") # Magenta
# Toggle for legacy heavy shader-based pulse on dice (disabled by default)
var use_heavy_pulse: bool = false

# Lightweight, shader-free dice attention tween
var dice_attention_tween: Tween = null
var dice_original_scale: Vector2 = Vector2.ONE
var dice_original_modulate: Color = Color.WHITE
var dice_child_original_modulates: Array = []
var dice_bounce_tween: Tween = null
var dice_original_self_modulate: Color = Color(1,1,1,1)

var active_panel: Panel
var is_active_choice_block: bool = false

# Mapping of monster_type to icon textures
const MONSTER_TYPE_ICONS := {
	FW_Monster_Resource.monster_type.SCRUB: preload("res://Monsters/MonsterDifficultyImages/scrub.png"),
	FW_Monster_Resource.monster_type.GRUNT: preload("res://Monsters/MonsterDifficultyImages/grunt.png"),
	FW_Monster_Resource.monster_type.ELITE: preload("res://Monsters/MonsterDifficultyImages/elite.png"),
	FW_Monster_Resource.monster_type.BOSS: preload("res://Monsters/MonsterDifficultyImages/boss.png"),
}
const EVENT_ICON := preload("res://tile_images/questionmarks.png")

const PLAYER_PVP_ICON := preload("res://Monsters/MonsterDifficultyImages/fallen_player.png")
const BLACKSMITH_ICON := preload("res://Monsters/MonsterDifficultyImages/blacksmith.png")
const MINIGAME_ICON := preload("res://Icons/minigames.png")

func _ready() -> void:
	# Connect to EventBus for level completion updates
	EventBus.level_completed.connect(_on_level_completed)

	# Store the initial (closed) position
	closed_position = button_container.position
	open_position = closed_position + Vector2(40, 0)
	custom_minimum_size = panel_dimensions

	# Baseline: background shader rect is hidden and cleared
	if shader_rect:
		shader_rect.visible = false
		shader_rect.material = null

	# Setup viewport visibility notifications for additional optimizations
	if get_viewport():
		_track_viewport_visibility()

	# If the drawer should be open (e.g. after scene reload), open it
	if should_drawer_be_open and not is_drawer_open:
		show_play_button_drawer()

func _exit_tree() -> void:
	"""Clean up resources when block is removed"""
	_cleanup_resources()

func _cleanup_resources() -> void:
	"""Clean up all resources and connections"""
	# Stop any running animations
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		pulse_tween = null

	# Stop dice attention tween and restore visuals
	_stop_dice_attention()

	# Clear shader materials
	_clear_shader_materials()

	# Clean up fog button preservation
	fog_button_material = null
	preserve_fog_shader = false

	# Clean up signal connections
	_cleanup_signal_connections()

func _cleanup_signal_connections() -> void:
	"""Clean up tracked signal connections"""
	# Note: For Godot 4, signal cleanup is mostly automatic
	# This function exists for future extensibility if manual cleanup is needed
	_active_signal_connections.clear()

func _track_viewport_visibility() -> void:
	"""Setup viewport visibility tracking for performance optimization"""
	# Connect to viewport notifications for visibility changes
	# This helps optimize blocks that are outside the visible area
	if has_signal("visibility_changed"):
		visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	"""Handle visibility changes for viewport-based optimization"""
	_is_in_viewport = is_visible_in_tree()

	# Keep baseline optimized; visibility changes won't flip effects here

func _on_level_completed(_completed_node: FW_LevelNode) -> void:
	"""Called when any level/event is completed - refresh our state"""
	# Only update if this block might be affected by the completion
	if not level_node or not _completed_node:
		return

	# Performance optimization: only update if this could affect our block
	# (same depth or adjacent depths)
	var depth_diff = abs(level_node.level_depth - _completed_node.level_depth)
	if depth_diff > 1:
		return

	# Defer the update to prevent frame spikes when many blocks update at once
	call_deferred("_deferred_completion_update")

func _deferred_completion_update() -> void:
	"""Deferred update of completion states"""
	_update_event_completion_state()
	_update_level_completion_state()
	_update_blacksmith_completion_state()
	_update_minigame_completion_state()

func set_current_tile(is_current: bool) -> void:
	# Applies a strong glowing/smoke background using panel_glow_smoke.gdshader
	is_current_player_position = is_current  # Track current position for minimal exceptions

	if is_current:
		# Ensure shader_rect is visible for current position
		if shader_rect:
			shader_rect.visible = true

		# For current tile, use optimized shader for better performance
		var mat := _get_pooled_material()

		# Use lightweight static shader for better performance across all platforms
		mat.shader = _get_cached_shader("res://Shaders/panel_glow_static.gdshader")
		mat.set_shader_parameter("glow_color", Color(0.2, 1.0, 0.6, 0.7)) # Bright green-cyan, semi-transparent
		mat.set_shader_parameter("glow_strength", 1.0)
		mat.set_shader_parameter("border_width", 0.04)
		mat.set_shader_parameter("inner_glow", 0.4)  # Add subtle inner glow for depth

		shader_rect.material = mat
		current_shader_materials.append(mat)

		# Current node should never be fogged; guarantee fog is cleared persistently and visually
		if level_node and level_node.fog:
			level_node.fog = false
			var map_hash = GDM.current_info.world.world_hash
			GDM.mark_fog_cleared(map_hash, level_node.level_hash, true)
			GDM.world_state.update_fog(map_hash, level_node.fog)
			# Hide any fog button and remove materials without animations
			var fog_btn := _get_current_fog_button()
			if fog_btn:
				fog_btn.hide()
				fog_btn.material = null
			# Skill check panel (if any) should be hidden for current node
			if skill_check:
				skill_check.visible = false

		# Show green paw for current position
		if paws_image:
			paws_image.texture = load("res://Level Select/paws_green.png")
			paws_image.modulate = Color.WHITE
			paws_image.self_modulate = Color.WHITE
			paws_image.show()
	else:
		# Remove the strong glow, revert to normal highlight
		shader_rect.material = null
		_clear_shader_materials()
		# Path highlight skipped by default in optimized baseline

# Performance optimization functions
func enable_performance_optimization(_enable: bool) -> void:
	"""Toggle optimized vs full-effects mode (full effects used for active choices)."""
	if is_performance_optimized == _enable:
		# No change
		return

	is_performance_optimized = _enable
	if _enable:
		_disable_expensive_effects()
		visible = not _is_very_far_from_player()
	else:
		# Re-enable full visual treatment for important tiles (current/choices)
		visible = true
		_enable_expensive_effects()

func _is_very_far_from_player() -> bool:
	"""Check if block is very far from player position (Steam Deck optimization)"""
	if not level_node:
		return true

	var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
	var distance = abs(level_node.level_depth - current_level)

	# Hide blocks more than 3 levels away entirely
	return distance > 3

func _disable_expensive_effects() -> void:
	"""Disable all expensive GPU effects for Steam Deck performance"""
	_stop_pulse_animation()
	_clear_shader_materials()
	_disable_environment_shaders()

	# Ensure background shader is fully disabled
	if shader_rect:
		shader_rect.material = null

	# CRITICAL: Disable expensive UI elements entirely
	if shader_rect:
		shader_rect.visible = false

	# Disable fog button effects if not essential
	if not _should_preserve_fog_shader():
		var fog_button = _get_current_fog_button()
		if fog_button and fog_button.material:
			fog_button.material = null

	# Reduce visual complexity for distant blocks
	if enemy_image and level_node:
		var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
		if abs(level_node.level_depth - current_level) > 2:
			enemy_image.modulate = Color(0.6, 0.6, 0.6, 0.8)  # Dim distant blocks

func _enable_expensive_effects() -> void:
	"""Re-enable key visual effects for important tiles (current position or active choices)."""
	# Heavy dice pulse removed for level select to avoid GPU spikes

	# Environment shaders can be left minimal; enable only panel background and fog
	if shader_rect:
		shader_rect.visible = true
		# Assign a subtle highlight if none is present (current tile may override later)
		if not (shader_rect.material and shader_rect.material is ShaderMaterial):
			var mat := _get_pooled_material()
			mat.shader = _get_cached_shader("res://Shaders/panel_glow_smoke.gdshader")
			mat.set_shader_parameter("glow_color", FW_PathManager.get_path_color(path_difficulty))
			mat.set_shader_parameter("glow_strength", 0.7)
			mat.set_shader_parameter("smoke_density", 0.35)
			mat.set_shader_parameter("smoke_scale", 1.0)
			shader_rect.material = mat
			current_shader_materials.append(mat)

	# Fog button shaders: only keep for current tile or active choice to reduce GPU load
	var fog_button := _get_current_fog_button()
	_restore_fog_button_shader()
	if level_node and level_node.fog and fog_button and not fog_button.material:
		if is_current_player_position or is_active_choice_block:
			# Ensure a fog/burn material is assigned for interactive tiles with fog
			if level_node.skill_check:
				fog_button.material = fog_shader()
			else:
				fog_button.material = burn_shader_material()

	# Restore normal visual appearance
	if enemy_image:
		enemy_image.modulate = Color.WHITE

func _stop_pulse_animation() -> void:
	"""Stop the dice button pulse animation"""
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		pulse_tween = null
	# No shader parameter resets here; shader pulse is disabled in level select

func _start_pulse_animation() -> void:
	# Heavy shader pulse disabled for level select; keep function for API compatibility
	return

func _clear_shader_materials() -> void:
	"""Clear stored shader materials to free resources"""
	for mat in current_shader_materials:
		if mat:
			# Don't return fog button material to pool if we're preserving it
			if preserve_fog_shader and mat == fog_button_material:
				continue
			# Return material to pool for reuse
			_return_material_to_pool(mat)
	current_shader_materials.clear()

# Shader material optimization functions
static func _get_cached_shader(shader_path: String) -> Shader:
	"""Get cached shader or load and cache it"""
	if not _shader_cache.has(shader_path):
		_shader_cache[shader_path] = load(shader_path)
	return _shader_cache[shader_path]

static func _get_pooled_material() -> ShaderMaterial:
	"""Get a material from the pool or create a new one"""
	if _material_pool.size() > 0:
		return _material_pool.pop_back()
	else:
		return ShaderMaterial.new()

static func _return_material_to_pool(mat: ShaderMaterial) -> void:
	"""Return a material to the pool for reuse"""
	if mat and _material_pool.size() < 20:  # Limit pool size
		# Reset material properties
		mat.shader = null
		# Clear shader parameters would be ideal, but not directly accessible
		_material_pool.append(mat)

func _disable_environment_shaders() -> void:
	"""Disable shader effects on environment elements for performance"""
	if not environment_container:
		return

	for child in environment_container.get_children():
		if child is Control and child.material:
			child.material = null

func _preserve_fog_button_shader() -> void:
	"""Preserve the fog button shader material before optimization"""
	if level_fog_of_war_button and level_fog_of_war_button.material:
		fog_button_material = level_fog_of_war_button.material
		preserve_fog_shader = true

func _restore_fog_button_shader() -> void:
	"""Restore the fog button shader material after optimization"""
	if preserve_fog_shader and fog_button_material and level_fog_of_war_button:
		level_fog_of_war_button.material = fog_button_material

func _should_preserve_fog_shader() -> bool:
	"""Determine if fog shader should be preserved based on node state"""
	if not level_node:
		return false

	# Preserve fog shader if:
	# 1. Node has fog enabled
	# 2. Block is reachable (player might interact with it)
	# 3. Block is in current viewport
	return level_node.fog and is_reachable and _is_in_viewport

func _enable_environment_shaders() -> void:
	"""Re-enable shader effects on environment elements"""
	# This will be handled when the block state is refreshed normally
	pass

# environment is string for now but will be an object with effects eventually
func setup(node: FW_LevelNode) -> void:
	level_node = node
	path_difficulty = FW_PathManager.get_path_difficulty(node)

	match node.node_type:
		FW_LevelNode.NodeType.STARTING:
			setup_starting_block(node)
		FW_LevelNode.NodeType.EVENT:
			setup_event_block(node)
		FW_LevelNode.NodeType.MINIGAME:
			block_data = FW_BlockDisplayData.from_minigame(node.minigame_path, node.level_depth, 0, node.level_hash)
			setup_minigame_block(node)
		FW_LevelNode.NodeType.BLACKSMITH:
			setup_blacksmith_block(node)
		FW_LevelNode.NodeType.PLAYER:
			# Create player block data from LevelNode and use unified setup
			var player_combatant = node.get_player_data()
			if player_combatant:
				block_data = FW_BlockDisplayData.from_player(player_combatant, node.level_depth, node.environment, 0, node.level_hash)
			else:
				# Fallback: create with random player
				var fallback_player = FW_PvPCache.get_opponent()
				block_data = FW_BlockDisplayData.from_player(fallback_player, node.level_depth, node.environment, 0, node.level_hash)
			setup_combat_block()
		FW_LevelNode.NodeType.MONSTER:
			# Create monster block data and use unified setup
			block_data = FW_BlockDisplayData.from_monster(node.monster, node.level_depth, node.environment, 0, node.level_hash)
			setup_combat_block()

# New unified setup method that handles both monsters and players
func setup_with_block_data(data: FW_BlockDisplayData, node: FW_LevelNode = null) -> void:
	"""Setup block using BlockDisplayData - supports both monsters and players"""
	block_data = data
	level_node = node

	if node:
		path_difficulty = FW_PathManager.get_path_difficulty(node)

	# Set legacy fields for backward compatibility
	if data.block_type == FW_BlockDisplayData.BlockType.MONSTER:
		monster_res = data.monster_data
	elif data.block_type == FW_BlockDisplayData.BlockType.EVENT:
		event = data.event_data

	# All combat blocks use the same setup (monsters and players)
	if data.is_combat_block():
		setup_combat_block()
	elif data.block_type == FW_BlockDisplayData.BlockType.EVENT:
		setup_event_block(node)
	elif data.block_type == FW_BlockDisplayData.BlockType.MINIGAME:
		setup_minigame_block(node)
	else:
		push_error("Unknown block type: " + str(data.block_type))

# Unified combat block setup (replaces setup_monster_block)
func setup_combat_block() -> void:
	"""Setup the combat block using BlockDisplayData (works for both monsters and players)"""
	if not block_data:
		push_error("BlockDisplayData is required for combat block setup")
		return

	active_panel = monster_block

	# Store pulse tween reference for performance optimization
	# Only start pulsing animation if not performance optimized
	if not is_performance_optimized:
		_start_pulse_animation()

	# Set basic info from block data
	var display_info = block_data.get_display_info()

	if start_button:
		start_button.show()

	# For PvP blocks, use generated level names only, not player names
	if block_data.is_player_block():
		# Use just the generated level name from LevelNameGenerator, not the player's name
		var arena_name_parts = block_data.display_name.split("'s ")
		if arena_name_parts.size() > 1:
			level_name_label.text = arena_name_parts[1]  # Get the part after "Player's "
		else:
			level_name_label.text = block_data.display_name
	else:
		# For monsters and events, use the generated level names
		level_name_label.text = display_info["name"]

	# Always show just the depth number for consistency across all block types
	level_depth_label.text = str(block_data.level_depth)

	level_name = block_data.name
	level_depth = block_data.level_depth

	# Update completion state after setup
	_update_level_completion_state()

	# Setup environment (for monsters) or show player info
	if block_data.is_player_block():
		_setup_player_combat_display()
	else:
		_setup_monster_combat_display()

	# Set the difficulty icon
	node_type_image.texture = block_data.get_difficulty_icon()

	# Handle fog logic for both monsters and players via LevelNode
	if level_node:
		_setup_fog_and_skill_check()
		_handle_auto_drawer_logic()
	else:
		# Fallback for blocks without level nodes (shouldn't happen in normal mixed maps)
		# This is mainly for pure PvP arenas or special cases
		skill_check.visible = false
		level_fog_of_war_button.visible = false
		node_type_image.show()  # Always show difficulty icons

		# Auto-open drawer for blocks without fog
		should_drawer_be_open = true
		if not is_drawer_open:
			show_play_button_drawer()

	monster_block.show()

func _setup_player_combat_display() -> void:
	"""Setup display elements specific to player combat blocks"""
	# Populate environment container for player blocks (players can have environmental effects)
	for child in environment_container.get_children():
		child.queue_free()

	for e in block_data.environment:
		var env = TextureButton.new()
		environment_container.add_child(env)
		if e is FW_EnvironmentalEffect and e.texture:
			env.texture_normal = e.texture
		else:
			env.texture_normal = null
		env.custom_minimum_size = Vector2(40, 40)
		env.ignore_texture_size = true
		env.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		env.tooltip_text = e.description if e is FW_EnvironmentalEffect else ""
		env.material = shader_material()
		env.connect("pressed", do_env_popup.bind(e))

	# Set player texture and info - show player name and job
	enemy_label.text = block_data.player_data.name
	if block_data.job_name != "":
		enemy_label.text += " (" + block_data.job_name + ")"
	enemy_image.texture_normal = block_data.texture

	# Connect to player info popup instead of monster popup
	if enemy_image.is_connected("pressed", do_monster_popup):
		enemy_image.disconnect("pressed", do_monster_popup)
	enemy_image.connect("pressed", _do_player_popup.bind(block_data))

func _setup_monster_combat_display() -> void:
	"""Setup display elements specific to monster combat blocks"""
	if not block_data or not block_data.monster_data:
		return

	# Setup environment effects
	for child in environment_container.get_children():
		child.queue_free()

	for e in block_data.environment:
		var env = TextureButton.new()
		environment_container.add_child(env)
		if e is FW_EnvironmentalEffect and e.texture:
			env.texture_normal = e.texture
		else:
			env.texture_normal = null
		env.custom_minimum_size = Vector2(40, 40)
		env.ignore_texture_size = true
		env.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		env.tooltip_text = e.description if e is FW_EnvironmentalEffect else ""
		env.material = shader_material()
		env.connect("pressed", do_env_popup.bind(e))

	# Set monster texture and info
	enemy_label.text = block_data.monster_data.name
	enemy_image.texture_normal = block_data.monster_data.texture

	# Connect to monster popup
	if not enemy_image.is_connected("pressed", do_monster_popup):
		enemy_image.connect("pressed", do_monster_popup.bind(block_data.monster_data))

func _setup_fog_and_skill_check() -> void:
	"""Handle fog and skill check setup from level node"""
	if not level_node:
		return

	if level_node.fog:
		node_type_image.show()
	else:
		node_type_image.hide()

	skill_check.visible = level_node.fog
	level_fog_of_war_button.visible = level_node.fog

	if level_node.fog:
		# Setup skill check if present, but defer fog material assignment for performance
		if level_node.skill_check:
			skill_check.setup(level_node.skill_check, level_name)
		else:
			# Ensure the fog clear button works
			if not level_fog_of_war_button.is_connected("pressed", _on_level_fog_of_war_button_pressed):
				level_fog_of_war_button.connect("pressed", _on_level_fog_of_war_button_pressed)

		# Do not assign any shader material here; it will be assigned lazily in _enable_expensive_effects()
		level_fog_of_war_button.material = null
		preserve_fog_shader = false
		fog_button_material = null
	else:
		level_fog_of_war_button.hide()
		level_fog_of_war_button.material = null
		# Ensure skill_check has default cursors when not used
		skill_check.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _handle_auto_drawer_logic() -> void:
	"""Handle automatic drawer opening logic"""
	if not level_node:
		return

	var debug_reachable = _is_node_reachable()
	var debug_completed = _is_node_completed()

	# Auto-open drawer if: has combat data, fog cleared, reachable, and not completed
	if block_data and not level_node.fog and debug_reachable and not debug_completed:
		should_drawer_be_open = true
		if not is_drawer_open:
			show_play_button_drawer()
	else:
		should_drawer_be_open = false

func set_path_state(reachable: bool, completed: bool = false) -> void:
	"""Set the visual state of this block based on path reachability"""
	is_reachable = reachable
	is_completed = completed

	# Apply visual states
	if completed:
		_apply_completed_state()
		# Guard: keep optimized visuals for completed tiles
		enable_performance_optimization(true)
	elif not reachable:
		_apply_unreachable_state()
		# Guard: keep optimized visuals for unreachable tiles
		enable_performance_optimization(true)
	else:
		_apply_reachable_state()

func _get_current_fog_button() -> TextureButton:
	"""Returns the correct fog button based on the node type."""
	if not level_node:
		return null

	# Dictionary mapping for cleaner code and easier maintenance
	var fog_button_map = {
		FW_LevelNode.NodeType.MONSTER: level_fog_of_war_button,
		FW_LevelNode.NodeType.PLAYER: level_fog_of_war_button,  # Players use the same fog button as monsters
		FW_LevelNode.NodeType.EVENT: event_fog_of_war_button,
		FW_LevelNode.NodeType.BLACKSMITH: blacksmith_fog_of_war_button,
		FW_LevelNode.NodeType.MINIGAME: minigame_fog_of_war_button
	}

	return fog_button_map.get(level_node.node_type, null)

func _set_all_buttons_state(enabled: bool, mouse_filter_type: Control.MouseFilter = Control.MOUSE_FILTER_PASS) -> void:
	"""Unified function to set state for all interactive buttons"""
	if event_button:
		event_button.disabled = not enabled
		event_button.mouse_filter = mouse_filter_type
	if blacksmith_button:
		blacksmith_button.disabled = not enabled
		blacksmith_button.mouse_filter = mouse_filter_type
	if minigame_button:
		minigame_button.disabled = not enabled
		minigame_button.mouse_filter = mouse_filter_type

func _is_interactive_node_type() -> bool:
	"""Check if current node type supports interactive elements like paws and completion states"""
	if not level_node:
		return false
	return level_node.node_type in [
		FW_LevelNode.NodeType.MONSTER,
		FW_LevelNode.NodeType.EVENT,
		FW_LevelNode.NodeType.PLAYER,
		FW_LevelNode.NodeType.STARTING,
		FW_LevelNode.NodeType.BLACKSMITH,
		FW_LevelNode.NodeType.MINIGAME
	]

func _apply_completed_state() -> void:
	"""Visual state for nodes that have been completed"""
	# Special case: Highlight the starting node (depth 0) only while player hasn't moved off it
	var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
	if level_node and level_node.level_depth == 0 and current_level == 0:
		active_panel.modulate = NORMAL_NODE_COLOR
		return

	active_panel.modulate = COMPLETED_NODE_COLOR
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Disable all interactive buttons for completed nodes
	_set_all_buttons_state(false, Control.MOUSE_FILTER_IGNORE)
	if minigame_button:
		minigame_button.disabled = true
		minigame_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_play_button_drawer(true)

	# Stop any dice attention when completed
	_stop_dice_attention()
	# Show paws image for completed event or level, and ensure it's fully visible
	if level_node and _is_interactive_node_type() and paws_image:
		# Show grey paw for historical completed nodes (not current position)
		if not is_current_player_position:
			paws_image.texture = load("res://Level Select/paws_selectable.png")
			paws_image.modulate = Color.WHITE
			paws_image.self_modulate = Color.WHITE
			paws_image.show()
		# If it's the current position, the green paw is already shown by set_current_tile()

func _apply_unreachable_state() -> void:
	"""Visual state for nodes that aren't on current path"""
	# Special case: Highlight the starting node (depth 0) only while player hasn't moved off it
	var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
	if level_node and level_node.level_depth == 0 and current_level == 0:
		active_panel.modulate = Color.WHITE
		return
	elif level_node and level_node.level_depth == 0 and current_level > 0:
		# Player has moved away from starting node - show grey paw
		active_panel.modulate = COMPLETED_NODE_COLOR
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if paws_image:
			paws_image.texture = load("res://Level Select/paws_selectable.png")
			paws_image.modulate = Color.WHITE
			paws_image.self_modulate = Color.WHITE
			paws_image.show()
		return

	active_panel.modulate = UNREACHABLE_NODE_COLOR
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Disable all interactive buttons for unreachable nodes
	_set_all_buttons_state(false, Control.MOUSE_FILTER_IGNORE)
	if minigame_button:
		minigame_button.disabled = true
		minigame_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fog_button = _get_current_fog_button()
	if fog_button:
		fog_button.disabled = true

	# Stop any dice attention when not interactable
	_stop_dice_attention()

	# Remove hand cursors for unreachable elements
	_set_cursor_states(false)

	if paws_image:
		paws_image.hide()

	# --- NEW LOGIC: Close the play button drawer if open and node is unreachable ---
	_close_play_button_drawer()

func _set_cursor_states(should_show_hand: bool) -> void:
	"""Set cursor states for all interactive elements based on reachability"""
	var cursor_shape = Control.CURSOR_POINTING_HAND if should_show_hand else Control.CURSOR_ARROW

	# Event button cursor
	if event_button:
		event_button.mouse_default_cursor_shape = cursor_shape

	# Minigame button cursor
	if minigame_button:
		minigame_button.mouse_default_cursor_shape = cursor_shape

	# Blacksmith button cursor
	if blacksmith_button:
		blacksmith_button.mouse_default_cursor_shape = cursor_shape

	# Start button cursor (for level nodes)
	if start_button:
		start_button.mouse_default_cursor_shape = cursor_shape

	# Fog buttons cursor
	var fog_button = _get_current_fog_button()
	if fog_button:
		fog_button.mouse_default_cursor_shape = cursor_shape

	# Level-specific cursors (for both monsters and players)
	if level_node and level_node.node_type in [FW_LevelNode.NodeType.MONSTER, FW_LevelNode.NodeType.PLAYER]:
		# Enemy image cursor
		if enemy_image:
			enemy_image.mouse_default_cursor_shape = cursor_shape

		# Environmental effects cursors (mainly for monsters, but also applies to players)
		if environment_container:
			for env in environment_container.get_children():
				if env and env.has_method("set") and "mouse_default_cursor_shape" in env:
					env.mouse_default_cursor_shape = cursor_shape

	# Skill check cursor - ensure it reflects interactivity and reachability
	# Roll dice (skill) button cursor - show hand when interactive
	if roll_dice_button:
		roll_dice_button.mouse_default_cursor_shape = cursor_shape if should_show_hand and _is_node_reachable() else Control.CURSOR_ARROW

func _apply_reachable_state() -> void:
	"""Visual state for nodes that are on current valid paths"""
	active_panel.modulate = Color.WHITE  # Normal appearance
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Starting blocks should never be clickable
	if level_node and level_node.node_type == FW_LevelNode.NodeType.STARTING:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_cursor_states(false)  # No hand cursor for starting blocks

		# Special case: Show grey paw on starting node when player has moved away
		var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
		if current_level > 0 and paws_image:
			paws_image.texture = load("res://Level Select/paws_selectable.png")
			paws_image.modulate = Color.WHITE
			paws_image.self_modulate = Color.WHITE
			paws_image.show()
		return

	# Enable buttons based on fog state and node type
	if event_button:
		event_button.disabled = false
		event_button.mouse_filter = Control.MOUSE_FILTER_STOP

	if minigame_button:
		# Only enable minigame button if fog is cleared
		var minigame_blocked_by_fog = level_node.fog
		minigame_button.disabled = minigame_blocked_by_fog
		minigame_button.mouse_filter = Control.MOUSE_FILTER_STOP if not minigame_blocked_by_fog else Control.MOUSE_FILTER_IGNORE

	if blacksmith_button:
		# Only enable blacksmith button if no fog present or if node is STARTING type
		var has_fog_blocking = level_node.fog and level_node.node_type != FW_LevelNode.NodeType.STARTING
		blacksmith_button.disabled = has_fog_blocking
		blacksmith_button.mouse_filter = Control.MOUSE_FILTER_STOP if not has_fog_blocking else Control.MOUSE_FILTER_IGNORE

	var fog_button = _get_current_fog_button()
	if fog_button and level_node.fog:
		fog_button.disabled = false

	# Set hand cursors for reachable interactive elements
	_set_cursor_states(true)

	# Add subtle glow/highlight for available paths (performance-aware)
	_add_path_highlight()

	if paws_image:
		paws_image.hide()


func _add_path_highlight() -> void:
	"""Add visual highlight to show this node is on an available path"""
	# In optimized baseline, skip adding extra highlight
	return

func fog_shader() -> ShaderMaterial:
	var shadow_material = _get_pooled_material()

	# Use lightweight fog shader for better performance across all platforms
	shadow_material.shader = _get_cached_shader("res://Shaders/shadow2.gdshader")
	shadow_material.shader = _get_cached_shader("res://Shaders/shadow2.gdshader")
	shadow_material.set_shader_parameter("cloud_speed", .4)
	shadow_material.set_shader_parameter("cloud_color", Vector4(0.05, 0.06, 0.11, 1))
	shadow_material.set_shader_parameter("cloud_highlight", Vector4(0.1, 0.12, 0.18, 1))

	return shadow_material

func setup_starting_block(node: FW_LevelNode) -> void:
	"""Setup the starting block - no interactions, just visual"""
	active_panel = starting_block
	starting_block.show()
	monster_block.hide()
	event_block.hide()

	# Starting blocks are never clickable
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set basic info
	level_name = node.name
	level_depth = node.level_depth

func _is_node_completed() -> bool:
	"""Check if this node has been completed in the current world"""
	if not level_node:
		return false

	var path_history = GDM.world_state.get_path_history(GDM.current_info.world.world_hash)

	# A node is completed if it appears in the path history at its depth
	if path_history.has(level_node.level_depth):
		var completed_node = path_history[level_node.level_depth]
		# Check if it's the same node by comparing level_hash (regeneration-safe)
		if completed_node and level_node.level_hash and completed_node.level_hash:
			return completed_node.level_hash == level_node.level_hash
		# Fallback to name comparison for older saves
		return completed_node == level_node or (completed_node and completed_node.name == level_node.name)

	return false

func _is_node_reachable() -> bool:
	"""Check if this node is currently reachable by the player using PathManager logic"""
	if not level_node:
		return false

	var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
	var path_history = GDM.world_state.get_path_history(GDM.current_info.world.world_hash)
	var depth = level_node.level_depth

	# Get the actual current position node (handles edge case after level increment)
	var current_position_node = _get_current_position_node_for_reachability(current_level, path_history)
	if not current_position_node:
		return false

	var actual_current_depth = current_position_node.level_depth

	# Use the same logic as level_backdrop_vs.gd for consistency
	if depth == 0:
		var next_completed = path_history.has(1)
		return not next_completed
	elif depth < actual_current_depth:
		return false
	elif depth == actual_current_depth:
		var depth_has_completed_node = path_history.has(depth)
		if depth_has_completed_node:
			return false

		var last_completed_node = _get_path_history_node(actual_current_depth - 1, path_history)
		if last_completed_node:
			var nodes_by_depth = _get_all_nodes_by_depth()
			var available_nodes = FW_PathManager.get_available_paths(last_completed_node, nodes_by_depth, actual_current_depth - 1)
			var in_available = _is_node_in_available_list(level_node, available_nodes)
			return in_available
		else:
			return true
	elif depth == actual_current_depth + 1:
		var nodes_by_depth = _get_all_nodes_by_depth()
		var available_nodes = FW_PathManager.get_available_paths(current_position_node, nodes_by_depth, actual_current_depth)
		var in_available = _is_node_in_available_list(level_node, available_nodes)
		return in_available
	else:
		return false

func _get_current_position_node_for_reachability(current_level: int, path_history: Dictionary) -> FW_LevelNode:
	"""Get the current position node, handling edge cases for event completions"""
	var current_node = _get_path_history_node(current_level, path_history)

	# Handle edge case: current_level incremented but no node completed at that level yet
	# (e.g., after event completion)
	if not current_node and current_level > 0:
		current_node = _get_path_history_node(current_level - 1, path_history)

	return current_node

func _get_path_history_node(level: int, path_history: Dictionary) -> FW_LevelNode:
	"""Get node from path history at specified level"""
	if path_history.has(level):
		return path_history[level]
	return null

func _get_all_nodes_by_depth() -> Dictionary:
	"""Get all nodes by depth from the current world state"""
	# This is a bit of a hack - we need access to the full node tree
	# In a better design, this would be passed to the block or stored globally
	var current_hash = GDM.current_info.world.world_hash
	var root_node = GDM.world_state.get_level_data(current_hash)
	if root_node and root_node.name != "":
		return FW_LevelGenerator.collect_nodes_by_depth(root_node)
	else:
		# Try to regenerate the level if possible
		if GDM.world_state and GDM.world_state.get_level_gen_params(current_hash).size() > 0:
			var gen_params = GDM.world_state.get_level_gen_params(current_hash)
			# Generate level structure but don't overwrite saved monster/event data
			var regenerated_root = GDM.generate_new_level(current_hash, gen_params, true)
			if regenerated_root:
				# CRITICAL: Apply saved progress to regenerated level
				GDM._apply_saved_progress_to_level(regenerated_root, current_hash)
				return FW_LevelGenerator.collect_nodes_by_depth(regenerated_root)

		#var save_keys = "No save data"
		#if GDM.world_state and GDM.world_state.save:
		#	save_keys = str(GDM.world_state.save.keys())
		printerr("Shouldn't get here error - unable to retrieve or regenerate level data")
		return {}

func _is_node_in_available_list(target_node: FW_LevelNode, available_nodes: Array) -> bool:
	"""Check if target_node is in available_nodes by comparing level_hash"""
	if not target_node:
		return false
	for available_node in available_nodes:
		if available_node and available_node.level_hash == target_node.level_hash:
			return true
	return false

func setup_monster_block(node: FW_LevelNode) -> void:
	active_panel = monster_block
	# Heavy dice pulse removed for level select

	level_name_label.text = node.display_name
	level_depth_label.text = str(node.level_depth)
	level_name = node.name
	level_depth = node.level_depth

	# Update completion state after setup
	_update_level_completion_state()

	if name != "Blank":
		for e in node.environment:
			var env = TextureButton.new()
			environment_container.add_child(env)
			if e is FW_EnvironmentalEffect and e.texture:
				env.texture_normal = e.texture
			else:
				env.texture_normal = null # or a default texture
			env.ignore_texture_size = true
			env.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			env.custom_minimum_size = Vector2(40, 40)
			# Cursor will be set by _set_cursor_states() based on reachability
			env.connect("pressed", do_env_popup.bind(e))
		monster_res = node.monster
		enemy_label.text = node.monster.name
		enemy_image.texture_normal = node.monster.texture
		# Cursor will be set by _set_cursor_states() based on reachability
		enemy_image.connect("pressed", do_monster_popup.bind(node.monster))
		# Set the node_type_image based on monster type
		if node.monster:
			var icon = MONSTER_TYPE_ICONS.get(node.monster.type, null)
			node_type_image.texture = icon

		# Hide node_type_image if fog is cleared
		if node.fog:
			node_type_image.show()
		else:
			node_type_image.hide()
		# Fog button and skill check visibility
		skill_check.visible = node.fog
		level_fog_of_war_button.visible = node.fog
		if node.fog:
			if level_node.skill_check:
				skill_check.setup(level_node.skill_check, level_name)
			else:
				if not level_fog_of_war_button.is_connected("pressed", _on_level_fog_of_war_button_pressed):
					level_fog_of_war_button.connect("pressed", _on_level_fog_of_war_button_pressed)
			# Defer shader material assignment to _enable_expensive_effects()
			level_fog_of_war_button.material = null
			preserve_fog_shader = false
			fog_button_material = null
		else:
			level_fog_of_war_button.hide()
			level_fog_of_war_button.material = null

		# --- NEW LOGIC: auto-pop drawer if monster, fog cleared, reachable, and NOT completed ---
		var debug_reachable = _is_node_reachable()
		var debug_completed = _is_node_completed()
		if node.monster and not node.fog and debug_reachable and not debug_completed:
			should_drawer_be_open = true
			if not is_drawer_open:
				show_play_button_drawer()
		else:
			should_drawer_be_open = false
	else:
		start_button.connect("pressed", _on_start_button_pressed)
		level_fog_of_war_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monster_block.show()

func setup_blacksmith_block(node: FW_LevelNode) -> void:
	active_panel = blacksmith_block
	blacksmith_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# Set the basic info
	level_node = node
	level_name = node.name
	level_depth = node.level_depth

	# Set labels - use the ones that exist in the scene
	if blacksmith_label:
		blacksmith_label.text = "Blacksmith"

	# Handle fog state for blacksmith blocks
	if node.fog:
		blacksmith_fog_of_war_button.show()
		blacksmith_fog_of_war_button.material = null
		# Fog button state will be set by path state system (reachable/unreachable)
		node_type_image.texture = BLACKSMITH_ICON
		node_type_image.show()
		# Disable blacksmith button when fog is present
		blacksmith_button.disabled = true
		blacksmith_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blacksmith_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		blacksmith_fog_of_war_button.hide()
		blacksmith_fog_of_war_button.material = null
		node_type_image.hide()
		# Button state will be set by path state system (reachable/unreachable)

	# Connect the blacksmith button if not already connected
	if not blacksmith_button.is_connected("pressed", _on_blacksmith_button_pressed):
		blacksmith_button.connect("pressed", _on_blacksmith_button_pressed)

	blacksmith_block.show()

	# Update completion state after setup
	_update_blacksmith_completion_state()

func _update_blacksmith_completion_state() -> void:
	"""Update visual state based on blacksmith completion"""
	if not level_node:
		return

	var node_is_completed = _is_node_completed()
	if node_is_completed:
		_apply_completed_state()

func _on_blacksmith_fog_of_war_button_pressed() -> void:
	_on_fog_of_war_button_pressed(blacksmith_fog_of_war_button)

func setup_event_block(node: FW_LevelNode) -> void:
	active_panel = event_block
	event_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# Cursor will be set by _set_cursor_states() based on reachability
	event = node.event

	# Ensure event UI is visible in case a prior minigame hid it
	var event_margin := event_block.get_node_or_null("MarginContainer")
	if event_margin:
		event_margin.show()
	event_button.show()
	event_fog_of_war_button.show()

	if node.event:
		var color = event.get_type_color()
		var mat = ShaderMaterial.new()
		mat.shader = load("res://Shaders/hightlight_glow.gdshader")
		mat.set_shader_parameter("glow_color", color)
		event_image.texture = EVENT_ICON
		event_image.modulate = color
		event_image.material = mat
		event_name.text = "Random Event" # event.name

	# Handle fog state for event blocks (persistently)
	if node.fog:
		event_fog_of_war_button.show()
		# Defer fog material assignment for performance; only connect pressed
		if not event_fog_of_war_button.is_connected("pressed", _on_event_fog_of_war_button_pressed):
			event_fog_of_war_button.connect("pressed", _on_event_fog_of_war_button_pressed)
		event_fog_of_war_button.material = null
		# Cursor will be set by _set_cursor_states() based on reachability
		event_fog_of_war_button.disabled = false
		node_type_image.texture = EVENT_ICON
		node_type_image.show()
	else:
		event_fog_of_war_button.hide()
		event_fog_of_war_button.material = null
		node_type_image.hide()

	event_block.show()

	# Update completion state after setup
	_update_event_completion_state()

func setup_minigame_block(node: FW_LevelNode) -> void:
	active_panel = mini_game_block
	level_node = node
	level_name = node.name
	level_depth = node.level_depth

	# Hide other block UIs and reuse the event panel container
	monster_block.hide()
	starting_block.hide()
	blacksmith_block.hide()
	event_block.hide()
	mini_game_block.show()

	# Title/icon
	var display_label := "Minigame"
	if block_data and block_data.display_name != "":
		display_label = block_data.display_name
	elif node and node.display_name != "":
		display_label = node.display_name

	minigame_name.text = display_label
	minigame_image.texture = MINIGAME_ICON

	# Fog handling
	if node.fog:
		minigame_fog_of_war_button.show()
		minigame_fog_of_war_button.material = null
		if not minigame_fog_of_war_button.is_connected("pressed", _on_minigame_fog_of_war_button_pressed):
			minigame_fog_of_war_button.connect("pressed", _on_minigame_fog_of_war_button_pressed)
		node_type_image.texture = MINIGAME_ICON
		node_type_image.show()
		minigame_button.disabled = true
		minigame_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		minigame_fog_of_war_button.hide()
		minigame_fog_of_war_button.material = null
		node_type_image.hide()
		minigame_button.disabled = false
		minigame_button.mouse_filter = Control.MOUSE_FILTER_STOP

	if not minigame_button.is_connected("pressed", _on_minigame_button_pressed):
		minigame_button.connect("pressed", _on_minigame_button_pressed)

	_update_minigame_completion_state()

func _update_event_completion_state() -> void:
	"""Update the visual state of this event block based on completion status"""
	if not level_node or not level_node.event:
		return

	# Check completion status and disable if already completed
	if _is_node_completed():
		event_name.text = "Event Completed"
		event_button.disabled = true
		event_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Special case: Highlight the starting node (depth 0) only while player hasn't moved off it
		var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
		if level_node.level_depth == 0 and current_level == 0:
			active_panel.modulate = Color.WHITE
		else:
			active_panel.modulate = Color(0.3, 0.3, 0.3)  # Dim completed events
	elif not _is_node_reachable():
		# Event is not yet reachable
		event_button.disabled = true
		event_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Special case: Highlight the starting node (depth 0) only while player hasn't moved off it
		var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
		if level_node.level_depth == 0 and current_level == 0:
			active_panel.modulate = Color.WHITE
		else:
			active_panel.modulate = Color(0.5, 0.5, 0.5, 1)  # Gray out unreachable events
	else:
		# Event is available
		event_button.disabled = false
		event_button.mouse_filter = Control.MOUSE_FILTER_STOP
		active_panel.modulate = Color.WHITE  # Normal appearance

func _update_level_completion_state() -> void:
	"""Update the visual state of this level block based on completion status"""
	if not level_node:
		return

	# Skip non-combat/event nodes
	if level_node.node_type == FW_LevelNode.NodeType.MINIGAME:
		return

	# Check completion status and disable if already completed
	if _is_node_completed():
		event_name.text = "Event Completed"
		event_button.disabled = true
		event_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Special case: Highlight the starting node (depth 0) only while player hasn't moved off it
		var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
		if level_node.level_depth == 0 and current_level == 0:
			active_panel.modulate = Color.WHITE
		else:
			active_panel.modulate = Color(0.3, 0.3, 0.3)  # Dim completed events
		# Show grey paw for historical completed nodes (not current position)
		if paws_image and not is_current_player_position:
			paws_image.texture = load("res://Level Select/paws_selectable.png")
			paws_image.modulate = Color.WHITE
			paws_image.self_modulate = Color.WHITE
			paws_image.show()
		# If it's the current position, the green paw is already shown by set_current_tile()
		_close_play_button_drawer(true)
	elif not _is_node_reachable():
		# Event is not yet reachable
		event_button.disabled = true
		event_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Special case: Highlight the starting node (depth 0) only while player hasn't moved off it
		var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
		if level_node.level_depth == 0 and current_level == 0:
			active_panel.modulate = Color.WHITE
		else:
			active_panel.modulate = Color(0.5, 0.5, 0.5, 1)  # Gray out unreachable events
		if paws_image:
			paws_image.hide()
	else:
		# Event is available
		event_button.disabled = false
		event_button.mouse_filter = Control.MOUSE_FILTER_STOP
		active_panel.modulate = Color.WHITE  # Normal appearance
		if paws_image:
			paws_image.hide()

func _on_minigame_button_pressed() -> void:
	# Avoid duplicate interactions
	if _is_node_completed():
		return
	if not _is_node_reachable():
		return
	if level_node and level_node.fog:
		return
	if GDM.player_action_in_progress:
		return

	GDM.player_action_in_progress = true
	GDM.current_info.level = level_node
	_start_minigame()

func _on_minigame_fog_of_war_button_pressed() -> void:
	_on_fog_of_war_button_pressed(minigame_fog_of_war_button)

func _update_minigame_completion_state() -> void:
	"""Update visual/interaction state for minigame nodes"""
	if not level_node or level_node.node_type != FW_LevelNode.NodeType.MINIGAME:
		return

	if _is_node_completed():
		minigame_button.disabled = true
		minigame_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_panel.modulate = COMPLETED_NODE_COLOR
		var current_level = GDM.world_state.get_current_level(GDM.current_info.world.world_hash)
		if level_node.level_depth == 0 and current_level == 0:
			active_panel.modulate = Color.WHITE
		elif paws_image and not is_current_player_position:
			paws_image.texture = load("res://Level Select/paws_selectable.png")
			paws_image.modulate = Color.WHITE
			paws_image.self_modulate = Color.WHITE
			paws_image.show()
		_close_play_button_drawer(true)
	elif not _is_node_reachable():
		minigame_button.disabled = true
		minigame_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_panel.modulate = UNREACHABLE_NODE_COLOR
		if paws_image:
			paws_image.hide()
	else:
		minigame_button.disabled = level_node.fog
		minigame_button.mouse_filter = Control.MOUSE_FILTER_STOP if not level_node.fog else Control.MOUSE_FILTER_IGNORE
		active_panel.modulate = NORMAL_NODE_COLOR
		if paws_image:
			paws_image.hide()

func _on_event_button_pressed() -> void:
	# Don't allow triggering events that have already been completed
	if _is_node_completed():
		return

	# Only allow clicking events that are currently reachable
	if not _is_node_reachable():
		return

	# Prevent concurrent actions
	if GDM.player_action_in_progress:
		return
	GDM.player_action_in_progress = true

	# Proceed to set current level and emit event trigger
	GDM.current_info.level = level_node
	EventBus.trigger_event.emit(event)

func do_monster_popup(m: FW_Monster_Resource) -> void:
	EventBus.show_monster.emit(m)

func _do_player_popup(player_data) -> void:
	"""Show player info popup using the generified CombatantDisplayPrefab"""
	# For now, we can emit to the same monster display system since it's now unified
	# The display prefab will handle the player vs monster logic internally
	if player_data is FW_Combatant:
		EventBus.show_player_combatant.emit(player_data)
	else:
		# Fallback for BlockDisplayData
		EventBus.show_player_combatant.emit(player_data.player_data)

func do_env_popup(e: FW_EnvironmentalEffect) -> void:
	EventBus.environment_inspect.emit(e)

func burn_shader_material() -> ShaderMaterial:
	var shader := _get_pooled_material()
	shader.shader = _get_cached_shader("res://Shaders/Burn.gdshader")
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	shader.set_shader_parameter("dissolve_value", 1.0)
	shader.set_shader_parameter("burn_size", .23)
	shader.set_shader_parameter("burn_color", Color.RED)
	shader.set_shader_parameter("dissolve_texture", nt)
	return shader

func shader_material() -> ShaderMaterial:
	var shader := _get_pooled_material()
	shader.shader = _get_cached_shader("res://Shaders/BorderHilight.gdshader")
	shader.set_shader_parameter("outline_color", Color.YELLOW)
	shader.set_shader_parameter("outline_thickness", 5.0)
	return shader

func _start_minigame() -> void:
	if not level_node:
		GDM.player_action_in_progress = false
		return

	if level_node.minigame_path == "":
		GDM.player_action_in_progress = false
		return

	var map_hash = GDM.current_info.world.world_hash

	# Ensure fog is cleared persistently before leaving the map
	if level_node.fog:
		level_node.fog = false
		GDM.mark_fog_cleared(map_hash, level_node.level_hash, true)
		GDM.world_state.update_fog(map_hash, level_node.fog)

	GDM.current_info.level = level_node
	GDM.previous_scene_path = get_tree().current_scene.scene_file_path

	# Persist state before swapping scenes
	GDM.vs_save()
	GDM.player_action_in_progress = false
	ScreenRotator.change_scene(level_node.minigame_path)

func _start_level() -> void:
	GDM.skill_check_in_progress = false
	GDM.player_action_in_progress = false  # Allow other actions again after battle

	# Handle different block types
	if block_data and block_data.is_player_block():
		# PvP battle setup using world_map pattern
		_start_pvp_battle()
	else:
		# Regular monster battle
		_start_monster_battle()

func _start_monster_battle() -> void:
	"""Start a regular monster battle"""
	# Set the monster as the one to be fought
	# Save the level name etc so we can maybe mark it as complete afterwards
	GDM.current_info.level = level_node

	# Use block_data.monster_data if available (new system), fallback to monster_res (legacy)
	if block_data and block_data.monster_data:
		GDM.monster_to_fight = block_data.monster_data
	elif monster_res:
		GDM.monster_to_fight = monster_res
	else:
		return

	GDM.current_info.environmental_effects = level_node.environment if level_node else []

	if level_node:
		level_node.fog = false
		# Track fog clearing for persistent level state
		var map_hash = GDM.current_info.world.world_hash
		GDM.mark_fog_cleared(map_hash, level_node.level_hash, true)
		GDM.world_state.update_fog(map_hash, level_node.fog)

	GDM.vs_save()
	ScreenRotator.change_scene("res://Scenes/gamewindow_type2.tscn")

func _start_pvp_battle() -> void:
	"""Start a PvP battle (based on world_map._setup_pvp_match_against_opponent)"""
	if not block_data or not block_data.player_data:
		return

	var opponent = block_data.player_data

	# Convert opponent to monster format for compatibility with existing battle system
	var monster_resource = _create_monster_from_combatant(opponent)
	if not monster_resource:
		return

	GDM.monster_to_fight = monster_resource

	# Set game mode to VS
	GDM.game_mode = GDM.game_types.vs

	# Use the actual level node from the generated tree (not a temporary one)
	GDM.current_info.level = level_node
	GDM.current_info.environmental_effects = level_node.environment if level_node else []

	# Save state and transition to battle
	GDM.vs_save()
	ScreenRotator.change_scene("res://Scenes/gamewindow_type2.tscn")

func _create_monster_from_combatant(combatant: FW_Combatant) -> FW_Monster_Resource:
	"""Convert a Combatant (downloaded player) to Monster_Resource for battle compatibility"""
	var monster = FW_Monster_Resource.new()

	# Basic properties
	monster.name = combatant.name + " (Player)"
	monster.description = combatant.description
	monster.texture = combatant.texture
	monster.affinities = combatant.affinities
	monster.abilities = combatant.abilities

	# Calculate stats from combatant
	if combatant.stats:
		monster.is_pvp_monster = true  # Flag this as a PvP monster
		monster.stats = combatant.stats
		monster.max_hp = combatant.get_max_hp()
		monster.shields = combatant.get_max_shields()
	else:
		# Fallback values for PvP
		monster.max_hp = 100
		monster.shields = 0

	# Set AI type for PvP opponent
	monster.ai_type = combatant.ai_type

	# Set monster type based on difficulty/level
	if combatant.difficulty_level > 50:
		monster.type = FW_Monster_Resource.monster_type.BOSS
	elif combatant.difficulty_level > 25:
		monster.type = FW_Monster_Resource.monster_type.ELITE
	elif combatant.difficulty_level > 10:
		monster.type = FW_Monster_Resource.monster_type.GRUNT
	else:
		monster.type = FW_Monster_Resource.monster_type.SCRUB

	# Set subtype (could be based on character class or randomized)
	monster.subtype = FW_Monster_Resource.monster_subtype.MERCENARY

	# Set XP reward based on level
	monster.xp = combatant.difficulty_level * 10

	return monster

func _close_play_button_drawer(hide_start_button: bool = false) -> void:
	if hide_start_button and start_button:
		start_button.hide()
		start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not is_drawer_open:
		should_drawer_be_open = false
		return

	var tween = get_tree().create_tween()
	tween.tween_property(button_container, "position", closed_position, 0.4).set_trans(Tween.TRANS_SPRING)
	is_drawer_open = false
	if start_button:
		start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_image.material = null
	for e in environment_container.get_children():
		e.material = null
	should_drawer_be_open = false

# Utility to programmatically open the play button drawer
func show_play_button_drawer() -> void:
	if is_drawer_open:
		return
	var tween = get_tree().create_tween()
	tween.tween_property(button_container, "position", open_position, 0.4).set_trans(Tween.TRANS_SPRING)
	is_drawer_open = true
	if start_button:
		start_button.show()
		start_button.mouse_filter = Control.MOUSE_FILTER_STOP
	enemy_image.material = shader_material()
	for e in environment_container.get_children():
		e.material = shader_material()

func _on_level_fog_of_war_button_pressed() -> void:
	_on_fog_of_war_button_pressed(level_fog_of_war_button)

func _on_event_fog_of_war_button_pressed() -> void:
	_on_fog_of_war_button_pressed(event_fog_of_war_button)

func _on_fog_of_war_button_pressed(button: TextureButton) -> void:
	if not level_node:
		return

	# Prevent concurrent actions
	if GDM.player_action_in_progress:
		return
	GDM.player_action_in_progress = true

	# Update the underlying data model to permanently clear the fog
	if active_panel == event_block or active_panel == blacksmith_block or active_panel == mini_game_block:
		level_node.fog = false

		# Track fog clearing for persistent level state
		var map_hash = GDM.current_info.world.world_hash
		GDM.mark_fog_cleared(map_hash, level_node.level_hash, true)

		GDM.world_state.update_fog(map_hash, level_node.fog)
		GDM.vs_save()

	# Perform the visual effect
	button.material = burn_shader_material()
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween = get_tree().create_tween()
	tween.tween_property(button.material, "shader_parameter/dissolve_value", 0, 0.4)
	tween.connect("finished", Callable(self, "_on_fog_burned_off").bind(button))
	tween.play()
	node_type_image.hide()

func _on_fog_burned_off(button: TextureButton) -> void:
	# Hide the fog button and node_type_image after burn animation completes
	button.hide()
	button.material = null
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node_type_image.hide()

	GDM.player_action_in_progress = false  # Allow other actions again

	# Handle specific node type behaviors after fog clearing
	if active_panel == blacksmith_block:
		# For blacksmith nodes, make the blacksmith button accessible
		blacksmith_button.disabled = false
		blacksmith_button.mouse_filter = Control.MOUSE_FILTER_STOP
	elif active_panel == event_block:
		# For event nodes, make the event button accessible
		event_button.disabled = false
		event_button.mouse_filter = Control.MOUSE_FILTER_STOP
	elif active_panel == mini_game_block:
		minigame_button.disabled = false
		minigame_button.mouse_filter = Control.MOUSE_FILTER_STOP

	# If this node exposes a skill check UI, draw attention to the dice with cheap color cycling
	if skill_check and skill_check.is_inside_tree():
		_start_dice_attention()

func _on_skill_check_result(result: bool, skill: FW_SkillCheckRes) -> void:
	level_node.fog = false

	# Track fog clearing for persistent level state
	var map_hash = GDM.current_info.world.world_hash
	GDM.mark_fog_cleared(map_hash, level_node.level_hash, true)

	GDM.world_state.update_fog(map_hash, level_node.fog)
	GDM.vs_save()
	if result:
		# Stop dice attention now that the skill check is resolved
		_stop_dice_attention()
		melt_card()
		# Gain XP here
		var xp_value: int = skill.get_xp_value()
		GDM.level_manager.add_xp(xp_value)
		EventBus.gain_xp.emit(xp_value)
		show_play_button_drawer()
	else:
		# Stop dice attention on failure path as well
		_stop_dice_attention()
		GDM.set_initiative_winner(GDM.Initiative.MONSTER)
		var notification_screen = get_tree().root.find_child("BattleNotificationScreen", true, false)
		if notification_screen:
			notification_screen.battle_notification()
			notification_screen.battle_notification_over.connect(_start_level, CONNECT_ONE_SHOT)
		#else:
			#_start_level()

# Lightweight dice attention (shader-free). Safe on Steam Deck and low GPU.
func _start_dice_attention() -> void:
	if not roll_dice_button:
		return

	# Don't double-start
	_stop_dice_attention()

	# Capture original visuals to restore later
	dice_original_modulate = roll_dice_button.modulate
	dice_original_scale = roll_dice_button.scale
	dice_original_self_modulate = roll_dice_button.self_modulate

	# Capture child modulates and self_modulates (so underlying image also pulses)
	dice_child_original_modulates.clear()
	for child in roll_dice_button.get_children():
		if child is CanvasItem:
			dice_child_original_modulates.append({"node": child, "modulate": child.modulate, "self_modulate": child.self_modulate})

	# Determine the skill color (fallback to white) and apply an immediate tint so labels match
	var skill_color: Color = Color(1,1,1,1)
	if skill_check and skill_check.skill:
		skill_color = skill_check.skill.color
		# Apply to both modulate and self_modulate so texture and children follow where possible
		roll_dice_button.modulate = skill_color
		roll_dice_button.self_modulate = skill_color

		# If direct modulate doesn't visually affect the button texture on some platforms,
		# create a cheap shader overlay TextureRect that multiplies the dice texture by the color.
		var overlay_name := "dice_color_overlay"
		var overlay = roll_dice_button.get_node_or_null(overlay_name)
		if overlay == null:
			overlay = TextureRect.new()
			overlay.name = overlay_name
			overlay.texture = roll_dice_button.texture_normal
			overlay.ignore_texture_size = true
			overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Anchor overlay to full rect with zero margins
			overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sh := _get_cached_shader("res://Shaders/tint.gdshader")
			var sm := ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("tint_color", skill_color)
			overlay.material = sm
			# Add the overlay and move it to the bottom so label and other UI elements remain visible
			roll_dice_button.add_child(overlay)
			# Ensure the overlay is drawn behind the label (index 0 = back)
			roll_dice_button.move_child(overlay, 0)
		else:
			# Update overlay texture and tint if it already exists
			overlay.texture = roll_dice_button.texture_normal
			if overlay.material and overlay.material is ShaderMaterial:
				overlay.material.set_shader_parameter("tint_color", skill_color)

	# Use the skill color (or a lightened variant) for attention so visuals match
	var diag_tween = create_tween()
	var diag_tint := skill_color
	# Tint the main button too so we can see it
	diag_tween.tween_property(roll_dice_button, "modulate", diag_tint, 0.08)
	# Iterate the button and all descendants (stack-based) so we catch direct children and deeper nodes
	var to_visit := [roll_dice_button]
	while to_visit.size() > 0:
		var n = to_visit.back()
		to_visit.pop_back()
		if n is CanvasItem:

			diag_tween.parallel().tween_property(n, "modulate", diag_tint, 0.08)
		# push children to stack for traversal
		for c in n.get_children():
			to_visit.append(c)

	# revert tint quickly so it's noticeable but brief
	diag_tween.tween_property(roll_dice_button, "modulate", dice_original_modulate, 0.12)
	for entry in dice_child_original_modulates:
		var node = entry["node"]
		if node and node is CanvasItem:
			diag_tween.parallel().tween_property(node, "modulate", entry["modulate"], 0.12)


	# After the diagnostic finishes, proceed with the normal bounce+modulate sequence
	diag_tween.finished.connect(func():
		# proceed with attention sequence
		# First: small bounce (finite), then start gentle modulate loop
		var bump_scale := dice_original_scale * 1.06
		# Create a gentle highlight based on skill color (blend towards white for a visible pulse)
		var warm_tint: Color = skill_color.lerp(Color(1,1,1,1), 0.3)

		# Create bounce tween (finite loops)
		if dice_bounce_tween and dice_bounce_tween.is_valid():
			dice_bounce_tween.kill()
			dice_bounce_tween = null

		dice_bounce_tween = create_tween()
		dice_bounce_tween.set_trans(Tween.TRANS_SINE)
		dice_bounce_tween.set_ease(Tween.EASE_IN_OUT)
		dice_bounce_tween.set_loops(4)

		# Scale up then back per loop
		dice_bounce_tween.tween_property(roll_dice_button, "scale", bump_scale, 0.18)
		dice_bounce_tween.tween_property(roll_dice_button, "scale", dice_original_scale, 0.18)

		# When bounce finishes, start modulate loop
		dice_bounce_tween.finished.connect(func():
			# cleanup bounce ref
			dice_bounce_tween = null
			# Start continuous modulate + self_modulate tween
			if dice_attention_tween and dice_attention_tween.is_valid():
				return
			dice_attention_tween = create_tween()
			dice_attention_tween.set_trans(Tween.TRANS_SINE)
			dice_attention_tween.set_ease(Tween.EASE_IN_OUT)
			dice_attention_tween.set_loops() # infinite
			# Animate main button both modulate and self_modulate
			dice_attention_tween.tween_property(roll_dice_button, "modulate", warm_tint, 0.5)
			dice_attention_tween.tween_property(roll_dice_button, "modulate", dice_original_modulate, 0.6)
			dice_attention_tween.parallel().tween_property(roll_dice_button, "self_modulate", warm_tint, 0.5)
			dice_attention_tween.parallel().tween_property(roll_dice_button, "self_modulate", dice_original_self_modulate, 0.6)
			# Animate any CanvasItem children (e.g., TextureRects) in parallel for both modulate and self_modulate
			for entry in dice_child_original_modulates:
				var node = entry["node"]
				var orig = entry["modulate"]
				var orig_self = entry.get("self_modulate", Color(1,1,1,1))
				# parallel section: warm tint then back
				dice_attention_tween.parallel().tween_property(node, "modulate", warm_tint, 0.5)
				dice_attention_tween.parallel().tween_property(node, "modulate", orig, 0.6)
				dice_attention_tween.parallel().tween_property(node, "self_modulate", warm_tint, 0.5)
				dice_attention_tween.parallel().tween_property(node, "self_modulate", orig_self, 0.6)
		)
	)

	# play the diagnostic tween
	diag_tween.play()

	# (Diagnostic-driven sequence is started in diag_tween.finished)

func _stop_dice_attention() -> void:
	# Kill any running tweens
	if dice_attention_tween and dice_attention_tween.is_valid():
		dice_attention_tween.kill()
		dice_attention_tween = null
	if dice_bounce_tween and dice_bounce_tween.is_valid():
		dice_bounce_tween.kill()
		dice_bounce_tween = null

	# Restore visuals for the main button and any captured children
	if roll_dice_button:
		# Restore main button properties
		roll_dice_button.modulate = dice_original_modulate
		roll_dice_button.self_modulate = dice_original_self_modulate
		roll_dice_button.scale = dice_original_scale

		# Restore any child modulates and self_modulates
		for entry in dice_child_original_modulates:
			var node = entry["node"]
			if node and node is CanvasItem:
				node.modulate = entry.get("modulate", node.modulate)
				if entry.has("self_modulate"):
					node.self_modulate = entry.get("self_modulate", node.self_modulate)

		# Clear captured child state after restoring
		dice_child_original_modulates.clear()

		# Remove any runtime overlay we may have added to reliably tint the dice texture
		var overlay = roll_dice_button.get_node_or_null("dice_color_overlay")
		if overlay:
			overlay.queue_free()

func melt_card() -> void:
	var viewport := SubViewport.new()
	viewport.size = skill_check.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)
	var skill_check_copy = skill_check.duplicate()
	skill_check_copy.position = Vector2.ZERO
	viewport.add_child(skill_check_copy)

	# Wait for the duplicate to render in the viewport.
	# The original remains visible on screen during this frame.
	await get_tree().process_frame

	var tex := viewport.get_texture()

	# Create the overlay that will be animated.
	var overlay := TextureRect.new()
	overlay.texture = tex
	overlay.size = skill_check.size
	overlay.position = skill_check.get_global_rect().position - self.get_global_rect().position
	overlay.material = burn_shader_material()
	overlay.ignore_texture_size = true
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(overlay)

	# THE FIX: Hide the original *after* the overlay is in place.
	skill_check.visible = false

	# Start the animation immediately and clean up all nodes afterward.
	var tween = get_tree().create_tween()
	tween.tween_property(overlay.material, "shader_parameter/dissolve_value", 0, 1)
	tween.tween_callback(Callable(overlay, "queue_free"))
	tween.tween_callback(Callable(skill_check_copy, "queue_free"))
	tween.tween_callback(Callable(skill_check, "queue_free"))
	tween.tween_callback(func(): GDM.skill_check_in_progress = false)
	tween.play()

func _on_start_button_pressed() -> void:
	# Don't allow starting levels that have already been completed
	if _is_node_completed():
		return

	# Only allow starting levels that are currently reachable
	if not _is_node_reachable():
		return

	# Prevent concurrent actions
	if GDM.player_action_in_progress:
		return
	GDM.player_action_in_progress = true
	GDM.set_initiative_winner(GDM.Initiative.PLAYER)

	var notification_screen = get_tree().root.find_child("BattleNotificationScreen", true, false)
	if notification_screen:
		notification_screen.battle_notification()
		notification_screen.battle_notification_over.connect(_start_level, CONNECT_ONE_SHOT)
	else:
		# If notification screen isn't present, proceed immediately to start the level
		_start_level()

func _on_monster_block_mouse_entered() -> void:
	# Only highlight if the tile is selectable (reachable and not completed)
	if is_reachable and not is_completed:
		# Animate the glow color to a highlight color
		var highlight_color = FW_PathManager.get_path_color(path_difficulty).lerp(Color.GREEN, 0.5)
		if shader_rect.material and shader_rect.material is ShaderMaterial:
			var tween = get_tree().create_tween()
			tween.tween_property(shader_rect.material, "shader_parameter/glow_color", highlight_color, 0.15)


func _on_monster_block_mouse_exited() -> void:
	# Only reset highlight if the tile is selectable (reachable and not completed)
	if is_reachable and not is_completed:
		# Animate the glow color back to the normal highlight color
		var highlight_color = FW_PathManager.get_path_color(path_difficulty)
		if shader_rect.material and shader_rect.material is ShaderMaterial:
			var tween = get_tree().create_tween()
			tween.tween_property(shader_rect.material, "shader_parameter/glow_color", highlight_color, 0.15)

func get_perf_state() -> Dictionary:
	"""Lightweight snapshot of block's perf-related state for diagnostics."""
	var fog_mat := false
	var fog_btn := _get_current_fog_button()
	if fog_btn and fog_btn.material and fog_btn.material is ShaderMaterial:
		fog_mat = true
	return {
		"cur": is_current_player_position,
		"opt": is_performance_optimized,
		"visible": visible,
		"shader_rect": (shader_rect and shader_rect.material and shader_rect.material is ShaderMaterial),
		"fog_shader": fog_mat
	}


func _on_blacksmith_button_pressed() -> void:
	# Set action in progress to prevent multiple clicks
	GDM.player_action_in_progress = true
	GDM.skill_check_in_progress = false

	# Set the current level to this blacksmith node (same as events and combat)
	GDM.current_info.level = level_node

	# Trigger the blacksmith screen (character is bound in the connection)
	EventBus.trigger_blacksmith.emit()
