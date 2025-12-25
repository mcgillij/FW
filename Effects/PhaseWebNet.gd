extends Node2D

signal finished

var nodes: Array = [] # array of Vector2 in global pixel coords
var duration: float = 1.0
var color: Color = Color(1.0, 0.475, 0.776)
var _t: float = 0.0

func _ready() -> void:
	set_process(false)

func start(params: Dictionary) -> void:
	# Expected params: {"nodes": [Vector2,...], "duration": float, "color": Color}
	var raw_nodes = params.get("nodes", [])
	duration = params.get("duration", 1.0)
	color = params.get("color", color)
	_t = 0.0
	# Use the pixel coords as provided by the manager (these are screen-space pixels
	# relative to the viewport). Ensure this node is positioned at the origin so
	# drawing uses the same coordinate system.
	position = Vector2.ZERO
	nodes.clear()
	for p in raw_nodes:
		if typeof(p) == TYPE_VECTOR2:
			nodes.append(p)
	# Debug: print nodes so we can verify placement and viewport context
	var vp = get_viewport()
	var vs = vp.get_visible_rect().size if vp else Vector2.ZERO
	FW_Debug.debug_log(["PhaseWebNet.start: viewport_size=%s, nodes(screen)= %s" % [str(vs), str(nodes)]])
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration:
		set_process(false)
		emit_signal("finished")
		queue_free()

func _draw() -> void:
	if nodes.size() == 0:
		return

	var prog = clamp(_t / duration, 0.0, 1.0)

	# Compute centroid
	var centroid = Vector2.ZERO
	for p in nodes:
		centroid += p
	centroid /= float(nodes.size())

	# Draw strands from centroid to each node (growing with prog)
	for p in nodes:
		var target = centroid.lerp(p, prog)
		var alpha = 0.95 * (0.5 + 0.5 * prog)
		var col = Color(color.r, color.g, color.b, alpha)
		# Use a thicker line for visibility during debug
		draw_line(centroid, target, col, max(2.0, 8.0 * prog))

	# Draw node glows (pulsing with prog)
	for p in nodes:
		var r = 12.0 + 36.0 * prog
		var a = 0.7 + 0.3 * prog
		var glow_col = Color(color.r, color.g, color.b, a)
		draw_circle(p, r, glow_col)
		# inner white spark
		var inner_a = 0.0
		if prog > 0.0:
			inner_a = 0.8 * abs(sin(prog * PI))
		draw_circle(p, r * 0.45, Color(1,1,1, inner_a))
