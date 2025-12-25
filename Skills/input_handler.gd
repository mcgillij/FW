extends Node

#@export var starting_skillpoints := 12
@export var skilltree : FW_WorldmapView
@export_group("Bottom Bar")
@export var skillpoint_label : Label
const SKILLPOINT_LABEL_FORMAT := "{0} Points Left"
@export var skill_reset : BaseButton
@export var stat_list : Label
@export_group("Tooltip")
@export var tooltip_root : CanvasItem
@export var tooltip_title : Label
@export var tooltip_desc : Label

@export var ability_display_tooltip: PackedScene
@onready var ability_container: VBoxContainer = %ability_container

@export_group("Adding Nodes")
@export var add_target : FW_WorldmapGraph
@export var add_node_index := 3

const TOOLTIP_WIDTH := 350.0
const TOOLTIP_MARGIN := 60.0

var stats_from_tree: Dictionary = {}
var abilities_from_tree: Array[FW_Ability] = []
var _total_points_spent: int = 0

# New: Timer for tooltip auto-hide (15 seconds)
var tooltip_timer: Timer

func _ready():
	# Don't set max_unlock_cost here - it will be set by setup() with proper data
	# skilltree.max_unlock_cost = GDM.player.skill_points - sum_values(stats_from_tree, abilities_from_tree)
	# _skillpoints_changed() will be called after setup() loads the data
	tooltip_root.hide()

	# Create and configure the tooltip timer
	tooltip_timer = Timer.new()
	tooltip_timer.wait_time = 15.0
	tooltip_timer.one_shot = true
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	add_child(tooltip_timer)

func _exit_tree() -> void:
	# Clean up any pending tooltip children safely
	if ability_container and is_instance_valid(ability_container):
		for child in ability_container.get_children():
			if is_instance_valid(child):
				child.queue_free()

	# New: Clean up the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.stop()
		tooltip_timer.queue_free()

func sum_values(skill_dict: Dictionary, abilities_arr: Array[FW_Ability]) -> int:
	if skilltree:
		return _calculate_total_points_spent()
	if _total_points_spent != 0:
		return _total_points_spent
	var total := abilities_arr.size()
	for key in skill_dict.keys():
		var value = skill_dict[key]
		if typeof(value) == TYPE_INT || typeof(value) == TYPE_FLOAT:
			total += int(value)
	return total

func _calculate_total_points_spent() -> int:
	if not skilltree:
		return _total_points_spent
	var node_states := skilltree.get_all_nodes()
	var total := 0.0
	for node_data in node_states.keys():
		if not node_data:
			continue
		total += float(node_states[node_data]) * float(node_data.cost)
	return int(roundi(total))

func _skillpoints_changed():
	# Null safety checks
	if not skilltree:
		printerr("skilltree is null in _skillpoints_changed")
		return
	if not GDM or not GDM.player:
		printerr("GDM or GDM.player is null in _skillpoints_changed")
		return
	if not skillpoint_label:
		printerr("skillpoint_label is null")
		return
	if not skill_reset:
		printerr("skill_reset is null")
		return
	if not stat_list:
		printerr("stat_list is null")
		return

	var stats_raw := skilltree.get_all_nodes()
	var invested_points := 0.0
	var stats := {}
	abilities_from_tree = []
	for k in stats_raw.keys():
		var v : int = stats_raw[k]
		if v == 0:
			continue
		if not k:
			continue
		invested_points += float(v) * float(k.cost)
		if not k.data:
			continue
		for node_data_item in k.data:
			if node_data_item is FW_SkillStats:
				stats[node_data_item.name] = int(stats.get(node_data_item.name, 0) + v * node_data_item.amount)
			elif node_data_item is FW_Ability:
				if !abilities_from_tree.has(node_data_item):
					abilities_from_tree.append(node_data_item)
	var points_remaining := int(roundi(GDM.player.skill_points - invested_points))
	if points_remaining < 0:
		printerr("Skill tree points overspent by ", -points_remaining)
		points_remaining = 0
	skilltree.max_unlock_cost = points_remaining
	_total_points_spent = int(roundi(invested_points))
	skillpoint_label.text = SKILLPOINT_LABEL_FORMAT.format([skilltree.max_unlock_cost])
	skill_reset.disabled = skilltree.max_unlock_cost >= GDM.player.skill_points
	var stat_list_text : Array[String] = []
	for k in stats:
		stat_list_text.append("%s: %s" % [k, stats[k]])
	for i in abilities_from_tree:
		stat_list_text.append("%s: unlocked" % [i.name])
	stats_from_tree = stats
	stat_list.text = "\n".join(stat_list_text)

