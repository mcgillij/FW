@tool
extends EditorScript

# Run this in the editor to sanity-check all Junk resources under res://Item/Junk/Resources/
# It prints warnings when required fields are missing or suspicious values are found.
func _run() -> void:
	var dir: DirAccess = DirAccess.open("res://Item/Junk/Resources")
	if not dir:
		printerr("Could not open Junk Resources directory")
		return
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	var problems: int = 0
	while filename != "":
		if filename.ends_with(".tres") or filename.ends_with(".res"):
			var path: String = "res://Item/Junk/Resources/%s" % filename
			var res: Resource = ResourceLoader.load(path)
			if not res:
				printerr("Could not load resource: %s" % path)
				problems += 1
			else:
				# Ensure it's a Junk resource and check required fields safely
				if res is FW_Junk:
					var j: FW_Junk = res as FW_Junk
					if j.name == null or j.name == "":
						printerr("Missing name in %s" % path)
						problems += 1
					if j.flavor_text == null or j.flavor_text == "":
						printerr("Missing flavor_text in %s" % path)
						problems += 1
					if typeof(j.gold_value) != TYPE_INT and typeof(j.gold_value) != TYPE_FLOAT:
						printerr("Missing or invalid gold_value in %s" % path)
						problems += 1
					if j.item_type != FW_Item.ITEM_TYPE.JUNK and j.item_type != FW_Item.ITEM_TYPE.MONEY:
						printerr("Warning: item_type is not JUNK/MONEY in %s" % path)
				else:
					printerr("Resource is not a Junk resource: %s" % path)
					problems += 1
		filename = dir.get_next()
	dir.list_dir_end()
	if problems == 0:
		print("Junk sanity check: OK — no problems found.")
	else:
		printerr("Junk sanity check: Found %d problems" % problems)
