extends TextureRect

signal save_scroll_value
signal world_map_button_pressed

@onready var tutorial_panel: Panel = %tutorial_panel
@onready var tutorial_signpost: Node2D = %tutorial_signpost

# Overlay for the tutorial modal
var _tutorial_overlay: Control = null

func _on_level_button_pressed(world_node: FW_WorldNode) -> void:
	# If this is the tutorial signpost world node resource, don't forward it to world_map (we handle toggling locally)
	if world_node and world_node.name == "tutorial_signpost":
		return
	emit_signal("world_map_button_pressed", world_node)


func _on_tutorial_signpost_pressed(_world_node: FW_WorldNode) -> void:
	# Toggle tutorial: simply show/hide the panel. World node prototypes handle hover/click behaviors
	# Toggle the tutorial panel modal. If already visible, hide. Otherwise, show overlay + panel
	if tutorial_panel.visible:
		_hide_tutorial_panel()
	else:
		_show_tutorial_panel()


func _ready() -> void:
	# Save the original material for the signpost and wire up hover effects
	if tutorial_signpost:
		# Connect to the prefab level_button_pressed so we can toggle the tutorial panel specifically
		if tutorial_signpost.has_signal("level_button_pressed"):
			tutorial_signpost.level_button_pressed.connect(_on_tutorial_signpost_pressed)

		# DEBUG: inspect prefab children and loaded resource to ensure proper setup
		if OS.is_debug_build():
			var loaded_res = tutorial_signpost.get("loaded") if tutorial_signpost.has_method("get") else null
			if loaded_res:
				FW_Debug.debug_log(["[world_1] tutorial_signpost loaded resource: ", str(loaded_res)])
				if loaded_res.open_texture:
					FW_Debug.debug_log(["[world_1] tutorial_signpost open_texture: ", str(loaded_res.open_texture.resource_path)])
				FW_Debug.debug_log(["[world_1] tutorial_signpost enabled: ", str(loaded_res.enabled)])
			# Try to make sure the internal levelbutton matches the expected texture
			var levelbutton = tutorial_signpost.get_node_or_null("levelbutton")
			if levelbutton:
				FW_Debug.debug_log(["[world_1] tutorial_signpost levelbutton exists - texture=", str(levelbutton.texture_normal), "size=", str(levelbutton.size), "visible=", str(levelbutton.visible)])
				# Ensure the button uses the loaded texture explicitly and is visible
				if loaded_res and loaded_res.open_texture:
					levelbutton.texture_normal = loaded_res.open_texture
					levelbutton.visible = true
					# Ensure texture size is applied so hover region matches texture
					if loaded_res.open_texture and loaded_res.open_texture.get_size():
						var tsize = loaded_res.open_texture.get_size()
						if levelbutton.size != tsize:
							levelbutton.size = tsize
							levelbutton.ignore_texture_size = false
					levelbutton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					# Bring the signpost above so it renders like other nodes
					tutorial_signpost.z_index = 10
					levelbutton.z_index = 11


# Per-pixel detection removed; prefab handles hover and click, so we don't need custom handlers here


func _show_tutorial_panel() -> void:
	# Create a full-screen transparent overlay that captures clicks anywhere
	if _tutorial_overlay:
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null
	var overlay := ColorRect.new()
	overlay.name = "tutorial_overlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.gui_input.connect(Callable(self, "_on_tutorial_overlay_gui_input"))
	add_child(overlay)
	_tutorial_overlay = overlay

	# Show the actual content panel above the overlay
	tutorial_panel.visible = true
	# Set z_index so the panel renders above the overlay
	# ColorRect default z_index is 0; set overlay lower and panel higher to ensure correct stacking
	overlay.z_index = 1000
	if tutorial_panel:
		tutorial_panel.z_index = overlay.z_index + 1
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_tutorial_overlay_gui_input(event: InputEvent) -> void:
	# Close the tutorial modal on any mouse button press (left, right) or touch
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_hide_tutorial_panel()


func _hide_tutorial_panel() -> void:
	if tutorial_panel:
		tutorial_panel.visible = false
	if _tutorial_overlay:
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null

func _exit_tree() -> void:
	pass
