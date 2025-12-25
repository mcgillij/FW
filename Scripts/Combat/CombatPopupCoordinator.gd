extends Node
class_name FW_CombatPopupCoordinator

## Manages all combat popup panels to ensure only one is open at a time.
## Provides dark overlay with click-outside-to-close and ESC key support.
## Works with existing Panel/Control nodes (not PopupPanel) for SteamDeck rotation compatibility.

# Reference to the current active popup (Control node - could be Panel, Control, etc.)
var current_popup: Control = null
var current_popup_data: Dictionary = {}
var popup_original_parent: Node = null  # Track original parent to restore

# Dark overlay for background
var overlay: ColorRect = null
var popup_layer: CanvasLayer = null

# Animation
var overlay_tween: Tween = null
const FADE_DURATION := 0.2

signal popup_opened(popup_type: String)
signal popup_closed(popup_type: String)

func _ready() -> void:
	_create_popup_layer()
	_create_overlay()

func _create_popup_layer() -> CanvasLayer:
	"""Creates a dedicated CanvasLayer for popups and overlay."""
	popup_layer = CanvasLayer.new()
	popup_layer.name = "CombatPopupLayer"
	popup_layer.layer = 10  # Above game content (adjust if needed)
	popup_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # Works even when paused
	add_child(popup_layer)
	return popup_layer

func _create_overlay() -> void:
	"""Creates the dark semi-transparent overlay with click detection."""
	overlay = ColorRect.new()
	overlay.name = "PopupOverlay"
	overlay.color = Color(0, 0, 0, 0)  # Start transparent (will fade in)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to game
	overlay.visible = false
	
	# Make it cover the entire viewport
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0
	
	# Connect click detection
	overlay.gui_input.connect(_on_overlay_clicked)
	
	# Add to popup layer (renders below popups due to tree order)
	popup_layer.add_child(overlay)

func show_popup(popup_panel: Control, popup_type: String, data: Dictionary = {}) -> void:
	"""
	Shows a popup panel with dark overlay.
	
	Args:
		popup_panel: The Control node to display (Panel, Control, etc.)
		popup_type: String identifier for this popup (e.g., "ability", "monster_stats")
		data: Optional metadata about this popup
	"""
	# If clicking the same popup type, toggle it off
	if current_popup and current_popup_data.get("type") == popup_type:
		close_current_popup()
		return
	
	# Close existing popup first (different type)
	if current_popup:
		close_current_popup()
	
	# Store reference
	current_popup = popup_panel
	current_popup_data = {"type": popup_type, "data": data}
	
	# Store original parent to determine if we should free or restore
	popup_original_parent = popup_panel.get_parent()
	
	# Move popup to our layer (for consistent layering)
	if popup_original_parent:
		popup_original_parent.remove_child(popup_panel)
	popup_layer.add_child(popup_panel)
	
	# Center the popup in the viewport
	_center_popup(popup_panel)
	
	# Ensure popup is visible
	popup_panel.visible = true
	
	# Show and fade in overlay
	_show_overlay()
	
	popup_opened.emit(popup_type)

func close_current_popup() -> void:
	"""Closes the currently active popup and hides overlay."""
	if not current_popup:
		return
	
	var popup_type = current_popup_data.get("type", "unknown")
	
	# Hide overlay first
	_hide_overlay()
	
	# Determine how to clean up the popup
	if popup_original_parent and is_instance_valid(popup_original_parent):
		# Popup came from scene - restore it to original parent and hide
		popup_layer.remove_child(current_popup)
		popup_original_parent.add_child(current_popup)
		current_popup.visible = false
	else:
		# Popup was dynamically created - free it
		current_popup.queue_free()
	
	# Clear references
	current_popup = null
	current_popup_data.clear()
	popup_original_parent = null
	
	popup_closed.emit(popup_type)

func _show_overlay() -> void:
	"""Fades in the dark overlay."""
	overlay.visible = true
	
	# Cancel any existing tween
	if overlay_tween:
		overlay_tween.kill()
	
	# Fade in
	overlay_tween = create_tween()
	overlay_tween.set_ease(Tween.EASE_OUT)
	overlay_tween.set_trans(Tween.TRANS_CUBIC)
	overlay_tween.tween_property(overlay, "color", Color(0, 0, 0, 0.7), FADE_DURATION)

func _hide_overlay() -> void:
	"""Fades out the dark overlay."""
	# Cancel any existing tween
	if overlay_tween:
		overlay_tween.kill()
	
	# Fade out
	overlay_tween = create_tween()
	overlay_tween.set_ease(Tween.EASE_IN)
	overlay_tween.set_trans(Tween.TRANS_CUBIC)
	overlay_tween.tween_property(overlay, "color", Color(0, 0, 0, 0), FADE_DURATION)
	
	# Hide after fade completes
	await overlay_tween.finished
	overlay.visible = false

func _center_popup(popup: Control) -> void:
	"""Centers the popup in the viewport."""
	# Reset any offscreen positioning first
	popup.position = Vector2.ZERO
	
	# Force a layout update to ensure size is calculated
	await get_tree().process_frame
	
	# Get the viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Get the popup size (try different methods)
	var popup_size = popup.size
	if popup_size == Vector2.ZERO:
		popup_size = popup.custom_minimum_size
	if popup_size == Vector2.ZERO:
		popup_size = popup.get_combined_minimum_size()
	
	# Calculate centered position
	var centered_pos = (viewport_size - popup_size) / 2.0
	
	# Ensure position is not negative (in case popup is larger than viewport)
	centered_pos.x = max(0, centered_pos.x)
	centered_pos.y = max(0, centered_pos.y)
	
	# Set the position
	popup.position = centered_pos

func _on_overlay_clicked(event: InputEvent) -> void:
	"""Handles clicks on the overlay (click-outside-to-close)."""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_current_popup()

func _input(event: InputEvent) -> void:
	"""Handles ESC key for PC (Android has no ESC, so click-outside only)."""
	if event.is_action_pressed("ui_cancel") and current_popup:
		close_current_popup()
		get_viewport().set_input_as_handled()

func is_popup_open() -> bool:
	"""Returns true if any popup is currently open."""
	return current_popup != null

func get_current_popup_type() -> String:
	"""Returns the type of the currently open popup, or empty string if none."""
	return current_popup_data.get("type", "")
