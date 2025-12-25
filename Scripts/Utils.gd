extends RefCounted

class_name FW_Utils

class ShaderValues:
	# glow / highlight shaders
	var glow_intensity := 1.0
	var speed := 2.0
	# fractal
	var time_speed : float = 1.0
	var zoom_speed : float = 0.05
	var initial_zoom_factor : float = 2.0

	func muck_with_shader_values(delta, item_with_shader) -> void:
		if item_with_shader:
			glow_intensity += delta * speed
			if glow_intensity >= 3.0 and speed > 0 or glow_intensity <= 1.0 and speed < 0:
				speed *= -1.0
			item_with_shader.get_material().set_shader_parameter("glow_intensity", glow_intensity)

	func toggle_on_highlight_shader(item_with_shader) -> void:
		if item_with_shader:
			item_with_shader.get_material().set_shader_parameter("highlight_strength", 0.5)

	func toggle_off_highlight_shader(item_with_shader) -> void:
		if item_with_shader:
			item_with_shader.get_material().set_shader_parameter("highlight_strength", 0)

static func to_percent(value: float, decimals: int = 0) -> String:
	return "%.{0}f%%".format([decimals]) % (value * 100)

# Merge new effects into existing ones
static func merge_dict(dict_one: Dictionary, dict_two: Dictionary) -> Dictionary:
	var dict := dict_one.duplicate()
	# Handle keys from dict_one that exist in dict_two
	for key in dict_one.keys():
		if dict_two.has(key):
			dict[key] = dict_one[key] + dict_two[key]

	# Add any keys that only exist in dict_two
	for key in dict_two.keys():
		if not dict_one.has(key):
			dict[key] = dict_two[key]
	return dict

static func count_array(arr: Array) -> Dictionary:
	var dict := {}
	for a in arr:
		if dict.has(a):
			dict[a] += 1
		else:
			dict[a] = 1
	return dict

static func format_effects(effects: Dictionary) -> String:
	var effects_string := ""
	for stat in effects.keys():
		var value = effects[stat]
		if value is Dictionary:
			#if value.is_empty():
			continue
		elif value is String:
			continue
		elif value is StringName:
			continue
		elif value is bool:
			continue
		elif value == 0 or value == 0.0:
			continue
		if stat in FW_StatsManager.INT_STATS or stat == "cooldown":
			effects_string += stat.capitalize() + ": " + str(int(round(value))) + "\n"
		else:
			#var Utils = load("res://Scripts/FW_Utils.gd")
			effects_string += stat.capitalize() + ": " + FW_Utils.to_percent(value if value else 0) + "\n"
	return effects_string

static func get_difficulty(diff: FW_SkillCheckRes.DIFF) -> int:
	match diff:
		FW_SkillCheckRes.DIFF.SIMPLE:
			return randi_range(25, 35)
		FW_SkillCheckRes.DIFF.EASY:
			return randi_range(35, 45)
		FW_SkillCheckRes.DIFF.MEDIUM:
			return randi_range(45, 55)
		FW_SkillCheckRes.DIFF.HARD:
			return randi_range(65, 75)
		FW_SkillCheckRes.DIFF.EXTREME:
			return randi_range(75, 85)
	return 0

static func translate_monster_type_to_diff(monster: FW_Monster_Resource) -> FW_SkillCheckRes.DIFF:
	match monster.type:
		FW_Monster_Resource.monster_type.SCRUB:
			return FW_SkillCheckRes.DIFF.SIMPLE
		FW_Monster_Resource.monster_type.GRUNT:
			return FW_SkillCheckRes.DIFF.EASY
		FW_Monster_Resource.monster_type.ELITE:
			return FW_SkillCheckRes.DIFF.HARD
		FW_Monster_Resource.monster_type.BOSS:
			return FW_SkillCheckRes.DIFF.EXTREME
	return FW_SkillCheckRes.DIFF.SIMPLE

static func count_types(types: Array) -> Dictionary:
	var counts := {}
	for type in types:
		# Convert to lowercase to make it case-insensitive
		var normalized_type = type.to_lower()
		if not counts.has(normalized_type):
			counts[normalized_type] = 0
		counts[normalized_type] += 1
	return counts

# Function to blend colors based on array of types
static func blend_type_colors(types: Array) -> Color:
	var counts = count_types(types)
	var total_count := float(types.size())
	var blended_color := Color(0, 0, 0, 1)

	# Handle empty array
	if total_count == 0:
		return Color.WHITE

	# Blend colors based on their frequency in the array
	for type in counts:
		if FW_Ability.TYPE_COLORS.has(type):
			var weight = counts[type] / total_count
			var type_color = FW_Ability.TYPE_COLORS[type]

			# Add weighted components
			blended_color.r += type_color.r * weight
			blended_color.g += type_color.g * weight
			blended_color.b += type_color.b * weight

	return blended_color

