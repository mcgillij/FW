@tool
extends EditorScript

# Usage: Open this script in the Godot editor and press the "Run" button.
# It reads res://Item/Junk/junk_taxonomy.json and creates .tres resources under res://Item/Junk/Resources/.

func _run() -> void:
	var json_file_path: String = "res://Item/Junk/junk_taxonomy.json"
	var f: FileAccess = FileAccess.open(json_file_path, FileAccess.READ)
	if not f:
		printerr("Could not open taxonomy file: %s" % json_file_path)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		printerr("Failed to parse taxonomy JSON")
		return
	var items: Array = json.data as Array
	if typeof(items) != TYPE_ARRAY:
		printerr("Taxonomy JSON must be an array of item objects.")
		return

	var junk_script: Script = load("res://Item/Junk/FW_Junk.gd") as Script
	if not junk_script:
		printerr("Could not load FW_Junk.gd script")
		return

	for it in items:
		var entry: Dictionary = it as Dictionary
		var name: String = entry.get("name", "") as String
		if name == "":
			printerr("Skipping taxon entry with no name: %s" % str(entry))
			continue
		var jres: FW_Junk = (junk_script.new() as FW_Junk)
		jres.name = name
		jres.gold_value = int(entry.get("gold_value", 0))
		jres.item_type = FW_Item.ITEM_TYPE.JUNK
		jres.flavor_text = entry.get("flavor_text", "") as String

		var tex_name: String = entry.get("texture", "") as String
		if tex_name != "":
			var tex_path := "res://Item/Junk/Images/%s" % tex_name
			if FileAccess.file_exists(tex_path):
				jres.texture = ResourceLoader.load(tex_path) as Texture2D
			else:
				printerr("Warning: texture does not exist: %s for item %s" % [tex_path, name])

		# Save resource (ResourceSaver.save takes resource first, then path)
		var save_name: String = name.replace(" ", "")
		save_name = save_name.replace("'", "")
		var save_path: String = "res://Item/Junk/Resources/%s.tres" % save_name
		var err: int = ResourceSaver.save(jres, save_path)
		if err == OK:
			print("Saved: %s" % save_path)
		else:
			printerr("Failed saving %s: %s" % [save_path, str(err)])

	print("Done generating junk resources. Created %d entries." % items.size())
