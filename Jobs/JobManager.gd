extends RefCounted
class_name FW_JobManager

const JOB_MAPPING_FILE_PATH := "res://Jobs/job_mapping_data.tres" # Define a path for your .tres file
const BASE_EFFECT_STATS_FILE_PATH := "res://Jobs/base_effect_stats.tres" # Define a path for your .tres file
const UNASSIGNED_JOB_PATH := "res://Jobs/unassigned.tres"

static var job_mapping = {}
static var base_effect_stats = {}
static var total_jobs: int = 0
static var _initialized: bool = false
static var job_cache := {}

static func _ensure_initialized() -> void:
	if _initialized:
		return
	job_mapping = load_job_mapping_from_tres(JOB_MAPPING_FILE_PATH)
	base_effect_stats = load_base_effect_stats_from_tres(BASE_EFFECT_STATS_FILE_PATH)
	total_jobs = job_mapping.size()
	if ResourceLoader.exists(UNASSIGNED_JOB_PATH):
		total_jobs += 1
	_initialized = true

static func get_all_job_entries() -> Array:
	_ensure_initialized()
	var entries: Array = []
	for pattern_key in job_mapping.keys():
		if not (pattern_key is Dictionary):
			continue
		var resource_path: String = job_mapping[pattern_key]
		var job_res: FW_Job = _load_job_resource(resource_path)
		var canonical_requirements: Dictionary = {}
		var pattern_dict: Dictionary = pattern_key
		for ability_key in pattern_dict.keys():
			var ability_name := str(ability_key)
			canonical_requirements[ability_name] = int(pattern_dict[ability_key])
		entries.append({
			"job": job_res,
			"resource_path": resource_path,
			"requirements": canonical_requirements
		})
	#entries.sort_custom(Callable(JobManager, "_compare_job_entries"))
	if ResourceLoader.exists(UNASSIGNED_JOB_PATH):
		var unassigned_job: FW_Job = _load_job_resource(UNASSIGNED_JOB_PATH)
		if unassigned_job:
			entries.append({
				"job": unassigned_job,
				"resource_path": UNASSIGNED_JOB_PATH,
				"requirements": {}
			})
	return entries

static func _load_job_resource(resource_path: String) -> FW_Job:
	if job_cache.has(resource_path):
		return job_cache[resource_path]
	if ResourceLoader.exists(resource_path):
		var res = load(resource_path)
		if res and res is FW_Job:
			job_cache[resource_path] = res
			return res
		elif res:
			printerr("[JobManager] Loaded resource at ", resource_path, " is not a Job")
	return null

static func _compare_job_entries(a: Dictionary, b: Dictionary) -> bool:
	var job_a: FW_Job = a.get("job", null)
	var job_b: FW_Job = b.get("job", null)
	var name_a := job_a.name if job_a else String(a.get("resource_path", ""))
	var name_b := job_b.name if job_b else String(b.get("resource_path", ""))
	return name_a < name_b

static func count_entries(dict: Dictionary) -> Dictionary:
	var count_dict = {}
	for key in dict.keys():
		if count_dict.has(dict[key]):
			count_dict[dict[key]] += 1
		else:
			count_dict[dict[key]] = 1
	return count_dict

static func count_ability_types(ability_types: Array) -> Dictionary:
	# Normalize ability type keys so they match the job_mapping patterns.
	# ability_types may contain ints (enum values) or strings. job_mapping uses
	# string keys like "Bark", "Reflex", etc., so convert ints to those names
	# and normalize any incoming strings to capitalized form.
	var ability_count: Dictionary = {}
	for ability in ability_types:
		if ability == null:
			continue
		var key_name := ""
		var value_type := typeof(ability)
		if value_type == TYPE_INT:
			# Resolve enum name from FW_Ability.ABILITY_TYPES (name -> int)
			for n in FW_Ability.ABILITY_TYPES.keys():
				if FW_Ability.ABILITY_TYPES[n] == ability:
					key_name = str(n)
					break
		elif value_type == TYPE_STRING:
			# Normalize to capitalized form to match mapping file keys
			key_name = str(ability)
		elif ability is FW_Ability:
			var type_index: int = int(ability.ability_type)
			if type_index >= 0 and type_index < FW_Ability.ABILITY_TYPES.size():
				key_name = FW_Ability.ABILITY_TYPES.keys()[type_index]
		elif value_type == TYPE_DICTIONARY:
			var ability_dict: Dictionary = ability
			if ability_dict.has("ability_type"):
				key_name = _resolve_ability_type_name(ability_dict["ability_type"])
			elif ability_dict.has("type"):
				key_name = _resolve_ability_type_name(ability_dict["type"])
		else:
			key_name = str(ability)

		if key_name == null or key_name == "":
			# Skip unknown ability types so we don't pollute the count with placeholders
			continue
		var canonical := str(key_name).capitalize()
		if ability_count.has(canonical):
			ability_count[canonical] += 1
		else:
			ability_count[canonical] = 1

	return ability_count

