extends PopupMenu
class_name FW_ContextMenu

# Framework-safe popup/context menu.
# Uses Godot's built-in PopupMenu theming (no hardcoded styling).

signal entry_pressed(id: int)

var _next_auto_id: int = 0

func _ready() -> void:
	id_pressed.connect(func(id: int) -> void:
		entry_pressed.emit(id)
	)

func clear_entries() -> void:
	clear()
	_next_auto_id = 0

func add_entry(label: String, id: int = -1, icon: Texture2D = null, disabled: bool = false) -> int:
	var entry_id := id
	if entry_id < 0:
		entry_id = _next_auto_id
		_next_auto_id += 1
	if icon != null:
		add_icon_item(icon, label, entry_id)
	else:
		add_item(label, entry_id)
	set_item_disabled(get_item_index(entry_id), disabled)
	return entry_id

func set_entry_disabled(id: int, disabled: bool) -> void:
	var idx := get_item_index(id)
	if idx < 0:
		return
	set_item_disabled(idx, disabled)

func popup_at(rect: Rect2) -> void:
	# PopupMenu expects Rect2i for positioning.
	var r := Rect2i(rect.position, rect.size)
	popup(r)
