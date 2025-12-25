extends Node2D

# Quest Flag System:
# - NONE: FW_Quest flag hidden (no quests available for this NPC)
# - AVAILABLE: FW_Quest flag shown with YELLOW modulation (NPC has quest but player hasn't taken it)
# - IN_PROGRESS: FW_Quest flag shown with WHITE modulation (player has quest but hasn't completed it)
# - COMPLETE: FW_Quest flag shown with GREEN modulation (quest completed but not cashed in yet)
# - CASHED_IN: FW_Quest flag shown with DESATURATED GRAY (quest completed and cashed in)

signal save_scroll_value
signal level_button_pressed

@export var loaded: FW_WorldNode
@onready var level_label = %level_label
@onready var completed_label: Label = %completed_label
@onready var button: TextureButton = %levelbutton

@onready var complete_flag: TextureRect = %complete_flag
@onready var current_location: TextureRect = %current_location
@onready var quest_flag: TextureRect = %quest_flag
@onready var vendor_icon: TextureRect = %vendor_icon
@onready var blacksmith_icon: TextureRect = %blacksmith_icon
@onready var transmogrify_icon: TextureRect = %transmogrify_icon

@onready var levels_completed_label: Label = %levels_completed_label
@onready var levelbutton: TextureButton = %levelbutton

var original_material: Material
var hover_shader: ShaderMaterial = FW_Utils.shader_material()

enum QUEST_STATE {
	NONE,           # No quests available (hidden)
	AVAILABLE,      # Quest NPC here but quest not obtained yet (yellow)
	IN_PROGRESS,    # Quest obtained but not complete (white/no modulation)
	COMPLETE,       # Quest completed but not cashed in (green)
	CASHED_IN       # Quest completed and cashed in (gray)
}

func _ready() -> void:
	original_material = button.material
	# Generate hash with run seed and the node-instance name to ensure uniqueness across
	# nodes that share the same resource name (e.g., many "Prize Wheel" resource files).
	var run_seed = GDM.get_current_run_seed()
	# Duplicate the resource so we can safely mutate its runtime fields (e.g., world_hash) per instance.
	if loaded:
		loaded = loaded.duplicate(true)
	var name_for_hash := name
	if name_for_hash == null or name_for_hash == "":
		name_for_hash = loaded.name
	loaded.world_hash = hash(name_for_hash + str(loaded.type) + str(run_seed))
	if OS.is_debug_build():
		FW_Debug.debug_log(["[world_node_prefab] computed world_hash=", loaded.world_hash, "for node", name_for_hash, "resource_name=", loaded.name, "type=", loaded.type])
	if loaded.enabled:
		button.texture_normal = loaded.open_texture
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		button.texture_normal = loaded.blocked_texture
	if !level_label:
		level_label = %level_label
	if GDM.world_state.save.has(loaded.world_hash):
		if GDM.world_state.get_completed(loaded.world_hash):
			completed_label.text = "COMPLETED!!"
			complete_flag.show()
			levels_completed_label.hide()  # Hide levels completed label when fully completed
	level_label.text = str(FW_WorldNode.NODE_TYPE.keys()[loaded.type]).capitalize()
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.mouse_exited.connect(_on_button_mouse_exited)

	# Connect to quest events and update quest flag
	_connect_quest_events()
	# Defer quest flag update to ensure all @onready variables are initialized
	call_deferred("_update_quest_flag")
	# Update levels completed label
	call_deferred("_update_levels_completed_label")

	# make the doghouse smaller
	if loaded.type == FW_WorldNode.NODE_TYPE.DOG_HOUSE:
		levelbutton.stretch_mode = TextureButton.STRETCH_SCALE
		levelbutton.ignore_texture_size = true
		levelbutton.size = Vector2(100,100)
	# Show vendor/blacksmith icons based on menu entries
	if _has_menu_entry("VENDOR"):
		vendor_icon.show()
	if _has_menu_entry("BLACKSMITH"):
		blacksmith_icon.show()
	if _has_menu_entry("MAGIC_SHOP"):
		transmogrify_icon.show()

func _connect_quest_events() -> void:
	# Connect to EventBus quest signals to update quest flag when quest states change
	if has_node("/root/EventBus"):
		EventBus.quest_added.connect(_on_quest_event)
		EventBus.quest_completed.connect(_on_quest_event)
		EventBus.quest_goal_completed.connect(_on_quest_goal_event)

func _on_quest_event(_quest: FW_Quest) -> void:
	# Update quest flag when any quest event occurs
	_update_quest_flag()
	_update_levels_completed_label()

func _on_quest_goal_event(_quest: FW_Quest, _goal) -> void:
	# Update quest flag when quest goals are completed
	_update_quest_flag()
	_update_levels_completed_label()

