extends RefCounted
class_name FW_TweenUtils

const DEFAULT_TWEEN_DURATION := 0.12

static func tween_modulate(parent: Node, node: CanvasItem, target_color: Color, duration: float = DEFAULT_TWEEN_DURATION) -> Tween:
	var tw := parent.create_tween()
	tw.tween_property(node, "modulate", target_color, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw
