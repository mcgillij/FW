extends TextureRect
class_name FW_AbilityInventoryItem

@export var data: FW_Ability

func init(d: FW_Ability) -> void:
	data = d

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size = GDM.inventory_item_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture = data.texture
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	#tooltip_text = "%s\n%s" % [data.name, data.description]
	mouse_entered.connect(_on_button_mouse_entered)
	mouse_exited.connect(_on_button_mouse_exited)

func _on_button_mouse_entered() -> void:
	modulate = Color(1,1,1,.5)
	EventBus.ability_hover.emit(data)

func _on_button_mouse_exited() -> void:
	modulate = Color(1,1,1,1)
	EventBus.ability_unhover.emit()

func _get_drag_data(at_position: Vector2) -> Variant:
	set_drag_preview(make_drag_preview(at_position))
	var payload = {
		"item": self,
		"source_slot": get_parent()
	}
	return payload

func make_drag_preview(at_position: Vector2) -> Control:
	var t := TextureRect.new()
	t.texture = texture
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = GDM.inventory_item_size
	t.modulate.a = 0.5 # 50% opacity (probably make a const for this)
	t.position = Vector2(-at_position)
	var c := Control.new()
	c.add_child(t)
	return c
