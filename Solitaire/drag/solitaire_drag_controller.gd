extends RefCounted
class_name FW_SolitaireDragController

const STACK_HINT_TINT: Color = Color(0.75, 0.85, 1.0, 1.0)

# Forgiving drop detection thresholds
const MAX_FORGIVING_DISTANCE: float = 150.0  # Max distance to snap to any valid target
const SINGLE_TARGET_BONUS_DISTANCE: float = 250.0  # Extra forgiving if only one valid target

var game: Node
var _target_card_highlights: Array[Dictionary] = []
var _enabled: bool = true  # Track if dragging is enabled

func _init(game_ref: Node) -> void:
	game = game_ref

func set_enabled(enabled: bool) -> void:
	"""Enable or disable drag functionality"""
	_enabled = enabled
	if not _enabled:
		# Clear any ongoing highlights
		_set_drop_zone_highlight(false)
		_clear_target_card_highlights()

func on_drag_started(card_display: FW_CardDisplay) -> void:
	if not _enabled:
		card_display.is_dragging = false
		return
	game._log_debug("=== DRAG STARTED ===")
	game._log_debug("Card drag started", card_display.card._to_string() if card_display.card else "null")
	game._log_debug("Card display position:", card_display.position)
	game._log_debug("Card display size:", card_display.size)
	game._log_debug("Card display rotation:", rad_to_deg(card_display.rotation), "degrees")

	if not card_display.card:
		card_display.is_dragging = false
		return
	if not game.can_drag_card(card_display.card):
		card_display.is_dragging = false
		game._log_debug("Drag denied: card not draggable in current pile")
		return

	# Use smart sequence selection for better mobile experience
	game.selected_cards = game.get_smart_movable_sequence(card_display)
	if game.selected_cards.is_empty():
		card_display.is_dragging = false
		return

	game._log_debug("Selected cards:", game.selected_cards.size())
	for i in range(game.selected_cards.size()):
		var display: FW_CardDisplay = game.selected_cards[i]
		game._log_debug("  [", i, "]", display.card._to_string() if display.card else "null")

	var base_z := 1000
	for i in range(game.selected_cards.size()):
		var display: FW_CardDisplay = game.selected_cards[i]
		display.z_index = base_z + i
		display.move_to_front()
		display.modulate = Color(1.0, 1.0, 1.0, 0.85)
		var tween: Tween = game._create_card_tween(display)
		if tween:
			tween.set_ease(Tween.EASE_OUT)
			tween.set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(display, "scale", Vector2(1.05, 1.05), 0.1)

	_set_drop_zone_highlight(true)
	_update_target_card_highlights(true)
	game._log_debug("====================")

func on_drag_moved(delta: Vector2, dragged: FW_CardDisplay) -> void:
	for display in game.selected_cards:
		if display != dragged:
			display.position += delta

