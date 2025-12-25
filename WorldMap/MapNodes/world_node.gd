extends Resource

class_name FW_WorldNode

enum NODE_TYPE {
	FARM,
	VILLAGE,
	TOWN,
	CITY,
	CAPITAL,
	DUNGEON,
	CAVE,
	FOREST,
	FOREST_PATH,
	FOREST_RIVER,
	SNOW_PATH,
	ICY_LAKE,
	ICY_STREAM,
	RUINS,
	RUINS_VILLAGE,
	ABANDONED_BUILDINGS,
	SNOW_VILLAGE,
	ANCIENT_ARENA,
	ARENA_CHALLENGE,
	DOG_HOUSE,
	PRIZE_WHEEL,
	SNOWMAN,
	TUTORIAL_SIGNPOST
}

@export var name: String
@export var enabled: bool
@export var blocked_texture: Texture2D
@export var open_texture: Texture2D
@export var type: NODE_TYPE
@export var menu_entries: Array[FW_MenuEntryData]
@export var world_hash: int
@export var npc_id: String = ""  # NPC identifier for quest system
@export var quest_registry: Resource  # QuestRegistry resource
@export var mission_params: Dictionary  # Mission parameters for level generation

func _to_string() -> String:
	return "WorldNode: " + name + \
		" (type: " + str(type) + ")" + \
		", enabled: " + str(enabled) + \
		", menu_entries: " + str(menu_entries) + \
		", world_hash: " + str(world_hash)

func _set(property: StringName, value) -> bool:
	if property == "menu_entries":
		menu_entries = _convert_menu_entries(value)
		return true
	return false

func _convert_menu_entries(value) -> Array[FW_MenuEntryData]:
	var result: Array[FW_MenuEntryData] = []
	if value is Array:
		for element in value:
			if element is FW_MenuEntryData:
				result.append(element)
			elif element is Dictionary:
				var entry := FW_MenuEntryData.new()
				entry.key = element.get("key", "")
				entry.label_override = element.get("label", "")
				if element.has("icon"):
					var icon_resource = element["icon"]
					if icon_resource is Texture2D and icon_resource.resource_path != "":
						entry.icon_path = icon_resource.resource_path
						entry._cached_icon_path = icon_resource.resource_path
						entry._cached_icon = icon_resource
				result.append(entry)
	return result
