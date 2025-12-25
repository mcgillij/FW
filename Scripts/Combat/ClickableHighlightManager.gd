extends Node
class_name FW_ClickableHighlightManager

## Manages highlighting of clickable elements during player turn
## Applies shader-based glow effects to portraits, buffs, consumables, and environmental effects

# Highlight effect style
enum HighlightStyle {
	PULSE,      # Simple pulsing glow
	SHIMMER     # Clockwise rotating shimmer
}

# Shader material for highlighting
var highlight_shader: Shader
var highlight_materials: Dictionary = {} # Maps node paths to materials
var pulse_shader: Shader
var monster_ability_nodes: Array[TextureButton] = []
var original_materials: Dictionary = {} # Maps node paths to their original materials (or null)

# Current style
var current_style: HighlightStyle = HighlightStyle.PULSE

# Colors for different element types
const PLAYER_COLOR := Color(0.3, 0.7, 1.0, 1.0)  # Soft cyan
const MONSTER_COLOR := Color(1.0, 0.5, 0.3, 1.0)  # Soft orange
const BUFF_COLOR := Color(0.5, 1.0, 0.5, 1.0)     # Soft green
const CONSUMABLE_COLOR := Color(1.0, 0.8, 0.3, 1.0) # Soft gold
const ENV_COLOR := Color(0.8, 0.5, 1.0, 1.0)     # Soft purple

# Dimming constants
const DIM_FACTOR := 0.6  # How much to dim elements on hover (0.6 = 60% brightness)

# Tracked elements
var player_portrait: TextureButton
var monster_portrait: TextureButton
var player_buff_icons: Array[Control] = []
var monster_buff_icons: Array[Control] = []
var environmental_icons: Array[Control] = []

# State
var is_highlighting: bool = false
var is_player_turn: bool = true
var elements_discovered: bool = false  # Track if elements have been found

# Dimming state
var original_modulates: Dictionary = {}  # Maps node paths to original modulate values
var dimmed_elements: Array[Control] = []  # Currently dimmed elements
var element_dim_states: Dictionary = {}  # Maps node paths to current dim state (true = dimmed)

func _ready() -> void:
	# Load the highlight shaders
	highlight_shader = load("res://Shaders/BorderHilight.gdshader")
	pulse_shader = load("res://Shaders/BorderHilight_pulse.gdshader")

	# Connect to turn signals
	EventBus.start_of_player_turn.connect(_on_player_turn_start)
	EventBus.start_of_monster_turn.connect(_on_monster_turn_start)

	# Connect to buff bar update signals to refresh buff icons
	EventBus.player_add_buff.connect(_on_buffs_changed)
	EventBus.player_remove_buff.connect(_on_buffs_changed)
	EventBus.monster_add_buff.connect(_on_buffs_changed)
	EventBus.monster_remove_buff.connect(_on_buffs_changed)

	# Defer initial setup to ensure scene is ready
	call_deferred("_initial_setup")

func _check_initial_highlight_state() -> void:
	if GDM.game_manager and GDM.game_manager.turn_manager and elements_discovered:
		var current_is_player_turn = GDM.game_manager.turn_manager.is_player_turn()
		if current_is_player_turn and not is_highlighting:
			enable_highlighting()

func _initial_setup() -> void:
	# Find elements in the scene tree
	_find_clickable_elements()

	# Also refresh monster abilities
	_refresh_monster_abilities()

	# Start highlighting if it's player turn
	if GDM.game_manager and GDM.game_manager.turn_manager:
		is_player_turn = GDM.game_manager.turn_manager.is_player_turn()
		if is_player_turn:
			enable_highlighting()
	else:
		push_warning("TurnManager not available during initial setup")

	# Check if we need to enable highlighting immediately (in case signal was already emitted)
	_check_initial_highlight_state()

	elements_discovered = true

func _find_clickable_elements() -> void:
	"""Locate all clickable elements in the scene"""
	var root = get_tree().root

	# Find player and monster portraits
	player_portrait = _find_node_by_unique_name(root, "character_image")
	monster_portrait = _find_node_by_unique_name(root, "monster_image")

	# Find buff bars
	_refresh_buff_icons()

	# Find environmental effect icons
	_refresh_environmental_icons()

	# Find monster abilities
	_refresh_monster_abilities()

	#FW_Debug.debug_log(["[HighlightManager] Monster abilities found: ", monster_ability_nodes.size()])


