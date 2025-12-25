class_name FW_UIUtils

# Small UI helper utilities used across the project
# Use static methods to avoid instantiation; caller should provide a parent node for creating tweens.

const DIMMED_COLOR := Color(0.5, 0.5, 0.5, 1)
const NORMAL_COLOR := Color(1, 1, 1, 1)
const HOVER_COLOR := Color(0.92, 0.92, 0.92, 1)
const PRESSED_COLOR := Color(0.7, 0.4, 0.4, 1)  # Red-tinted dim for already pressed buttons
const TWEEN_DURATION := 0.12

static func tween_modulate(parent: Node, node: CanvasItem, target_color: Color, duration: float = TWEEN_DURATION) -> Tween:
	# Create a scene-tree tween on the provided parent to animate the modulate property.
	var tw = parent.create_tween()
	tw.tween_property(node, "modulate", target_color, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw
