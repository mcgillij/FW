extends ColorRect
class_name FW_ModalOverlay

signal dismissed

@export var dismiss_on_mouse: bool = true
@export var dismiss_on_touch: bool = true
@export var dismiss_on_escape: bool = true

static func attach(parent: Node, z: int = 1000) -> FW_ModalOverlay:
	var overlay := FW_ModalOverlay.new()
	overlay.name = "fw_modal_overlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.anchor_left = 0
	overlay.anchor_top = 0
	overlay.anchor_right = 1
	overlay.anchor_bottom = 1
	overlay.z_index = z
	parent.add_child(overlay)
	return overlay

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if dismiss_on_escape:
		set_process_unhandled_input(true)

func _on_gui_input(event: InputEvent) -> void:
	if dismiss_on_mouse and event is InputEventMouseButton and event.pressed:
		dismissed.emit()
		queue_free()
		return
	if dismiss_on_touch and event is InputEventScreenTouch and event.pressed:
		dismissed.emit()
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not dismiss_on_escape:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			dismissed.emit()
			queue_free()