func _on_map_node_gui_input(event : InputEvent, path : NodePath, node_in_path : int, _resource : FW_WorldmapNodeData):
	if not skilltree:
		printerr("skilltree is null in _on_map_node_gui_input")
		return
	if event is InputEventMouseMotion: # TODO: Test on phone to make sure these events work
		pass  # Removed: tooltip_root.global_position = event.global_position
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
			if skilltree.can_activate(path, node_in_path):
				tooltip_root.hide()
				# Stop timer and clean up when manually hiding
				if tooltip_timer and is_instance_valid(tooltip_timer):
					tooltip_timer.stop()
				if ability_container and is_instance_valid(ability_container):
					for i in ability_container.get_children():
						if is_instance_valid(i):
							i.queue_free()
				skilltree.max_unlock_cost -= skilltree.set_node_state(path, node_in_path, 1)
				_skillpoints_changed()
				EventBus.skilltree_select.emit()
				# Validate ability assignments when abilities are toggled
				_validate_ability_assignments_if_needed()
			# here's where we will work on the click to deactivate / substract the node.
			else:
				var node_state = skilltree.get_node_state(path, node_in_path)
				if node_state == 1:
					if can_deactivate(node_in_path) and node_in_path != 0: #never unclick the root node
						tooltip_root.hide()
						# Stop timer and clean up when manually hiding
						if tooltip_timer and is_instance_valid(tooltip_timer):
							tooltip_timer.stop()
						if ability_container and is_instance_valid(ability_container):
							for i in ability_container.get_children():
								if is_instance_valid(i):
									i.queue_free()
						skilltree.max_unlock_cost -= skilltree.set_node_state(path, node_in_path, 0)
						_skillpoints_changed()
						EventBus.skilltree_deselect.emit()
						# Validate ability assignments when abilities are deselected
						_validate_ability_assignments_if_needed()
					else:
						printerr("Cannot deactivate node; would split the graph.")
						EventBus.skilltree_deselect.emit()


func can_deactivate(target_node: int) -> bool:
	if not skilltree:
		printerr("skilltree is null in can_deactivate")
		return false
	var current_state := skilltree.get_world_state()
	# Fixed bounds check - should be < not <=
	if current_state.size() < target_node or target_node < 0:
		return false

	# Temporarily "deactivate" the node
	current_state[target_node] = 0

	# Collect all active nodes (excluding the one we're trying to deactivate)
	var active_nodes := []
	for i in current_state.size():
		if current_state[i] == 1:
			active_nodes.append(i)

	# If nothing else is active, we can deactivate freely
	if active_nodes.is_empty():
		return true

	# Run DFS/BFS from one of the remaining active nodes
	var start := 0
	var visited := {}
	var stack := [start]

	# Cache the WorldmapGraph node to avoid repeated lookups
	var worldmap_graph = %WorldmapGraph
	if not worldmap_graph:
		printerr("WorldmapGraph not found!")
		return false

	while stack.size() > 0:
		var current = stack.pop_back()
		if visited.has(current):
			continue
		visited[current] = true

		# Use cached reference instead of repeated unique name lookup
		for neighbor in worldmap_graph.get_node_neighbors(current):
			# Bounds check for safety
			if neighbor >= 0 and neighbor < current_state.size():
				if current_state[neighbor] == 1 and not visited.has(neighbor):
					stack.append(neighbor)

	# All active nodes must be in visited
	for active_node in active_nodes:
		if not visited.has(active_node):
			return false # Deactivation would split the graph

	return true