func _refresh_monster_abilities() -> void:
	"""Find monster ability TextureButton nodes (instances of monster_ability.gd)"""
	monster_ability_nodes.clear()

	for node in get_tree().get_nodes_in_group(""):
		# We'll instead traverse the tree and look for TextureButton nodes with the monster script
		pass

	# Recursive search for TextureButton nodes and check their script path
	var root = get_tree().root
	var stack = [root]
	while stack.size() > 0:
		var n = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
			if child is TextureButton:
				var s = null
				if child.get_script() != null:
					s = child.get_script().resource_path
					if s.find("Monsters/monster_ability.gd") != -1:
						monster_ability_nodes.append(child)
						#FW_Debug.debug_log(["[HighlightManager] Found monster ability node: ", child.name])


func _find_node_by_unique_name(node: Node, unique_name: String) -> Node:
	"""Recursively find a node by its unique name"""
	# Simple recursive search by node name. The previous implementation
	# relied on editor-only metadata and could miss runtime UI nodes.
	if node.name == unique_name:
		return node

	for child in node.get_children():
		var found = _find_node_by_unique_name(child, unique_name)
		if found:
			return found

	return null

func _refresh_buff_icons() -> void:
	"""Refresh the list of buff icons from buff bars"""
	player_buff_icons.clear()
	monster_buff_icons.clear()

	var player_buff_bar = _find_node_by_unique_name(get_tree().root, "PlayerBuffBar")
	if player_buff_bar:
		var buff_bar_container = _find_node_by_unique_name(player_buff_bar, "buff_bar")
		if buff_bar_container:
			for child in buff_bar_container.get_children():
				if child is TextureButton:
					player_buff_icons.append(child)
					#FW_Debug.debug_log(["[HighlightManager] Found player buff icon: ", child.name])

	var monster_buff_bar = _find_node_by_unique_name(get_tree().root, "MonsterBuffBar")
	if monster_buff_bar:
		var buff_bar_container = _find_node_by_unique_name(monster_buff_bar, "buff_bar")
		if buff_bar_container:
			for child in buff_bar_container.get_children():
				if child is TextureButton:
					monster_buff_icons.append(child)
					#FW_Debug.debug_log(["[HighlightManager] Found monster buff icon: ", child.name])

func _refresh_environmental_icons() -> void:
	"""Refresh the list of environmental effect icons"""
	environmental_icons.clear()

	var root = get_tree().root
	var env_holder = _find_environmental_holder(root)
	if env_holder:
		var container = env_holder.get_node_or_null("MarginContainer/Panel/MarginContainer/environment_holder")
		if container:
			for child in container.get_children():
				if child is TextureButton:
					environmental_icons.append(child)

func _find_environmental_holder(node: Node) -> Node:
	"""Find the EnvironmentalEffectsHolder node"""
	if node.name == "EnvironmentalEffectsHolder":
		return node
	for child in node.get_children():
		var found = _find_environmental_holder(child)
		if found:
			return found
	return null

func enable_highlighting() -> void:
	if is_highlighting:
		return

	is_highlighting = true

	# Apply highlights based on turn
	if is_player_turn:
		# Make sure portraits are up-to-date
		if not player_portrait or not is_instance_valid(player_portrait):
			player_portrait = _find_node_by_unique_name(get_tree().root, "character_image")
		if not monster_portrait or not is_instance_valid(monster_portrait):
			monster_portrait = _find_node_by_unique_name(get_tree().root, "monster_image")

		_apply_highlight(player_portrait, PLAYER_COLOR)
		_apply_highlight(monster_portrait, MONSTER_COLOR)

		for icon in player_buff_icons:
			_apply_highlight(icon, BUFF_COLOR)
		for icon in monster_buff_icons:
			_apply_highlight(icon, BUFF_COLOR)
		for icon in environmental_icons:
			_apply_highlight(icon, ENV_COLOR)

		# Apply to monster abilities as well
		for ability_node in monster_ability_nodes:
			_apply_highlight(ability_node, MONSTER_COLOR)

