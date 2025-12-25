class_name FW_ScrollController
extends RefCounted

var _scroll_container: ScrollContainer
var _scroll_tween: Tween
var _saved_position: Vector2 = Vector2.ZERO
var _current_zoom_level: Vector2 = Vector2.ONE

func _init(scroll_container: ScrollContainer):
	_scroll_container = scroll_container

func set_zoom_level(zoom_level: Vector2) -> void:
	"""Update the current zoom level for scroll calculations"""
	_current_zoom_level = zoom_level

func save_current_position() -> void:
	"""Save the current scroll position"""
	if _scroll_container:
		_saved_position = Vector2(_scroll_container.scroll_horizontal, _scroll_container.scroll_vertical)

func restore_position_smooth(duration: float = 0.3) -> void:
	"""Restore the saved scroll position with smooth animation"""
	if not _scroll_container:
		return

	_kill_existing_tween()
	_scroll_tween = _scroll_container.create_tween()
	_scroll_tween.set_parallel(true)
	_scroll_tween.tween_property(_scroll_container, "scroll_horizontal", _saved_position.x, duration)
	_scroll_tween.tween_property(_scroll_container, "scroll_vertical", _saved_position.y, duration)
	_scroll_tween.set_ease(Tween.EASE_OUT)
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)

func scroll_to_position(position: Vector2, duration: float = 0.5) -> void:
	"""Scroll to a specific position with smooth animation"""
	if not _scroll_container:
		return

	_kill_existing_tween()
	_scroll_tween = _scroll_container.create_tween()
	_scroll_tween.set_parallel(true)
	_scroll_tween.tween_property(_scroll_container, "scroll_horizontal", position.x, duration)
	_scroll_tween.tween_property(_scroll_container, "scroll_vertical", position.y, duration)
	_scroll_tween.set_ease(Tween.EASE_OUT)
	_scroll_tween.set_trans(Tween.TRANS_CUBIC)

	_saved_position = position

func calculate_optimal_scroll_position(target_block: Control, parent_container: Control) -> Vector2:
	"""Calculate the optimal scroll position to center a target block, correctly handling container scale."""
	if not _scroll_container or not target_block or not parent_container:
		return Vector2.ZERO

	var viewport_size: Vector2 = _scroll_container.size
	var s: Vector2 = parent_container.scale
	if s.x == 0 or s.y == 0:
		s = Vector2.ONE

	# Compute the target block's top-left in the parent_container's local space.
	# Controls don't expose a direct to_local, but for non-rotated scaled containers:
	# local_pos ~= (block_global - container_global) / scale
	var block_global_pos: Vector2 = target_block.global_position
	var container_global_pos: Vector2 = parent_container.global_position
	var local_pos: Vector2 = (block_global_pos - container_global_pos) / s

	# Center of the block in parent local coordinates
	var block_center_local: Vector2 = local_pos + target_block.size / 2.0

	# Convert desired center into scroll values (scroll is in unscaled coordinates)
	var optimal_scroll: Vector2
	optimal_scroll.x = block_center_local.x - (viewport_size.x / (2.0 * s.x))
	optimal_scroll.y = block_center_local.y - (viewport_size.y / (2.0 * s.y))

	# Clamp to valid scroll range
	var v_scroll_bar := _scroll_container.get_v_scroll_bar()
	var h_scroll_bar := _scroll_container.get_h_scroll_bar()
	optimal_scroll.x = clamp(optimal_scroll.x, 0.0, float(h_scroll_bar.max_value))
	optimal_scroll.y = clamp(optimal_scroll.y, 0.0, float(v_scroll_bar.max_value))

	return optimal_scroll

func restore_position_immediately() -> void:
	"""Restore the saved scroll position immediately without animation"""
	if _scroll_container:
		_scroll_container.scroll_horizontal = int(_saved_position.x)
		_scroll_container.scroll_vertical = int(_saved_position.y)

func _kill_existing_tween() -> void:
	"""Kill any existing scroll tween"""
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
		_scroll_tween = null