static func normalize_color(v) -> Color:
	"""Defensive helper: accept multiple color formats and return a Color.
	Accepts: Color, String/hex, Array [r,g,b,(a)], Dictionary {r,g,b,(a)}, or null.
	Returns Color.WHITE on invalid input.
	"""
	if v == null:
		return Color.WHITE
	if v is Color:
		return v
	# Strings: allow "#rrggbb", "rrggbb", or color names parseable by Color()
	if typeof(v) == TYPE_STRING or v is StringName:
		var s := str(v).strip_edges()
		if s.length() in [6, 8] and not s.begins_with("#"):
			s = "#" + s
		# Color() can accept HTML style strings
		var c := Color()
		c = Color(s)
		return c
	# Arrays: [r,g,b] or [r,g,b,a]
	if v is Array and v.size() >= 3:
		var r = float(v[0])
		var g = float(v[1])
		var b = float(v[2])
		var a = 1.0
		if v.size() >= 4:
			a = float(v[3])
		if r > 1.0 or g > 1.0 or b > 1.0:
			r /= 255.0
			g /= 255.0
			b /= 255.0
		if a > 1.0:
			a /= 255.0
		return Color(r, g, b, a)
	# Dictionary: keys "r","g","b","a"
	if v is Dictionary:
		var r = float(v.get("r", 0))
		var g = float(v.get("g", 0))
		var b = float(v.get("b", 0))
		var a = float(v.get("a", 1))
		if r > 1.0 or g > 1.0 or b > 1.0:
			r /= 255.0
			g /= 255.0
			b /= 255.0
		if a > 1.0:
			a /= 255.0
		return Color(r, g, b, a)
	# Fallback
	return Color.WHITE

static func job_color_from_ability_types(ability_types: Array) -> Color:
	"""Compute a display color for a job from an array of ability descriptors.
	Accepts ability enum ints, strings, or ability resource objects (with .ability_type).
	Uses FW_Ability.ABILITY_TYPES to normalize to names and then blends using `blend_type_colors`.
	"""
	if ability_types == null or ability_types.size() == 0:
		return Color.WHITE
	var normalized := []
	for a in ability_types:
		if typeof(a) == TYPE_INT:
			# resolve enum name
			for n in FW_Ability.ABILITY_TYPES.keys():
				if FW_Ability.ABILITY_TYPES[n] == a:
					normalized.append(str(n).to_lower())
					break
		elif typeof(a) == TYPE_STRING or a is StringName:
			# Already a textual ability type
			normalized.append(str(a).to_lower())
		elif a and (a.has_method("get_ability_type") or a.has_method("get")):
			# If the item is an ability resource/object, safely read ability_type
			var t = 0
			if a.has_method("get_ability_type"):
				t = a.get_ability_type()
			elif a.has_method("get"):
				# Use get("ability_type") when available; may return 0 which is valid
				t = a.get("ability_type")
			for n in FW_Ability.ABILITY_TYPES.keys():
				if FW_Ability.ABILITY_TYPES[n] == t:
					normalized.append(str(n).to_lower())
					break
		# ignore anything else
	# Fallback to white if nothing normalized
	if normalized.size() == 0:
		return Color.WHITE
	return blend_type_colors(normalized)

static func get_version_info() -> String:
	var preset = ConfigFile.new()
	preset.load("res://export_presets.cfg")
	var version = preset.get_value("preset.3.options", "version/code")
	return str(version)

static func _is_steam_deck() -> bool:
	if RenderingServer.get_rendering_device().get_device_name().contains("RADV VANGOGH") \
	or OS.get_processor_name().contains("AMD CUSTOM APU 0405") or OS.get_processor_name().contains("AMD CUSTOM APU 0932"):
		return true
	else:
		return false

static func _combine_percentile_dice(percentile: int, ones: int) -> int:
	var total = percentile + ones
	if percentile == 0 and ones == 0:
		return 100
	return total

static func shader_material() -> ShaderMaterial:
	var shader := ShaderMaterial.new()
	shader.shader = load("res://Shaders/BorderHilight.gdshader").duplicate()
	shader.set_shader_parameter("outline_color", Color.YELLOW)
	shader.set_shader_parameter("outline_thickness", 5.0)
	return shader
