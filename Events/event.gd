extends "res://Scripts/base_menu_panel.gd"

@onready var event_image: TextureRect = %event_image
@onready var choices_box: VBoxContainer = %choices_box
@onready var title: Label = %title
@onready var description: RichTextLabel = %description

@export var choice_prefab: PackedScene

var event: FW_EventResource
var _event_completion_handled: bool = false
var _completion_in_progress: bool = false

var _event_context_base: Dictionary = {}

func _ready() -> void:
	EventBus.trigger_event.connect(_slide_out_and_load_event)
	EventBus.process_event_result.connect(do_event_stuff)
	EventBus.choice_requires_skill_check.connect(_on_choice_requires_skill_check)

func _slide_out_and_load_event(event_p: FW_EventResource) -> void:
	if !event_p:
		return
	event = event_p

	# Build deterministic context for this event node (used for seeded view/outcomes)
	var map_hash := 0
	var level_hash := 0
	if GDM.current_info and GDM.current_info.world:
		map_hash = GDM.current_info.world.world_hash
	if GDM.current_info and GDM.current_info.level:
		level_hash = GDM.current_info.level.level_hash
	_event_context_base = {
		"run_seed": GDM.get_current_run_seed(),
		"map_hash": map_hash,
		"level_hash": level_hash,
		"event_path": event.resource_path,
	}
	# Reset completion guards for a fresh event load
	_event_completion_handled = false
	_completion_in_progress = false
	#var ph = "<no-level>"
	#if GDM.current_info.level:
	#	ph = str(GDM.current_info.level.level_hash)
	# Diagnostic: get the texture from the event resource (safe, simple access)
	var ev_tex = null
	if event:
		# EventResource exports `event_image`, direct access is safe for our resources
		ev_tex = event.event_image if event.event_image else null

	# Reset any material/previous texture, then assign and force a redraw
	event_image.material = null
	event_image.texture = null
	event_image.texture = ev_tex
	event_image.visible = true
	event_image.modulate = Color(1, 1, 1, 1)
	event_image.custom_minimum_size = Vector2(512, 512)
	# No explicit update call here; Godot will redraw the control when its texture changes
	if not event_image.texture:
		# Try reassigning on the next frame as a fallback — this helps when the texture is not yet ready
		call_deferred("_reassign_event_image", ev_tex)

	# Finalize the UI setup (create choices, description, slide in) now so the panel always appears.
	_finish_loading_event()

func _reassign_event_image(ev_tex) -> void:
	# Deferred fallback to handle cases where the engine hasn't finished preparing the texture
	event_image.texture = ev_tex

func _finish_loading_event() -> void:
	# Clear previous choices then populate UI and show the panel
	for child in choices_box.get_children():
		child.queue_free()

	# Build runtime view (do not call _init manually; events are defined by .tres + build_view)
	var view: Dictionary = {}
	if event:
		var ctx := _event_context_base.duplicate(true)
		ctx["rng"] = event.make_deterministic_rng(_event_context_base, "ui")
		view = event.build_view(ctx)

	# Static title stays on the resource; description/choices come from the view
	title.text = event.name if event else ""
	description.text = view.get(FW_EventResource.VIEW_DESCRIPTION_KEY, event.description if event else "")
	var view_choices: Array = view.get(FW_EventResource.VIEW_CHOICES_KEY, [])
	if event and view_choices:
		for choice in view_choices:
			var c = choice_prefab.instantiate()
			choices_box.add_child(c)
			c.setup(event, choice)

	# Always slide in the panel once UI is prepared
	self.slide_in()

func do_event_stuff(e, choice, skill_success: bool = true) -> void:
	# Disable all choice buttons to prevent further interactions
	for child in choices_box.get_children():
		child.choice_button.disabled = true
	# Resolve by stable choice id (choice dict includes id + text)
	var choice_text: String = ""
	if choice is Dictionary:
		choice_text = str(choice.get(FW_EventResource.CHOICE_TEXT_KEY, choice.get("choice", "")))
	# Capture pending combat buffs before we resolve this event so we can
	# show only the buffs that this event added (decoupled UI from global state)
	var prev_pending_buffs: Array = []
	if e and e.has_method("get_pending_combat_buffs"):
		var current = e.get_pending_combat_buffs()
		# Duplicate the array so downstream mutations by _apply_failure_effects don't change our copy
		prev_pending_buffs = current.duplicate() if typeof(current) == TYPE_ARRAY else []
	# Debug: show what choice string is being passed into the event resolver
	FW_Debug.debug_log(["do_event_stuff: event=", e.name if e and e.has_method("name") else str(e), " choice=<<", choice_text, ">> skill_success=", skill_success])
	var ctx := _event_context_base.duplicate(true)
	ctx["rng"] = e.make_deterministic_rng(_event_context_base, "resolve") if e and e.has_method("make_deterministic_rng") else null
	var event_resolution = e.resolve_choice(choice, skill_success, ctx) if e and e.has_method("resolve_choice") else e._event_resolve(choice_text, skill_success)
	FW_Debug.debug_log(["do_event_stuff: event_resolution=", event_resolution])
	# Determine which buffs were newly added by resolving this event
	var display_buffs: Array = []
	if e and e.has_method("get_pending_combat_buffs"):
		var new_pending = e.get_pending_combat_buffs()
		if typeof(new_pending) == TYPE_ARRAY:
			for buff in new_pending:
				if not prev_pending_buffs.has(buff):
					display_buffs.append(buff)
	# Debugging logs: show the change in pending buff arrays (useful during dev)
	if OS.is_debug_build():
		FW_Debug.debug_log([
			"event.do_event_stuff: prev_pending_count=", prev_pending_buffs.size(),
			"new_pending_count=", (e.get_pending_combat_buffs().size() if e and e.has_method('get_pending_combat_buffs') else 0),
			"display_buffs_count=", display_buffs.size()
		])
	_show_resolution_panel(event_resolution, display_buffs)