func on_drag_ended(card_display: FW_CardDisplay) -> void:
	game._log_debug("Card drag ended", card_display.card._to_string() if card_display.card else "null")

	for display in game.selected_cards:
		if is_instance_valid(display):
			display.modulate = Color(1.0, 1.0, 1.0, 1.0)
			var tween: Tween = game._create_card_tween(display)
			if tween:
				tween.set_ease(Tween.EASE_OUT)
				tween.set_trans(Tween.TRANS_CUBIC)
				tween.tween_property(display, "scale", Vector2(1.0, 1.0), 0.1)

	_set_drop_zone_highlight(false)
	_clear_target_card_highlights()

	if game.selected_cards.is_empty():
		game._log_debug("No cards selected, ignoring drag end")
		return

	var drop_center := _calculate_drop_center(card_display)

	game._log_debug("=== DROP DETECTION DEBUG ===")
	game._log_debug("Card display position:", card_display.position)
	game._log_debug("Card pivot_offset:", card_display.pivot_offset)
	game._log_debug("Drop center calculated:", drop_center)
	game._log_debug("Mouse position (global):", card_display.get_global_mouse_position())
	if game.card_container:
		var parent_transform: Transform2D = game.card_container.get_global_transform_with_canvas()
		var mouse_local: Vector2 = parent_transform.affine_inverse() * card_display.get_global_mouse_position()
		game._log_debug("Mouse position (card_container local):", mouse_local)
		game._log_debug("Card container transform:", parent_transform)
		game._log_debug("Card container rotation:", rad_to_deg(parent_transform.get_rotation()), "degrees")
		game._log_debug("Card container position:", parent_transform.origin)
	game._log_debug("CARD_WIDTH:", game.CARD_WIDTH, "CARD_HEIGHT:", game.CARD_HEIGHT)
	game._log_debug("Layout preset:", game._layout_preset_to_string(game._current_layout_preset))

	if not game.tableau_slots.is_empty() and game.tableau_slots[0]:
		var slot0_pos: Vector2 = game._tableau_position(0, 0)
		game._log_debug("Tableau slot 0 card position:", slot0_pos)
		game._log_debug("Tableau slot 0 panel global pos:", game.tableau_slots[0].global_position)
		game._log_debug("Tableau slot 0 panel size:", game.tableau_slots[0].size)
		game._log_debug("Tableau slot 0 panel rotation:", rad_to_deg(game.tableau_slots[0].rotation), "degrees")
		var slot0_axes: Dictionary = game._slot_local_axes(game.tableau_slots[0])
		game._log_debug("Tableau slot 0 axes:", slot0_axes)

	var single_card: bool = game.selected_cards.size() == 1
	var first_card: FW_Card = game.selected_cards[0].card if not game.selected_cards.is_empty() else null

	if first_card:
		game._log_debug("First card:", first_card._to_string())
		game._log_debug("Card rank:", first_card.rank, "Card color:", first_card.get_color())
		for col in range(game.tableau.size()):
			var rect: Rect2 = _get_tableau_drop_rect(col)
			var in_rect: bool = rect.has_point(drop_center)
			var can_move: bool = game.can_move_to_tableau(first_card, col)
			game._log_debug("Tableau col", col, "rect:", rect, "contains_point:", in_rect, "can_move:", can_move)
			if not game.tableau[col].is_empty():
				var top: FW_Card = game.tableau[col].back()
				game._log_debug("  Top card:", top._to_string(), "rank:", top.rank, "color:", top.get_color())

	var drop_target: Dictionary = _find_drop_target(drop_center, single_card, first_card)
	game._log_debug("Drop target found:", drop_target)
	game._log_debug("=========================")

	if not drop_target.is_empty():
		match drop_target.get("pile", -1):
			game.PileType.TABLEAU:
				var tableau_index: int = drop_target.get("index", -1)
				if tableau_index != -1:
					game._log_debug("Moving to tableau column", tableau_index)
					game.move_card_to_tableau(game.selected_cards, tableau_index)
					game.selected_cards.clear()
					return
			game.PileType.FOUNDATION:
				var foundation_index: int = drop_target.get("index", -1)
				if foundation_index != -1 and single_card:
					game._log_debug("Moving to foundation", foundation_index)
					game.move_card_to_foundation(game.selected_cards[0], foundation_index)
					game.selected_cards.clear()
					return

	game._log_debug("Invalid move, resetting position")
	for display in game.selected_cards:
		if is_instance_valid(display):
			game.animate_invalid_move(display)
	game.selected_cards.clear()

func highlight_valid_drop_zones(highlight: bool) -> void:
	_set_drop_zone_highlight(highlight)
	_update_target_card_highlights(highlight)

func _calculate_drop_center(card_display: FW_CardDisplay) -> Vector2:
	if game.card_container:
		var parent_transform: Transform2D = game.card_container.get_global_transform_with_canvas()
		return parent_transform.affine_inverse() * card_display.get_global_mouse_position()
	if card_display.pivot_offset != Vector2.ZERO:
		return card_display.position + card_display.pivot_offset
	return card_display.position + Vector2(game.CARD_WIDTH * 0.5, game.CARD_HEIGHT * 0.5)