func disable_highlighting() -> void:
	"""Disable highlighting on all elements"""
	if not is_highlighting:
		return

	is_highlighting = false

	# Remove highlights
	if player_portrait and is_instance_valid(player_portrait):
		_remove_highlight(player_portrait)
	if monster_portrait and is_instance_valid(monster_portrait):
		_remove_highlight(monster_portrait)

	for icon in player_buff_icons:
		if icon and is_instance_valid(icon):
			_remove_highlight(icon)
	for icon in monster_buff_icons:
		if icon and is_instance_valid(icon):
			_remove_highlight(icon)
	for icon in environmental_icons:
		if icon and is_instance_valid(icon):
			_remove_highlight(icon)

	# Restore any dimmed elements to their original brightness
	for element in dimmed_elements:
		if element and is_instance_valid(element):
			var key = element.get_path()
			if highlight_materials.has(key):
				var mat = highlight_materials[key]
				mat.set_shader_parameter("dim_factor", 1.0)
				element_dim_states[key] = false
	dimmed_elements.clear()

func _apply_highlight(node: Control, color: Color) -> void:
	if not node or not is_instance_valid(node):
		return

	# Create or reuse material
	var mat: ShaderMaterial
	var mat_key = node.get_path()

	if mat_key in highlight_materials:
		mat = highlight_materials[mat_key]
	else:
		mat = ShaderMaterial.new()
		# Choose shader: pulse for monster abilities, regular for others
		var use_pulse = current_style == HighlightStyle.PULSE and node in monster_ability_nodes
		mat.shader = pulse_shader if use_pulse else highlight_shader
		highlight_materials[mat_key] = mat

		# Preserve original material so we can restore it on disable
		if not original_materials.has(mat_key):
			original_materials[mat_key] = node.material

	# Set shader parameters
	mat.set_shader_parameter("outline_color", color)
	mat.set_shader_parameter("outline_thickness", 2.0)
	mat.set_shader_parameter("dim_factor", 1.0)  # Start with normal brightness

	# Assign material directly to the node
	node.material = mat

	# Store original modulate and connect hover signals for dimming
	if not original_modulates.has(mat_key):
		original_modulates[mat_key] = node.modulate

	# Connect hover signals (only once per node)
	if not node.is_connected("mouse_entered", _on_element_mouse_entered):
		node.mouse_entered.connect(_on_element_mouse_entered.bind(node))
	if not node.is_connected("mouse_exited", _on_element_mouse_exited):
		node.mouse_exited.connect(_on_element_mouse_exited.bind(node))

	# Force a visual update
	node.queue_redraw()

func _remove_highlight(node: Control) -> void:
	"""Remove highlight shader from a node"""
	if not node or not is_instance_valid(node):
		return

	# Restore original material
	var key = node.get_path()
	if key in highlight_materials:
		#FW_Debug.debug_log(["[HighlightManager] Restoring original material on: ", node.name])
		var orig = null
		if original_materials.has(key):
			orig = original_materials[key]
		node.material = orig
		highlight_materials.erase(key)
		original_materials.erase(key)

func _on_player_turn_start() -> void:
	is_player_turn = true
	if elements_discovered:
		_find_clickable_elements()  # Refresh in case scene changed
		enable_highlighting()

func _on_monster_turn_start() -> void:
	is_player_turn = false
	if elements_discovered:
		disable_highlighting()

func _on_buffs_changed(_buff = null) -> void:
	if is_highlighting:
		# Refresh buff icons
		_refresh_buff_icons()
		# Reapply highlights to new icons
		if is_player_turn:
			for icon in player_buff_icons:
				_apply_highlight(icon, BUFF_COLOR)
			for icon in monster_buff_icons:
				_apply_highlight(icon, BUFF_COLOR)

func set_highlight_style(style: HighlightStyle) -> void:
	if current_style == style:
		return

	current_style = style

	# Clear existing materials to force recreation with new shader
	for node_path in highlight_materials.keys():
		var node = get_node_or_null(node_path)
		if node:
			node.material = null
	highlight_materials.clear()

	# Reapply highlights if currently active
	if is_highlighting:
		disable_highlighting()
		enable_highlighting()

func _on_element_mouse_entered(element: Control) -> void:
	if not is_highlighting or not element or not is_instance_valid(element):
		return

	var key = element.get_path()
	if highlight_materials.has(key):
		var mat = highlight_materials[key]
		mat.set_shader_parameter("dim_factor", DIM_FACTOR)
		element_dim_states[key] = true
		if element not in dimmed_elements:
			dimmed_elements.append(element)

func _on_element_mouse_exited(element: Control) -> void:
	if not element or not is_instance_valid(element):
		return

	var key = element.get_path()
	if highlight_materials.has(key):
		var mat = highlight_materials[key]
		mat.set_shader_parameter("dim_factor", 1.0)
		element_dim_states[key] = false
		dimmed_elements.erase(element)
