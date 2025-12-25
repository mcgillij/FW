extends Control
class_name FW_LootItemPanelPrefab

@onready var item_name: Label = %item_name
@onready var item_rarity: Label = %item_rarity
@onready var item_flavor_text: Label = %item_flavor_text
@onready var item_effects: Label = %item_effects
@onready var item_image: TextureRect = %item_image
@onready var item_gold_value: Label = %item_gold_value

var cms = Vector2(300, 250)

func populate_fields(item: FW_Item) -> void: # TODO: equipment is the only type of item so far, so we'll use that
	if !item_name:
		item_name = %item_name
	if !item_flavor_text:
		item_flavor_text = %item_flavor_text
	if !item_image:
			item_image = %item_image

	if item.item_type == FW_Item.ITEM_TYPE.EQUIPMENT:
		if !item_effects:
			item_effects = %item_effects
		item_effects.text = FW_Utils.format_effects(item.effects)
		if !item_rarity:
			item_rarity = %item_rarity
		var rarity_color = item.get_rarity_color(item.rarity)
		item_name.add_theme_color_override("font_color", rarity_color)
		item_rarity.add_theme_color_override("font_color", rarity_color)
		item_rarity.add_theme_color_override("font_outline_color", Color.WHITE)
		item_rarity.text = FW_Equipment.equipment_rarity.keys()[item.rarity].capitalize()
		item_rarity.show()
		item_image.self_modulate = rarity_color


	if item.item_type in [FW_Item.ITEM_TYPE.EQUIPMENT, FW_Item.ITEM_TYPE.JUNK, FW_Item.ITEM_TYPE.MONEY, FW_Item.ITEM_TYPE.CONSUMABLE]:
		if !item_gold_value:
			item_gold_value = %item_gold_value
		item_gold_value.text = str(item.gold_value) + " gp"
	item_name.text = item.name
	item_name.add_theme_color_override("font_outline_color", Color.WHITE)
	item_flavor_text.text = item.flavor_text
	item_image.texture = item.texture
	custom_minimum_size = cms # Don't swap x/y here

func _gui_input(event):
	var scroll = find_parent_scrollcontainer()
	if scroll:
		if (
			(event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT) or
			event is InputEventScreenDrag
		):
			scroll.scroll_horizontal -= event.relative.x
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll.scroll_horizontal -= 50
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll.scroll_horizontal += 50

func find_parent_scrollcontainer():
	var node = get_parent()
	while node:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null