func _find_drop_target(drop_center: Vector2, single_card: bool, card: FW_Card) -> Dictionary:
	if not card:
		game._log_debug("_find_drop_target: No card provided")
		return {}

	game._log_debug("_find_drop_target called: drop_center=", drop_center, "single_card=", single_card)

	var best_target: Dictionary = {}
	var best_distance: float = INF

	# First pass: Find all valid destinations and check for exact overlaps
	var valid_destinations: Array[Dictionary] = []
	var exact_match_found: bool = false

	if single_card:
		for f_idx in range(game.foundations.size()):
			if not game.can_move_to_foundation(card, f_idx):
				continue
			var rect: Rect2 = _get_foundation_drop_rect(f_idx)
			var slot_center: Vector2 = rect.get_center()
			var distance: float = drop_center.distance_to(slot_center)
			var is_inside: bool = rect.has_point(drop_center)

			valid_destinations.append({
				"pile": game.PileType.FOUNDATION,
				"index": f_idx,
				"distance": distance,
				"is_inside": is_inside
			})

			game._log_debug("  Foundation", f_idx, "is valid, distance:", distance, "inside:", is_inside)

			if is_inside and distance < best_distance:
				best_distance = distance
				best_target = {"pile": game.PileType.FOUNDATION, "index": f_idx}
				exact_match_found = true

	for col in range(game.tableau.size()):
		var rect: Rect2 = _get_tableau_drop_rect(col)
		var in_rect: bool = rect.has_point(drop_center)
		game._log_debug("  Checking tableau col", col, "rect:", rect, "contains drop_center:", in_rect)
		if not game.can_move_to_tableau(card, col):
			game._log_debug("    -> can_move_to_tableau returned false")
			continue

		var drop_pos: Vector2 = game._tableau_position(col, 0) if game.tableau[col].is_empty() else game._tableau_position(col, game.tableau[col].size())
		var distance: float = drop_center.distance_to(drop_pos)

		valid_destinations.append({
			"pile": game.PileType.TABLEAU,
			"index": col,
			"distance": distance,
			"is_inside": in_rect
		})

		game._log_debug("    -> Valid tableau target! distance:", distance, "inside:", in_rect)

		if in_rect and distance < best_distance:
			best_distance = distance
			best_target = {"pile": game.PileType.TABLEAU, "index": col}
			exact_match_found = true
			game._log_debug("    -> New best exact match!")

	# If we found an exact match (drop point inside rect), use it
	if exact_match_found:
		game._log_debug("_find_drop_target: Using exact match:", best_target)
		return best_target

	# No exact match - use forgiving proximity logic
	game._log_debug("_find_drop_target: No exact match, checking proximity to", valid_destinations.size(), "valid destinations")

	# If there's only ONE valid destination, be very forgiving
	if valid_destinations.size() == 1:
		var dest = valid_destinations[0]
		if dest["distance"] <= SINGLE_TARGET_BONUS_DISTANCE:
			game._log_debug("  -> Only one valid target at distance", dest["distance"], "- snapping to it!")
			return {"pile": dest["pile"], "index": dest["index"]}

	# Multiple targets: find the closest one within forgiving distance
	best_target = {}
	best_distance = INF

	for dest in valid_destinations:
		var distance: float = dest["distance"]
		if distance <= MAX_FORGIVING_DISTANCE and distance < best_distance:
			best_distance = distance
			best_target = {"pile": dest["pile"], "index": dest["index"]}
			game._log_debug("  -> New closest target within range:", best_target, "distance:", distance)

	if not best_target.is_empty():
		game._log_debug("_find_drop_target: Using closest valid target:", best_target, "distance:", best_distance)
	else:
		game._log_debug("_find_drop_target: No valid target within forgiving distance")

	return best_target

func _set_drop_zone_highlight(highlight: bool) -> void:
	if game.selected_cards.is_empty():
		return

	var first_card: FW_Card = game.selected_cards[0].card if game.selected_cards.size() > 0 else null
	if not first_card:
		return

	for col in range(min(game.tableau_slots.size(), 7)):
		var slot: Control = game.tableau_slots[col]
		if slot:
			if highlight and game.can_move_to_tableau(first_card, col):
				slot.modulate = Color(0.6, 1.2, 0.6, 1.0)
				var tween: Tween = game.create_tween()
				tween.set_loops()
				tween.tween_property(slot, "scale", Vector2(1.03, 1.03), 0.5)
				tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.5)
				slot.set_meta("highlight_tween", tween)
			else:
				slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
				slot.scale = Vector2(1.0, 1.0)
				if slot.has_meta("highlight_tween"):
					var tween: Tween = slot.get_meta("highlight_tween")
					if is_instance_valid(tween):
						tween.kill()
					slot.remove_meta("highlight_tween")

	if game.selected_cards.size() == 1:
		for f_idx in range(game.foundation_slots.size()):
			var slot: Control = game.foundation_slots[f_idx]
			if slot:
				if highlight and game.can_move_to_foundation(first_card, f_idx):
					slot.modulate = Color(1.2, 1.1, 0.5, 1.0)
					var tween: Tween = game.create_tween()
					tween.set_loops()
					tween.tween_property(slot, "scale", Vector2(1.03, 1.03), 0.5)
					tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.5)
					slot.set_meta("highlight_tween", tween)
				else:
					slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
					slot.scale = Vector2(1.0, 1.0)
					if slot.has_meta("highlight_tween"):
						var tween: Tween = slot.get_meta("highlight_tween")
						if is_instance_valid(tween):
							tween.kill()
						slot.remove_meta("highlight_tween")
	else:
		for f_idx in range(game.foundation_slots.size()):
			var slot: Control = game.foundation_slots[f_idx]
			if slot:
				slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
				slot.scale = Vector2(1.0, 1.0)
				if slot.has_meta("highlight_tween"):
					var tween: Tween = slot.get_meta("highlight_tween")
					if is_instance_valid(tween):
						tween.kill()
					slot.remove_meta("highlight_tween")

