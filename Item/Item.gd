extends Resource

class_name FW_Item

enum ITEM_TYPE { EQUIPMENT, CRAFTING, MISC, JUNK, QUEST, MONEY, CONSUMABLE }

@export var name: String
@export var item_type: FW_Item.ITEM_TYPE
@export var texture: Texture2D
@export_multiline var flavor_text: String

func _to_string() -> String:
	return "[Item: %s (%s)]" % [name, str(ITEM_TYPE.keys()[item_type])]
