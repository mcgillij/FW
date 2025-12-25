extends RefCounted

class_name FW_MenuEntryCatalog

const DEFAULTS := {
	"VENDOR": {
		"label": "Vendor",
		"icon_path": "res://Icons/vendor_icon.png"
	},
	"BLACKSMITH": {
		"label": "Blacksmith",
		"icon_path": "res://Icons/blacksmith_icon.png"
	},
	"MAGIC_SHOP": {
		"label": "Magic Shop",
		"icon_path": "res://Icons/transmogrify_icon.png"
	},
	"DOGHOUSE": {
		"label": "Home"
	},
	"UNLOCK": {
		"label": "Unlock",
		"icon_path": "res://Item/Junk/Images/gold_coins.png"
	}
}

const LEVEL_ICON_PATH := "res://Level Select/paws_selectable.png"
const QUEST_ICON_PATH := "res://Icons/quest_icon_map.png"

static func get_defaults(key: StringName) -> Dictionary:
	var str_key := String(key)
	return DEFAULTS.get(str_key, {})

static func get_label(key: StringName) -> String:
	var str_key := String(key)
	var defaults := get_defaults(key)
	if defaults.has("label"):
		return defaults["label"]
	return _humanize_key(str_key)

static func get_icon_path(key: StringName) -> String:
	var defaults := get_defaults(key)
	if defaults.has("icon_path"):
		return defaults["icon_path"]
	var str_key := String(key)
	if _is_level_entry(str_key):
		return LEVEL_ICON_PATH
	if _is_quest_entry(str_key):
		return QUEST_ICON_PATH
	return ""

static func _humanize_key(value: String) -> String:
	if value == "":
		return value
	return value.replace("_", " ").capitalize()

static func _is_level_entry(key: String) -> bool:
	if key == "":
		return false
	if key.find("MISSION") != -1:
		return true
	if key.begins_with("PVP_"):
		return true
	match key:
		"VAMPIRE_LAIR", "ORC_STRONGHOLD", "SKELETON_CRYPT":
			return true
	return false

static func _is_quest_entry(key: String) -> bool:
	if key == "":
		return false
	if key.find("QUEST") != -1:
		return true
	if key.begins_with("CHAT_WITH"):
		return true
	if key.ends_with("_CHAT"):
		return true
	match key:
		"SPECIAL_NPC", "ADVENTURERS_GUILD":
			return true
	return false