func _get_tableau_drop_rect(col: int) -> Rect2:
	if col < 0 or col >= game.tableau.size():
		return Rect2()
	var slot: Control = game.tableau_slots[col]
	if slot == null:
		return Rect2()

	var column_height: float = game.CARD_HEIGHT
	if not game.tableau[col].is_empty():
		column_height = game.CARD_HEIGHT + (game.tableau[col].size() - 1) * game.CARD_OFFSET_Y
	column_height += game.CARD_OFFSET_Y

	var points := _slot_corners_in_container(slot)
	if points.is_empty():
		return Rect2()
	var axes: Dictionary = game._slot_local_axes(slot)
	var stack_axis: Vector2 = axes.get("y_axis", Vector2.DOWN)
	var stack_extension_distance: float = max(0.0, column_height - game.CARD_HEIGHT)
	if stack_axis.length_squared() > 0.0001 and stack_extension_distance > 0.0:
		var stack_extension: Vector2 = stack_axis.normalized() * stack_extension_distance
		for i in range(points.size()):
			points.append(points[i] + stack_extension)

	var rect := _rect_from_points(points)
	return rect.grow(10.0)

func _get_foundation_drop_rect(f_idx: int) -> Rect2:
	if f_idx < 0 or f_idx >= game.foundations.size():
		return Rect2()
	var slot: Control = game.foundation_slots[f_idx]
	var points := _slot_corners_in_container(slot)
	if points.is_empty():
		return Rect2()
	var rect := _rect_from_points(points)
	return rect.grow(10.0)

func _slot_corners_in_container(slot: Control) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if slot == null or game.card_container == null:
		return points
	var slot_transform := slot.get_global_transform_with_canvas()
	var container_inverse: Transform2D = game.card_container.get_global_transform_with_canvas().affine_inverse()
	var corners := [
		Vector2.ZERO,
		Vector2(slot.size.x, 0.0),
		Vector2(0.0, slot.size.y),
		slot.size
	]
	for corner in corners:
		points.append(container_inverse * (slot_transform * corner))
	return points

func _rect_from_points(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect

func _update_target_card_highlights(highlight: bool) -> void:
	_clear_target_card_highlights()
	if not highlight:
		return
	if game.selected_cards.is_empty():
		return
	var first_card: FW_Card = game.selected_cards[0].card if game.selected_cards.size() > 0 else null
	if first_card == null:
		return
	var single_card: bool = game.selected_cards.size() == 1
	for col in range(game.tableau.size()):
		if not game.can_move_to_tableau(first_card, col):
			continue
		if game.tableau[col].is_empty():
			continue
		var target_card: FW_Card = game.tableau[col].back()
		if target_card == null or target_card == first_card:
			continue
		var target_display: FW_CardDisplay = game.get_display_for_card(target_card)
		if target_display == null:
			continue
		if game.selected_cards.has(target_display):
			continue
		_apply_card_hint(target_display)
	if single_card:
		for f_idx in range(game.foundations.size()):
			if not game.can_move_to_foundation(first_card, f_idx):
				continue
			if game.foundations[f_idx].is_empty():
				continue
			var foundation_card: FW_Card = game.foundations[f_idx].back()
			var foundation_display: FW_CardDisplay = game.get_display_for_card(foundation_card)
			if foundation_display == null:
				continue
			_apply_card_hint(foundation_display)

func _apply_card_hint(display: FW_CardDisplay) -> void:
	if display == null:
		return
	var entry := {
		"display": display,
		"color": display.modulate
	}
	_target_card_highlights.append(entry)
	var base_color: Color = display.modulate
	display.modulate = Color(
		clamp(base_color.r * STACK_HINT_TINT.r, 0.0, 1.0),
		clamp(base_color.g * STACK_HINT_TINT.g, 0.0, 1.0),
		clamp(base_color.b * STACK_HINT_TINT.b, 0.0, 1.0),
		base_color.a
	)

func _clear_target_card_highlights() -> void:
	for entry in _target_card_highlights:
		var display: FW_CardDisplay = entry.get("display")
		if is_instance_valid(display):
			display.modulate = entry.get("color", Color(1.0, 1.0, 1.0, 1.0))
	_target_card_highlights.clear()
