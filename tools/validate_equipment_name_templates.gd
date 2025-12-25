@tool
extends EditorScript

# Title: Validate Equipment Name Templates
# Path: res://tools/validate_equipment_name_templates.gd
# Description:
#   EditorScript to validate EquipmentNameGenerator template placeholders and
#   run randomized prefix/suffix combinations to ensure no template breaks.
# Key functions:
#   - _run(): entrypoint

const PREFIXES_PATH := "res://Equipment/prefixes.json"
const SUFFIXES_PATH := "res://Equipment/suffixes.json"

const RANDOM_COMBOS := 2000
const PRINT_SAMPLES := 20

func _run() -> void:
	print("\n=== Equipment Name Template Validation ===")
	var gen := FW_EquipmentNameGenerator.new()

	var template_report: Dictionary = gen.validate_templates()
	if not bool(template_report.get("ok", false)):
		push_error("EquipmentNameGenerator templates failed validation")
		for e in template_report.get("errors", []):
			print("ERROR: ", e)
		print("=== FAILED ===\n")
		return
	print("Templates: OK")

	var prefixes := _load_affix_names(PREFIXES_PATH)
	var suffixes := _load_affix_names(SUFFIXES_PATH)
	if prefixes.is_empty() or suffixes.is_empty():
		push_error("Could not load prefix/suffix name lists")
		print("=== FAILED ===\n")
		return

	var failures := 0
	var samples_printed := 0
	for i in range(RANDOM_COMBOS):
		var prefix := prefixes[randi() % prefixes.size()]
		var suffix := suffixes[randi() % suffixes.size()]
		var text := gen.generate_flavor_text(prefix, suffix)
		if text.is_empty() or text.find("{") != -1 or text.find("}") != -1:
			failures += 1
			print("FAIL:", "prefix=", prefix, "suffix=", suffix, "text=", text)
			continue
		if samples_printed < PRINT_SAMPLES:
			samples_printed += 1
			print("\nSample #", samples_printed)
			print(" - ", prefix, " / ", suffix)
			print(text)

	if failures > 0:
		push_warning("Name template fuzz test had %d failures" % failures)
		print("WARN: failures=", failures, " of ", RANDOM_COMBOS)
	else:
		print("Fuzz test: OK (", RANDOM_COMBOS, " combinations)")

	print("=== DONE ===\n")


func _load_affix_names(path: String) -> Array[String]:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return []
	var json = JSON.parse_string(file.get_as_text())
	if typeof(json) != TYPE_ARRAY:
		return []
	var names: Array[String] = []
	for entry in json:
		if typeof(entry) == TYPE_DICTIONARY and entry.has("name") and typeof(entry.name) == TYPE_STRING:
			names.append(entry.name)
	return names