static func _resolve_ability_type_name(raw_value) -> String:
	if raw_value == null:
		return ""
	var value_type := typeof(raw_value)
	if value_type == TYPE_INT:
		for n in FW_Ability.ABILITY_TYPES.keys():
			if FW_Ability.ABILITY_TYPES[n] == raw_value:
				return str(n)
	elif value_type == TYPE_STRING:
		return str(raw_value)
	return ""

static func map_to_job(ability_count: Dictionary) -> String:
	if job_mapping.is_empty():
		return UNASSIGNED_JOB_PATH

	for pattern in job_mapping.keys():
		if _matches_ability_pattern(ability_count, pattern):
			var matched_path = job_mapping[pattern]
			return matched_path

	# No match found. Print a concise diagnostic to help debugging.
	var sample_patterns := []
	var i := 0
	for p in job_mapping.keys():
		if i >= 5:
			break
		sample_patterns.append(p)
		i += 1
	# No matching job pattern found; fall back to unassigned resource
	return UNASSIGNED_JOB_PATH

static func _matches_ability_pattern(ability_count: Dictionary, pattern: Dictionary) -> bool:
	# Check that both dictionaries have the same keys
	if ability_count.keys().size() != pattern.keys().size():
		# sizes differ; no match. Provide a small diagnostic when debugging.
		# Keep this quiet unless job_mapping seems to be failing overall.
		return false

	# Check that all pattern keys exist in ability_count with correct values
	for key in pattern.keys():
		var expected = pattern[key]
		var actual = ability_count.get(key, 0)
		if actual != expected:
			return false
	return true

static func get_job(ability_types: Array) -> FW_Job:
	_ensure_initialized()
	var ability_count = count_ability_types(ability_types)
	var job_path = map_to_job(ability_count)
	var job_res = null
	if ResourceLoader.exists(job_path):
		job_res = load(job_path)
	else:
		printerr("[JobManager] get_job: job resource not found at path: ", job_path)
	return job_res

static func get_total_jobs() -> int:
	_ensure_initialized()
	return total_jobs

static func generate_effects(stats: Dictionary) -> Dictionary:
	_ensure_initialized()
	var base_effects = {
		"Bark": ["Mighty", "Ferocious", "Relentless", "Indomitable", "Colossal"],
		"Reflex": ["Swift", "Agile", "Unpredictable", "Phantom", "Spectral"],
		"Alertness": ["Wise", "Perceptive", "Intuitive", "Insightful", "Oracle"],
		"Vigor": ["Tough", "Resilient", "Unyielding", "Fortified", "Titanic"],
		"Enthusiasm": ["Charming", "Inspiring", "Radiant", "Charismatic", "Sovereign"]
	}
	# Normalize incoming stat keys: accept enums (int) or strings; map to base_effects keys
	var highest_stats = []
	for raw_key in stats.keys():
		var key_name: String = ""
		if typeof(raw_key) == TYPE_INT:
			# Try to resolve enum name from FW_Ability.ABILITY_TYPES
			for n in FW_Ability.ABILITY_TYPES.keys():
				if FW_Ability.ABILITY_TYPES[n] == raw_key:
					key_name = n
					break
		elif typeof(raw_key) == TYPE_STRING:
			key_name = raw_key.capitalize()
		else:
			key_name = str(raw_key)
		# Only include keys that we have base_effects for
		if base_effects.has(key_name):
			highest_stats.append(key_name)

	var effects_mapping := {}
	for key in highest_stats:
		var raw_val = stats.get(key, null)
		# If original stats used enum keys, try to get value using both forms
		if raw_val == null:
			# try lower-case lookup
			raw_val = stats.get(key.to_lower(), 0)
		var level = int(clamp(min(raw_val, 5), 1, 5)) - 1  # Ensure level in 0..4
		var arr = base_effects.get(key, [])
		if arr.size() <= level or level < 0:
			continue
		var mykey = arr[level]
		if base_effect_stats.has(mykey):
			effects_mapping[mykey] = base_effect_stats[mykey]
	var totals_effects := {}
	for i in effects_mapping.keys():
		totals_effects = FW_Utils.merge_dict(totals_effects, effects_mapping[i])
	return totals_effects

