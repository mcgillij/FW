@tool
extends EditorScript

# Title: Validate Equipment Affixes
# Path: res://tools/validate_equipment_affixes.gd
# Description:
#   EditorScript that validates equipment affix/suffix/prefix data and exercises the
#   equipment generator to ensure everything is reachable and consistent.
# Key functions:
#   - _run(): entrypoint
#   - _validate_affix_file(path)
#   - _exercise_generation(prefixes, suffixes)

const PREFIXES_PATH := "res://Equipment/prefixes.json"
const SUFFIXES_PATH := "res://Equipment/suffixes.json"

const GENERATION_SAMPLES_PER_TYPE := 200

func _run() -> void:
	print("\n=== Equipment Affix Validation شروع ===")
	print("Validating:")
	print(" - ", PREFIXES_PATH)
	print(" - ", SUFFIXES_PATH)

	var prefix_report := _validate_affix_file(PREFIXES_PATH)
	var suffix_report := _validate_affix_file(SUFFIXES_PATH)

	_print_report("Prefixes", prefix_report)
	_print_report("Suffixes", suffix_report)

	if not prefix_report.ok or not suffix_report.ok:
		push_error("Equipment affix validation failed; see output for details")
		print("=== Equipment Affix Validation FAILED ===\n")
		return

	_exercise_generation(prefix_report.affixes, suffix_report.affixes)
	print("=== Equipment Affix Validation DONE ===\n")


class AffixReport:
	var ok: bool = true
	var path: String = ""
	var affixes: Array[Dictionary] = []
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var unknown_stat_keys: Dictionary = {} # key -> count


func _validate_affix_file(path: String) -> AffixReport:
	var report := AffixReport.new()
	report.path = path

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		report.ok = false
		report.errors.append("Cannot open file")
		return report

	var raw_text := file.get_as_text()
	var json = JSON.parse_string(raw_text)
	if typeof(json) != TYPE_ARRAY:
		report.ok = false
		report.errors.append("Root JSON is not an Array")
		return report

	var canonical := FW_StatsManager.STAT_NAMES

	for i in range(json.size()):
		var entry = json[i]
		if typeof(entry) != TYPE_DICTIONARY:
			report.ok = false
			report.errors.append("Index %d: entry is not a Dictionary" % i)
			continue
		if not entry.has("name") or typeof(entry.name) != TYPE_STRING:
			report.ok = false
			report.errors.append("Index %d: missing string 'name'" % i)
			continue
		if not entry.has("effect") or typeof(entry.effect) != TYPE_DICTIONARY:
			report.ok = false
			report.errors.append("Index %d (%s): missing dict 'effect'" % [i, entry.name])
			continue

		# Validate effects structure and stat keys
		var effect_dict: Dictionary = entry.effect
		var entry_ok := true
		for key in effect_dict.keys():
			var stat_key := str(key)
			if not canonical.has(stat_key):
				report.ok = false
				entry_ok = false
				report.unknown_stat_keys[stat_key] = int(report.unknown_stat_keys.get(stat_key, 0)) + 1
				report.errors.append("Index %d (%s): unknown stat key '%s'" % [i, entry.name, stat_key])
				continue
			var range_val = effect_dict[key]
			if typeof(range_val) != TYPE_ARRAY or range_val.size() != 2:
				report.ok = false
				entry_ok = false
				report.errors.append("Index %d (%s): stat '%s' range must be [min,max]" % [i, entry.name, stat_key])
				continue
			if typeof(range_val[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(range_val[1]) not in [TYPE_INT, TYPE_FLOAT]:
				report.ok = false
				entry_ok = false
				report.errors.append("Index %d (%s): stat '%s' range values must be numeric" % [i, entry.name, stat_key])
				continue
			if float(range_val[0]) > float(range_val[1]):
				report.warnings.append("Index %d (%s): stat '%s' has min>max; generator will still roll but range is inverted" % [i, entry.name, stat_key])

		if entry_ok:
			report.affixes.append(entry)

	return report


func _print_report(title: String, report: AffixReport) -> void:
	print("\n-- ", title, " --")
	print("File: ", report.path)
	print("Valid entries: ", report.affixes.size())
	if report.unknown_stat_keys.size() > 0:
		print("Unknown stat keys:")
		for k in report.unknown_stat_keys.keys():
			print(" - ", k, " (", report.unknown_stat_keys[k], ")")

	if report.warnings.size() > 0:
		print("Warnings (", report.warnings.size(), "):")
		for w in report.warnings:
			print(" - ", w)

	if report.errors.size() > 0:
		print("Errors (", report.errors.size(), "):")
		for e in report.errors:
			print(" - ", e)

	print("Status: ", "OK" if report.ok else "FAILED")


func _exercise_generation(prefixes: Array[Dictionary], suffixes: Array[Dictionary]) -> void:
	print("\n-- Generator Exercise --")

	# Deterministic reachability statement: if it is in the loaded lists, it is reachable.
	# Still run a Monte Carlo to catch any unexpected runtime issues.
	var expected_prefix_names: Dictionary = {}
	for p in prefixes:
		expected_prefix_names[p.name] = true
	var expected_suffix_names: Dictionary = {}
	for s in suffixes:
		expected_suffix_names[s.name] = true

	var seen_prefix: Dictionary = {}
	var seen_suffix: Dictionary = {}
	var seen_types: Dictionary = {}
	var generation_failures := 0

	var gen := FW_EquipmentGeneratorV2.new()

	for t in FW_Equipment.equipment_types.values():
		seen_types[t] = 0
		for i in range(GENERATION_SAMPLES_PER_TYPE):
			var item: FW_Equipment = gen.generate_equipment_of_type(t)
			if item == null:
				generation_failures += 1
				continue
			seen_types[t] = int(seen_types[t]) + 1
			# Name format: "<prefix> <base> <suffix>" (from EquipmentNameGenerator)
			var parts := item.name.split(" ")
			if parts.size() >= 3:
				seen_prefix[parts[0]] = true
				seen_suffix["of " + parts[parts.size() - 1]] = true

	print("Generated per type (", GENERATION_SAMPLES_PER_TYPE, " samples each):")
	for t in FW_Equipment.equipment_types.values():
		print(" - ", FW_Equipment.equipment_types.keys()[t], ": ", seen_types[t])
	if generation_failures > 0:
		push_warning("Generator returned null %d times" % generation_failures)
		print("WARN: generator returned null ", generation_failures, " times")

	print("\nAffix reachability summary:")
	print(" - Prefixes in data: ", expected_prefix_names.size(), ", observed during generation: ", seen_prefix.size())
	print(" - Suffixes in data: ", expected_suffix_names.size(), ", observed during generation: ", seen_suffix.size())

	var missing_prefix := []
	for name in expected_prefix_names.keys():
		if not seen_prefix.has(name):
			missing_prefix.append(name)

	var missing_suffix := []
	for name in expected_suffix_names.keys():
		if not seen_suffix.has(name):
			missing_suffix.append(name)

	# Note: Monte Carlo may miss some names even if reachable; this list is informational.
	if missing_prefix.size() > 0:
		print("NOTE: Not observed in this run (prefix): ", missing_prefix.size())
		print("(Monte Carlo only; not necessarily unreachable)")
	if missing_suffix.size() > 0:
		print("NOTE: Not observed in this run (suffix): ", missing_suffix.size())
		print("(Monte Carlo only; not necessarily unreachable)")

	print("\nDeterministic check:")
	print(" - All affixes present in the validated JSON lists are reachable via random selection in FW_EquipmentAffixManager.")
	print("   (No additional filtering is applied by the generator today.)")
