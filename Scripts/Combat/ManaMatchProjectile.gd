extends Node2D

class_name FW_ManaMatchProjectile

const BASE_RADIUS := 12.0
const ARRIVAL_SHRINK_TIME := 0.12
const ANTICIPATION_TIME := 0.08  # Quick squash before launch

var _color: Color = Color.WHITE
var _release_cb: Callable = Callable()
var _travel_tween: Tween = null
var _arrival_tween: Tween = null
var _draw_logged := false

func _ready() -> void:
	visible = true  # Always visible - alpha controls fade
	modulate = Color(1, 1, 1, 0)
	scale = Vector2.ONE
	z_index = 950
	z_as_relative = false
	var parent_name: String = "none"
	if get_parent() != null:
		parent_name = get_parent().name
	FW_Debug.debug_log(["ManaMatchProjectile", "_ready", {"visible": visible, "z_index": z_index, "parent": parent_name}])

func _exit_tree() -> void:
	_release_cb = Callable()

func _draw() -> void:
	if !_draw_logged:
		_draw_logged = true
		FW_Debug.debug_log(["ManaMatchProjectile", "draw_called"])
	# Main glow circle
	draw_circle(Vector2.ZERO, BASE_RADIUS * 1.2, Color(_color.r, _color.g, _color.b, _color.a * 0.3))
	# Solid core
	draw_circle(Vector2.ZERO, BASE_RADIUS, _color)
	# Bright highlight
	draw_circle(Vector2.ZERO, BASE_RADIUS * 0.5, Color(1, 1, 1, 0.6))
	# Tiny sparkle
	draw_circle(Vector2(-BASE_RADIUS * 0.25, -BASE_RADIUS * 0.25), BASE_RADIUS * 0.2, Color(1, 1, 1, 0.9))

func launch(start: Vector2, target: Vector2, color: Color, travel_time: float, delay: float, release_cb: Callable) -> void:
	_color = color
	queue_redraw()
	_release_cb = release_cb
	visible = true
	position = start
	scale = Vector2.ONE
	modulate = Color(1, 1, 1, 0)

	FW_Debug.debug_log(["ManaMatchProjectile", "launch", {"start": start, "target": target, "color": color, "delay": delay, "global_pos": global_position, "canvas_layer": get_parent().layer if get_parent() is CanvasLayer else "N/A"}])

	if _travel_tween and _travel_tween.is_valid():
		_travel_tween.kill()
	if _arrival_tween and _arrival_tween.is_valid():
		_arrival_tween.kill()

	_travel_tween = create_tween()

	# Initial delay if needed
	if delay > 0.0:
		_travel_tween.tween_interval(delay)

	# Anticipation: quick squash and fade in
	_travel_tween.tween_property(self, "scale", Vector2(1.3, 0.7), ANTICIPATION_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_travel_tween.parallel().tween_property(self, "modulate:a", 1.0, ANTICIPATION_TIME).set_ease(Tween.EASE_OUT)

	# Pop back to normal and start traveling
	_travel_tween.tween_property(self, "scale", Vector2.ONE * 1.15, ANTICIPATION_TIME * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Main travel with arc (using scale manipulation for subtle effect)
	_travel_tween.tween_property(self, "position", target, travel_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_travel_tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.9, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_travel_tween.tween_callback(Callable(self, "_on_travel_complete"))

func cancel() -> void:
	if _travel_tween and _travel_tween.is_valid():
		_travel_tween.kill()
	if _arrival_tween and _arrival_tween.is_valid():
		_arrival_tween.kill()
	visible = false
	modulate = Color(1, 1, 1, 0)
	if !_release_cb.is_null():
		_release_cb.call()
	_release_cb = Callable()

func _on_travel_complete() -> void:
	_arrival_tween = create_tween()
	# Bounce in slightly then shrink
	_arrival_tween.tween_property(self, "scale", Vector2.ONE * 1.2, ARRIVAL_SHRINK_TIME * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_arrival_tween.tween_property(self, "scale", Vector2.ONE * 0.2, ARRIVAL_SHRINK_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_arrival_tween.parallel().tween_property(self, "modulate:a", 0.0, ARRIVAL_SHRINK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_arrival_tween.tween_callback(Callable(self, "_finalize_release"))
	FW_Debug.debug_log(["ManaMatchProjectile", "impact", {"position": global_position}])

func _finalize_release() -> void:
	visible = false
	modulate = Color(1, 1, 1, 0)
	scale = Vector2.ONE
	if !_release_cb.is_null():
		_release_cb.call()
	_release_cb = Callable()
