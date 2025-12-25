extends Node
class_name FW_CombatLogOverlay

# Utility class for showing combat log overlays in victory/defeat screens

static func show_combat_log_overlay(parent_node: Node) -> Panel:
	"""Shows a combat log overlay popup on the given parent node"""
	
	# Get reference to the combat log from the game scene
	var game_scene = parent_node.get_tree().get_first_node_in_group("game_manager")
	if not game_scene:
		FW_Debug.debug_log(["Could not find game manager"])
		return null

	var original_combat_log = game_scene.get_parent().get_node("CanvasLayer/bottomUI2/CombatLog")
	if not original_combat_log:
		FW_Debug.debug_log(["Could not find combat log"])
		return null

	# Store original properties for restoration
	var original_position = original_combat_log.position
	var original_size = original_combat_log.size
	var original_z_index = original_combat_log.z_index
	var original_visible = original_combat_log.visible
	var original_min_size = original_combat_log.custom_minimum_size

	# Create overlay panel as background
	var combat_log_overlay = Panel.new()
	
	# Size overlay to fit portrait screen (720x1280) with margins
	var viewport_size = parent_node.get_viewport().get_visible_rect().size
	combat_log_overlay.size = Vector2(min(680, viewport_size.x - 40), 550)
	
	# Center the overlay horizontally on screen
	var center_x = (viewport_size.x - combat_log_overlay.size.x) / 2
	combat_log_overlay.position = Vector2(center_x, 50)

	# Style the overlay
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style_box.border_width_left = 3
	style_box.border_width_top = 3
	style_box.border_width_right = 3
	style_box.border_width_bottom = 3
	style_box.border_color = Color(0.6, 0.6, 0.8, 1.0)
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	combat_log_overlay.add_theme_stylebox_override("panel", style_box)

	# Add title label
	var title_label = Label.new()
	title_label.text = "Combat Log - What Happened?"
	title_label.position = Vector2(10, 10)
	title_label.size = Vector2(450, 30)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	combat_log_overlay.add_child(title_label)

	# Add close button
	var close_btn = Button.new()
	close_btn.name = "close_btn"
	close_btn.text = " ✕ "
	close_btn.position = Vector2(combat_log_overlay.size.x - 40, 5)
	close_btn.size = Vector2(30, 30)
	close_btn.add_theme_font_size_override("font_size", 16)
	combat_log_overlay.add_child(close_btn)

	# Move the original combat log to the foreground by reparenting it
	original_combat_log.z_index = 1001
	original_combat_log.custom_minimum_size = Vector2(combat_log_overlay.size.x - 120, 420)  # Override minimum size
	original_combat_log.size = Vector2(combat_log_overlay.size.x - 10, 480)  # Much smaller to ensure it fits
	original_combat_log.visible = true
	
	# Store the original parent for restoration
	var original_parent = original_combat_log.get_parent()
	combat_log_overlay.set_meta("original_parent", original_parent)
	
	# Reparent the combat log to the overlay
	original_parent.remove_child(original_combat_log)
	combat_log_overlay.add_child(original_combat_log)
	
	# Center the combat log horizontally within the overlay
	var log_center_x = (combat_log_overlay.size.x - original_combat_log.size.x) / 2
	original_combat_log.position = Vector2(log_center_x, 60)

	# Store original properties for restoration
	combat_log_overlay.set_meta("original_position", original_position)
	combat_log_overlay.set_meta("original_size", original_size)
	combat_log_overlay.set_meta("original_min_size", original_min_size)
	combat_log_overlay.set_meta("original_z_index", original_z_index)
	combat_log_overlay.set_meta("original_visible", original_visible)
	combat_log_overlay.set_meta("combat_log_ref", original_combat_log)

	parent_node.add_child(combat_log_overlay)
	return combat_log_overlay


static func hide_combat_log_overlay(combat_log_overlay: Panel) -> void:
	"""Hides and cleans up the combat log overlay"""
	if not combat_log_overlay:
		return
		
	# Restore the original combat log to its original parent and state
	var combat_log_ref = combat_log_overlay.get_meta("combat_log_ref")
	if combat_log_ref:
		# Remove from overlay and reparent to original parent
		combat_log_overlay.remove_child(combat_log_ref)
		var original_parent = combat_log_overlay.get_meta("original_parent")
		if original_parent:
			original_parent.add_child(combat_log_ref)
		
		# Restore original properties
		combat_log_ref.position = combat_log_overlay.get_meta("original_position")
		combat_log_ref.size = combat_log_overlay.get_meta("original_size")
		combat_log_ref.custom_minimum_size = combat_log_overlay.get_meta("original_min_size")  # Restore original minimum size
		combat_log_ref.z_index = combat_log_overlay.get_meta("original_z_index")
		combat_log_ref.visible = combat_log_overlay.get_meta("original_visible")

	combat_log_overlay.queue_free()


static func _hide_overlay(combat_log_overlay: Panel) -> void:
	"""Internal callback for close button"""
	hide_combat_log_overlay(combat_log_overlay)