func get_quest_state() -> QUEST_STATE:
	# Return NONE if no NPC or quest registry
	if loaded.npc_id.is_empty() or loaded.quest_registry == null:
		return QUEST_STATE.NONE

	# Get available quests for this NPC
	var available_quests = loaded.quest_registry.get_quests_for_npc(loaded.npc_id)
	if available_quests.is_empty():
		return QUEST_STATE.NONE

	# Check quest states
	var has_available_quest = false
	var has_in_progress_quest = false
	var has_completed_quest = false
	var has_cashed_in_quest = false

	for quest in available_quests:
		if QuestManager.is_already_cashed_in(quest):
			# If any quest is cashed in, mark that status (but also keep checking)
			has_cashed_in_quest = true
			continue
		elif QuestManager.has_completed_quest(quest):
			# Quest completed but not cashed in yet
			has_completed_quest = true
		elif QuestManager.do_we_already_have_it(quest):
			# Quest in progress
			has_in_progress_quest = true
		else:
			# Quest available but not taken yet
			has_available_quest = true

	# Prioritize states: Cash-ed in > Complete > In Progress > Available
	if has_cashed_in_quest:
		return QUEST_STATE.CASHED_IN
	if has_completed_quest:
		return QUEST_STATE.COMPLETE
	elif has_in_progress_quest:
		return QUEST_STATE.IN_PROGRESS
	elif has_available_quest:
		return QUEST_STATE.AVAILABLE
	else:
		return QUEST_STATE.NONE

func _update_quest_flag() -> void:
	# Safety check - make sure quest_flag is ready
	if not quest_flag:
		call_deferred("_update_quest_flag")
		return

	var quest_state = get_quest_state()

	match quest_state:
		QUEST_STATE.NONE:
			quest_flag.hide()
		QUEST_STATE.AVAILABLE:
			quest_flag.show()
			quest_flag.modulate = Color.YELLOW
		QUEST_STATE.IN_PROGRESS:
			quest_flag.show()
			quest_flag.modulate = Color.WHITE
		QUEST_STATE.COMPLETE:
			quest_flag.show()
			quest_flag.modulate = Color.GREEN
		QUEST_STATE.CASHED_IN:
			quest_flag.show()
			# desaturated gray: #9EA7B0
			quest_flag.modulate = Color.html("#9EA7B0")

func _update_levels_completed_label() -> void:
	# Safety check - make sure levels_completed_label is ready
	if not levels_completed_label:
		call_deferred("_update_levels_completed_label")
		return

	var path_history = GDM.world_state.get_path_history(loaded.world_hash)
	var levels_count = path_history.size()

	if levels_count > 0 and not GDM.world_state.get_completed(loaded.world_hash):
		# Get total levels from mission parameters
		var total_levels = _get_total_levels_for_node()
		if total_levels > 0:
			levels_completed_label.text = str(levels_count) + " / " + str(total_levels)
		else:
			levels_completed_label.text = str(levels_count)
		levels_completed_label.show()
	else:
		levels_completed_label.hide()

func _get_total_levels_for_node() -> int:
	# Use embedded mission params from the world node
	if loaded.mission_params.has("max_depth"):
		var max_depth = loaded.mission_params.max_depth
		return max_depth + 1 if max_depth > 0 else 0

	# If no mission params are found, return 0 (shouldn't happen with properly configured nodes)
	push_error("World node '" + loaded.name + "' is missing mission_params configuration!")
	return 0

func _on_levelbutton_pressed() -> void:
	if loaded.enabled:
		emit_signal("level_button_pressed", loaded)
		get_parent().emit_signal("save_scroll_value")
	else:
		emit_signal("level_button_pressed", loaded)

func _on_button_mouse_entered() -> void:
	button.material = hover_shader

func _on_button_mouse_exited() -> void:
	button.material = original_material

# Public: safely update the visual texture for doghouse nodes
func set_doghouse_texture(tex: Texture2D) -> void:
	# Update the button textures used for display. Do not modify the underlying resource.
	if not levelbutton:
		return
	# Apply texture to the various button states where appropriate
	levelbutton.texture_normal = tex
	# If pressed/hover textures are not set separately, also set them to keep visuals consistent
	levelbutton.texture_pressed = tex
	levelbutton.texture_hover = tex
	# Visuals will update automatically; no explicit redraw call needed

func _has_menu_entry(key: String) -> bool:
	for entry in loaded.menu_entries:
		if entry and String(entry.get_key()) == key:
			return true
	return false

func set_player_location(is_current: bool) -> void:
	if is_current:
		current_location.show()
	else:
		current_location.hide()