func _show_resolution_panel(event_resolution: Array, display_buffs: Array = []) -> void:
	var event_status = event_resolution[0]
	var event_text = event_resolution[1]
	var win_or_lose_text = ""
	if event_status: # you won the event
		win_or_lose_text = "You won the event!\n"
		$LootScreen.setup()
	else:
		win_or_lose_text = "You lost the event!\n"
		# Show buff previews specific to this event, if any.
		# If there are none, clear any previous buff panels so they don't persist
		# on subsequent events (we deliberately avoid showing other events' pending buffs here)
		if display_buffs and display_buffs.size() > 0:
			$LootScreen.show_buffs(display_buffs)
		else:
			$LootScreen.show_buffs([])
	$LootScreen.show_text(win_or_lose_text + event_text)
	$LootScreen.slide_in()

func on_resolution_panel_button_pressed() -> void:
	# Prevent double-clicking or rapid completion
	if _completion_in_progress:
		return
	_completion_in_progress = true

	# Handle the progression logic
	_handle_event_completion()

	# Now slide out the event panel
	self.slide_out()

	_completion_in_progress = false

func _handle_event_completion() -> void:
	"""Handle the game state updates when an event completes"""
	# Prevent double execution
	if _event_completion_handled:
		return
	_event_completion_handled = true

	# Capture current world/level node now to avoid races if GDM.current_info changes
	var map_hash = GDM.current_info.world.world_hash
	var completed_node: FW_LevelNode = GDM.current_info.level
	if not completed_node:
		printerr("_handle_event_completion: no current level set")
		return

	# Persist cleared state and path history using the captured node
	GDM.mark_node_cleared(map_hash, completed_node.level_hash, true)

	# Also mark the runtime node as cleared so UI logic that checks node.cleared sees it immediately
	completed_node.cleared = true

	# (Do not emit immediately here to avoid duplicate handling/races)

	GDM.world_state.update_path_history(
		map_hash,
		completed_node.level_depth,
		completed_node
	)
	if OS.is_debug_build():
		FW_Debug.debug_log(["[event] update_path_history - map_hash=", map_hash, "level_depth=", completed_node.level_depth, "level_hash=", completed_node.level_hash])

	var is_final_level = completed_node.level_depth == GDM.current_info.level_to_generate["max_depth"]
	if is_final_level:
		GDM.world_state.update_completed(map_hash, true)
		if OS.is_debug_build():
			FW_Debug.debug_log(["[event] update_completed for map_hash=", map_hash])

	var new_level := GDM.world_state.get_current_level(map_hash) + 1
	GDM.world_state.update_current_level(map_hash, new_level)

	GDM.vs_save() # save once event completes.

	# Ensure global action flags are cleared so UI becomes responsive again
	# The block that started the event sets GDM.player_action_in_progress = true;
	# clear it here now that the event is fully processed and saved.
	GDM.player_action_in_progress = false
	GDM.skill_check_in_progress = false

	# Emit level_completed signal with the captured node deferred to avoid race conditions
	call_deferred("_emit_completion_signal_with_node", completed_node)

func _emit_completion_signal() -> void:
	"""Emit the completion signal in a deferred manner"""
	# Backwards-compatible: emit using current_info.level if needed
	EventBus.level_completed.emit(GDM.current_info.level)


func _emit_completion_signal_with_node(node: FW_LevelNode) -> void:
	"""Emit the completion signal for a specific node (deferred)"""
	if node:
		EventBus.level_completed.emit(node)



func _on_loot_screen_back_button() -> void:
	# Prevent double-clicking or rapid completion
	if _completion_in_progress:
		return
	_completion_in_progress = true

	# First slide out the loot screen
	$LootScreen.slide_out()

	for c in choices_box.get_children():
		c.queue_free()

	# Defer the heavy completion handling until after the loot screen has started sliding out
	call_deferred("_finish_after_loot")

	# Return now; _finish_after_loot will clear _completion_in_progress when done
	return


func _finish_after_loot() -> void:
	# Finalize completion after loot UI finishes its transition
	_handle_event_completion()
	# Now slide out the main event panel
	self.slide_out()
	_completion_in_progress = false

func _on_choice_requires_skill_check(choice_node: Control, skill_res) -> void:
	# Disable all choice buttons to prevent multiple interactions
	for child in choices_box.get_children():
		child.choice_button.disabled = true

	# Guard: ensure skill_res is a Resource/SkillCheckRes
	if not (skill_res is Resource):
		printerr("_on_choice_requires_skill_check: expected Resource for skill_res, got:", typeof(skill_res), skill_res)
		EventBus.process_event_result.emit(event, choice_node.button_choice, false)
		return

	var result = await FW_SkillCheckLogic.perform_skill_check_async(skill_res, "event_skill_check")

	# Update the choice label with roll result
	var original_text = choice_node.choice_label.text
	var roll_text = "\nRoll: %d + %d = %d (%s)" % [
		result.roll, result.stat_value, result.total,
		"Success!" if result.success else "Fail!"
	]
	choice_node.choice_label.text = original_text + roll_text

	# Wait a moment to show the result
	await get_tree().create_timer(1.5).timeout

	EventBus.process_event_result.emit(event, choice_node.button_choice, result.success)
