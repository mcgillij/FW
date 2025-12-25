extends RefCounted

class_name FW_EquipmentAffixManager

var prefixes: Array = []
var suffixes: Array = []

func _init():
	_load_affixes()

func _load_affixes():
	prefixes = _load_affix_list("res://Equipment/prefixes.json")
	suffixes = _load_affix_list("res://Equipment/suffixes.json")

func _load_affix_list(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if typeof(data) != TYPE_ARRAY:
			push_error("EquipmentAffixManager: expected Array in '%s'" % path)
			FW_Debug.debug_log(["[EquipmentAffixManager] invalid JSON root; expected Array:", path], FW_Debug.Level.ERROR)
			return []
		var cleaned: Array = []
		for i in range(data.size()):
			var affix = data[i]
			if typeof(affix) != TYPE_DICTIONARY:
				push_warning("EquipmentAffixManager: skipping non-dictionary affix in '%s' at index %d" % [path, i])
				FW_Debug.debug_log(["[EquipmentAffixManager] skipping non-dictionary affix", path, "index=", i], FW_Debug.Level.WARN)
				continue
			if not affix.has("name") or typeof(affix.name) != TYPE_STRING:
				push_warning("EquipmentAffixManager: skipping affix missing string 'name' in '%s' at index %d" % [path, i])
				FW_Debug.debug_log(["[EquipmentAffixManager] skipping affix missing name", path, "index=", i], FW_Debug.Level.WARN)
				continue
			if not affix.has("effect") or typeof(affix.effect) != TYPE_DICTIONARY:
				push_warning("EquipmentAffixManager: skipping affix '%s' with missing dict 'effect' in '%s'" % [affix.name, path])
				FW_Debug.debug_log(["[EquipmentAffixManager] skipping affix missing effect", affix.name, "path=", path], FW_Debug.Level.WARN)
				continue

			var is_valid := true
			# Validate keys and convert [min,max] arrays to Vector2.
			for stat in affix.effect.keys():
				var stat_key := str(stat)
				if not FW_StatsManager.STAT_NAMES.has(stat_key):
					push_warning("EquipmentAffixManager: skipping affix '%s' with unknown stat key '%s' in '%s'" % [affix.name, stat_key, path])
					FW_Debug.debug_log(["[EquipmentAffixManager] unknown stat key; skipping affix", affix.name, "key=", stat_key, "path=", path], FW_Debug.Level.WARN)
					is_valid = false
					break
				var stat_range = affix.effect[stat]
				if typeof(stat_range) != TYPE_ARRAY or stat_range.size() != 2:
					push_warning("EquipmentAffixManager: skipping affix '%s' invalid range for '%s' in '%s' (expected [min,max])" % [affix.name, stat_key, path])
					FW_Debug.debug_log(["[EquipmentAffixManager] invalid range; skipping affix", affix.name, "key=", stat_key, "range=", stat_range], FW_Debug.Level.WARN)
					is_valid = false
					break
				if typeof(stat_range[0]) not in [TYPE_INT, TYPE_FLOAT] or typeof(stat_range[1]) not in [TYPE_INT, TYPE_FLOAT]:
					push_warning("EquipmentAffixManager: skipping affix '%s' non-numeric range for '%s' in '%s'" % [affix.name, stat_key, path])
					FW_Debug.debug_log(["[EquipmentAffixManager] non-numeric range; skipping affix", affix.name, "key=", stat_key, "range=", stat_range], FW_Debug.Level.WARN)
					is_valid = false
					break
				affix.effect[stat_key] = Vector2(float(stat_range[0]), float(stat_range[1]))
				if stat_key != stat:
					affix.effect.erase(stat)

			if not is_valid:
				continue
			cleaned.append(affix)
		return cleaned
	return []

func get_random_prefix() -> Dictionary:
	if prefixes.is_empty():
		push_error("Prefixes list is empty")
		return {}
	return prefixes[randi() % prefixes.size()]

func get_random_suffix() -> Dictionary:
	if suffixes.is_empty():
		push_error("Suffixes list is empty")
		return {}
	return suffixes[randi() % suffixes.size()]

func roll_effects(effect_dict: Dictionary) -> Dictionary:
	var rolled_effects = {}
	for stat in effect_dict.keys():
		var value = effect_dict[stat]
		if typeof(value) == TYPE_VECTOR2:
			rolled_effects[stat] = randf_range(value.x, value.y)
		else:
			rolled_effects[stat] = value
	return rolled_effects

func convert_int_stats(effects: Dictionary) -> Dictionary:
	for stat in GDM.player.stats.INT_STATS:
		if effects.has(stat):
			effects[stat] = int(effects[stat])
	return effects

func are_affixes_loaded() -> bool:
	return not prefixes.is_empty() and not suffixes.is_empty()
