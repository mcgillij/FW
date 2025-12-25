extends TextureRect

class_name FW_InventoryItem

@export var data: FW_Item
@export var loot_prefab: PackedScene = load("res://Item/loot_item_panel_prefab.tscn")
# TODO: have to make other prefabs for different item / equipment types
var padding := 20.0
var base_modulate := Color.WHITE
const HOVER_DIM_FACTOR := 0.85

func init(d: FW_Item) -> void:
	data = d

func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE

	size = GDM.inventory_item_size
	texture = data.texture
	tooltip_text = "some text"
	if data.item_type == FW_Item.ITEM_TYPE.EQUIPMENT:
		var eq = FW_Equipment.new()
		var c = eq.get_rarity_color(data.rarity)
		self.self_modulate = c
	#tooltip_text = "some text" # %s\n%s\n%s" % [data.name, data.flavor_text, data.effects]
	base_modulate = self.self_modulate
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not mouse_entered.is_connected(_on_inventory_item_mouse_entered):
		mouse_entered.connect(_on_inventory_item_mouse_entered)
	if not mouse_exited.is_connected(_on_inventory_item_mouse_exited):
		mouse_exited.connect(_on_inventory_item_mouse_exited)

func _make_custom_tooltip(_for_text: String) -> Control:
	var loot = loot_prefab.instantiate()
	loot.populate_fields(data)
	loot.custom_minimum_size = Vector2(loot.custom_minimum_size.x+padding, loot.custom_minimum_size.y+padding)
	if ScreenRotator.is_rotated:
		var wrapper = Control.new()
		wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Swap x/y for the wrapper!
		wrapper.custom_minimum_size = Vector2(loot.custom_minimum_size.y, loot.custom_minimum_size.x)
		wrapper.add_child(loot)

		loot.pivot_offset = loot.custom_minimum_size / 2
		loot.position = wrapper.custom_minimum_size / 2 - loot.pivot_offset
		loot.rotation_degrees = 90

		return wrapper
	return loot

func _get_drag_data(at_position: Vector2) -> Variant:
	set_drag_preview(make_drag_preview(at_position))
	return self

func make_drag_preview(_at_position: Vector2) -> Control:
	var loot = loot_prefab.instantiate()
	loot.populate_fields(data)
	return loot

func _on_inventory_item_mouse_entered() -> void:
	self.self_modulate = _dimmed_base_modulate()

func _on_inventory_item_mouse_exited() -> void:
	self.self_modulate = base_modulate

func _dimmed_base_modulate() -> Color:
	var dimmed := base_modulate
	dimmed.r *= HOVER_DIM_FACTOR
	dimmed.g *= HOVER_DIM_FACTOR
	dimmed.b *= HOVER_DIM_FACTOR
	dimmed.a = base_modulate.a
	return dimmed