func _on_map_node_mouse_entered(_path : NodePath, _node_in_path : int, resource : FW_WorldmapNodeData):
	# Null safety check
	if not resource:
		return

	# New: Hide any existing tooltip before showing the new one
	if tooltip_root.visible:
		tooltip_root.hide()
		# Safe cleanup of previous ability display
		if ability_container and is_instance_valid(ability_container):
			for i in ability_container.get_children():
				if is_instance_valid(i):
					i.queue_free()

	tooltip_root.show()
	#FW_Debug.debug_log([resource.data])
	tooltip_title.text = resource.name
	tooltip_desc.text = resource.desc
	tooltip_root.size = Vector2.ZERO

	# New: Position tooltip at top-right of the screen (with a small margin)
	# Use fixed width of 350px for the ability panel to avoid clipping
	var viewport_size = get_viewport().get_visible_rect().size
	tooltip_root.global_position = Vector2(max(0, viewport_size.x - TOOLTIP_WIDTH - TOOLTIP_MARGIN), TOOLTIP_MARGIN)

	# Safe array access with bounds checking
	if resource.data and resource.data.size() > 0 and resource.data[0] is FW_Ability:
		if not ability_display_tooltip:
			printerr("ability_display_tooltip is null")
			return
		var ab = ability_display_tooltip.instantiate()
		ability_container.add_child(ab)
		ab.setup(resource.data[0])

	# New: Start/restart the timer
	if tooltip_timer and is_instance_valid(tooltip_timer):
		tooltip_timer.start()

func _on_map_node_mouse_exited(_path : NodePath, _node_in_path : int, _resource : FW_WorldmapNodeData):
	# New: Removed hide logic; tooltip now persists until timer expires or replaced
	pass

# New: FW_Function to handle tooltip timer timeout
func _on_tooltip_timer_timeout() -> void:
	tooltip_root.hide()
	# Safe cleanup
	if ability_container and is_instance_valid(ability_container):
		for i in ability_container.get_children():
			if is_instance_valid(i):
				i.queue_free()

func _on_reset_skills_pressed():
	if not skilltree:
		printerr("skilltree is null in _on_reset_skills_pressed")
		return
	if not GDM or not GDM.player:
		printerr("GDM or GDM.player is null in _on_reset_skills_pressed")
		return
	skilltree.max_unlock_cost = GDM.player.skill_points
	skilltree.reset()
	reset_abilities_stats()
	_skillpoints_changed()

func reset_abilities_stats() -> void:
	# Null safety checks
	if not GDM or not GDM.player:
		printerr("GDM or GDM.player not available")
		return

	# Reset cooldowns in GameManager
	if GDM.game_manager:
		if GDM.game_manager.player_cooldown_manager:
			GDM.game_manager.player_cooldown_manager.reset_cooldowns()
		if GDM.game_manager.monster_cooldown_manager:
			GDM.game_manager.monster_cooldown_manager.reset_cooldowns()

	abilities_from_tree = []
	stats_from_tree = {}
	# Use the proper reset method that handles default abilities correctly
	GDM.player.reset_abilities_for_new_character(false)
	# No need to call setup_boosters - UI systems now use GDM.player.abilities directly

func get_save_data() -> String:
	return var_to_str([
		skilltree.max_unlock_cost,
		skilltree.get_state(),
	])

func load_saved_data(data: String) -> void:
	var varr = str_to_var(data)
	if varr == null or not varr is Array or varr.size() < 2:
		printerr("Invalid save data in load_saved_data")
		return
	if not varr[0] is int or not varr[1] is Dictionary:
		printerr("Invalid save data types in load_saved_data")
		return
	if not skilltree:
		printerr("skilltree is null in load_saved_data")
		return
	skilltree.load_state(varr[1])
	_skillpoints_changed()  # Populate stats_from_tree and abilities_from_tree
	if not GDM or not GDM.player:
		printerr("GDM or GDM.player is null in load_saved_data")
		return
	var invested = sum_values(stats_from_tree, abilities_from_tree)
	skilltree.max_unlock_cost = GDM.player.skill_points - invested
	_skillpoints_changed()  # Update display with correct max_unlock_cost

func _validate_ability_assignments_if_needed() -> void:
	"""
	Check if any assigned abilities are no longer available and clear them.
	This provides immediate feedback when players toggle abilities in the skill tree.
	"""
	if not GDM or not GDM.player:
		return

	var abilities_changed = false
	var default_abilities = _get_default_abilities_for_current_character()

	# Check each assigned ability slot
	for i in range(GDM.player.abilities.size()):
		var assigned_ability = GDM.player.abilities[i]
		if assigned_ability != null:
			# An ability is valid if it's either:
			# 1. From the skill tree (in abilities_from_tree), OR
			# 2. A default ability for this character
			var is_valid = false

			# Check if it's from the skill tree
			for available_ability in abilities_from_tree:
				if available_ability != null and assigned_ability != null:
					if available_ability.name == assigned_ability.name:
						is_valid = true
						break

			# If not from skill tree, check if it's a default ability
			if not is_valid:
				for default_ability in default_abilities:
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
		# Emit signal to notify other systems (like Combined Stats screen)
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
