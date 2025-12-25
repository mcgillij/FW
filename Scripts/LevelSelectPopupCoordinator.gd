extends Node
class_name FW_LevelSelectPopupCoordinator

## Manages inspector popups for the level select screen.
## Provides dark overlay with click-outside-to-close and ESC key support.
## Works with existing CanvasLayer inspector nodes for SteamDeck compatibility.

# Reference to the current active popup (CanvasLayer node)
var current_popup: CanvasLayer = null
var current_popup_data: Dictionary = {}
var popup_original_visible: bool = false  # Track original visibility

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
	popup_layer.name = "LevelSelectPopupLayer"
	popup_layer.layer = 20  # High layer for overlay input handling
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

func show_popup(popup_canvas: CanvasLayer, popup_type: String, data: Dictionary = {}) -> void:
	"""
	Shows a popup CanvasLayer with dark overlay.

	Args:
		popup_canvas: The CanvasLayer node to display
		popup_type: String identifier for this popup (e.g., "monster", "environment")
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
	current_popup = popup_canvas
	current_popup_data = {"type": popup_type, "data": data}

	# Store original layer to restore later
	var original_layer = popup_canvas.layer
	current_popup_data["original_layer"] = original_layer

	# Store original visibility to determine if we should hide or keep visible
	popup_original_visible = popup_canvas.visible

	# For CanvasLayer popups, set them to a higher layer than overlay so they render on top (not dimmed)
	popup_canvas.layer = popup_layer.layer + 1  # Higher than overlay layer

	# Just ensure they are visible and show the overlay
	popup_canvas.visible = true

	# Show and fade in overlay
	_show_overlay()

	popup_opened.emit(popup_type)

func close_current_popup() -> void:
	"""Closes the currently active popup and hides overlay."""
	if not current_popup:
		return

	var popup_type = current_popup_data.get("type", "unknown")

	# Restore original layer
	var original_layer = current_popup_data.get("original_layer", 0)
	current_popup.layer = original_layer

	# Hide overlay first
	_hide_overlay()

	# For inspector popups, always hide them when closed
	if popup_type in ["monster", "environment"]:
		current_popup.visible = false
	else:
		# For other popups, restore original visibility state
		if popup_original_visible:
			# Popup was originally visible - keep it visible
			current_popup.visible = true
		else:
			# Popup was originally hidden - hide it
			current_popup.visible = false

	# Clear references
	current_popup = null
	current_popup_data.clear()
	popup_original_visible = false

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

func _on_overlay_clicked(event: InputEvent) -> void:
	"""Handles clicks on the overlay (click-outside-to-close)."""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is inside the popup area
			if _is_click_inside_popup(event.position):
				# Click is inside popup, don't close
				return
			# Click is outside popup, close it
			close_current_popup()

func _input(event: InputEvent) -> void:
	"""Handles ESC key for PC (Android has no ESC, so click-outside only)."""
	if event.is_action_pressed("ui_cancel") and current_popup:
		close_current_popup()
		get_viewport().set_input_as_handled()

func is_popup_open() -> bool:
	"""Returns true if any popup is currently open."""
	return current_popup != null

func _is_click_inside_popup(click_position: Vector2) -> bool:
	"""Check if the click position is inside the current popup's content area."""
	if not current_popup:
		return false
	
	var popup_type = current_popup_data.get("type", "")
	
	if popup_type == "monster":
		# For monster inspector, check if click is inside monster_container
		var monster_container = current_popup.get_node_or_null("monster_container")
		if monster_container and monster_container.visible:
			var global_rect = monster_container.get_global_rect()
			return global_rect.has_point(click_position)
	
	elif popup_type == "environment":
		# For environment inspector, check if click is inside environment_tooltip
		var environment_tooltip = current_popup.get_node_or_null("environment_tooltip")
		if environment_tooltip and environment_tooltip.visible:
			var global_rect = environment_tooltip.get_global_rect()
			return global_rect.has_point(click_position)
	
	elif popup_type == "legend":
		# For legend, check if click is inside legend_button_panel
		var legend_panel = current_popup.get_node_or_null("legend_button_panel")
		if legend_panel and legend_panel.visible:
			var global_rect = legend_panel.get_global_rect()
			return global_rect.has_point(click_position)
	
	return false

# EventBus signal handlers
func _on_show_monster_popup(monster: FW_Monster_Resource) -> void:
	"""Handle show_monster EventBus signal."""
	var monster_inspector = get_tree().root.find_child("MonsterInspector", true, false)
	if monster_inspector:
		monster_inspector.show_monster_info(monster)

func _on_show_player_popup(combatant: FW_Combatant) -> void:
	"""Handle show_player_combatant EventBus signal."""
	var monster_inspector = get_tree().root.find_child("MonsterInspector", true, false)
	if monster_inspector:
		monster_inspector.show_player_combatant_info(combatant)

func _on_show_environment_popup(effect: FW_EnvironmentalEffect) -> void:
	"""Handle environment_inspect EventBus signal."""
	var environment_inspector = get_tree().root.find_child("EnvironmentInspector", true, false)
	if environment_inspector:
		environment_inspector.show_tooltip(effect)