static func save_job_mapping_to_tres(mapping_dict: Dictionary, file_path: String) -> void:
	var job_mapping_resource = FW_JobMappingStore.new()
	job_mapping_resource.data = mapping_dict

	# In Godot 4, ResourceSaver.save takes the resource first, then the path.
	var error = ResourceSaver.save(job_mapping_resource, file_path)

	if error == OK:
		pass
		#FW_Debug.debug_log(["Job mapping saved successfully to: ", file_path])
	else:
		printerr("Failed to save job mapping to '", file_path, "'. Error code: ", error)

static func save_base_effect_stats_to_tres(mapping_dict: Dictionary, file_path: String) -> void:
	var resource = FW_BaseEffectStatsStore.new()
	resource.data = mapping_dict

	# In Godot 4, ResourceSaver.save takes the resource first, then the path.
	var error = ResourceSaver.save(resource, file_path)

	if error == OK:
		pass
		#FW_Debug.debug_log(["Base effect stats saved successfully to: ", file_path])
	else:
		printerr("Failed to save base effect stats to '", file_path, "'. Error code: ", error)

static func load_job_mapping_from_tres(file_path: String) -> Dictionary:
	if not ResourceLoader.exists(file_path):
		#printerr("Failed to load job mapping: File does not exist at '", file_path, "'.")
		return {} # Return an empty dictionary if the file doesn't exist

	var loaded_resource = ResourceLoader.load(file_path)

	if loaded_resource == null:
		#printerr("Failed to load job mapping: ResourceLoader.load returned null for '", file_path, "'.")
		return {}

	if loaded_resource is FW_JobMappingStore:
		var job_data_resource = loaded_resource as FW_JobMappingStore
		if job_data_resource.data != null:
			return job_data_resource.data
		else:
			#printerr("Failed to load job mapping: Loaded resource '", file_path, "' (JobMappingStore) has null 'data'.")
			return {}
	else:
		#printerr("Failed to load job mapping: Loaded resource '", file_path, "' is not of expected type FW_JobMappingStore. Actual type: ", typeof(loaded_resource))
		return {}

static func load_base_effect_stats_from_tres(file_path: String) -> Dictionary:
	if not ResourceLoader.exists(file_path):
		#printerr("Failed to load base effect stats: File does not exist at '", file_path, "'.")
		return {} # Return an empty dictionary if the file doesn't exist

	var loaded_resource = ResourceLoader.load(file_path)

	if loaded_resource == null:
		#printerr("Failed to load base effect stats: ResourceLoader.load returned null for '", file_path, "'.")
		return {}

	if loaded_resource is FW_BaseEffectStatsStore:
		var stats_data_resource = loaded_resource as FW_BaseEffectStatsStore
		if stats_data_resource.data != null:
			return stats_data_resource.data
		else:
			#printerr("Failed to load base effect stats: Loaded resource '", file_path, "' (BaseEffectStatsStore) has null 'data'.")
			return {}
	else:
		#printerr("Failed to load base effect stats: Loaded resource '", file_path, "' is not of expected type FW_BaseEffectStatsStore. Actual type: ", typeof(loaded_resource))
		return {}
