@tool
extends EditorScript

# Run in the Godot editor to list missing textures referenced by Junk taxonomy
func _run() -> void:
	var json_path: String = "res://Item/Junk/junk_taxonomy.json"
	var f: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if not f:
		printerr("Could not open taxonomy file: %s" % json_path)
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		printerr("Failed to parse taxonomy JSON")
		return
	var items: Array = json.data as Array
	var missing: Array = []
	for it in items:
		var entry: Dictionary = it as Dictionary
		var tex_name: String = (entry.get("texture", "") as String).strip_edges()
		if tex_name == "":
			continue
		var tex_path := "res://Item/Junk/Images/%s" % tex_name
		if not FileAccess.file_exists(tex_path):
			missing.append(tex_path)

	if missing.is_empty():
		print("All textures present (or no textures required).")
	else:
		print("Missing textures (create in res://Item/Junk/Images/):")
		for m in missing:
			print(" - %s" % m)
