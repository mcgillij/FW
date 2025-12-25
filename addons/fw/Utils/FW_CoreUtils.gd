extends RefCounted
class_name FW_CoreUtils

static func to_percent(value: float, decimals: int = 0) -> String:
	return "%.{0}f%%".format([decimals]) % (value * 100)

static func merge_dict_numbers(dict_one: Dictionary, dict_two: Dictionary) -> Dictionary:
	var merged := dict_one.duplicate()

	for key in dict_one.keys():
		if dict_two.has(key):
			merged[key] = dict_one[key] + dict_two[key]

	for key in dict_two.keys():
		if not dict_one.has(key):
			merged[key] = dict_two[key]

	return merged
static func merge_dict(dict_one: Dictionary, dict_two: Dictionary) -> Dictionary:
	return merge_dict_numbers(dict_one, dict_two)

static func count_array(arr: Array) -> Dictionary:
	var counts := {}
	for item in arr:
		if counts.has(item):
			counts[item] += 1
		else:
			counts[item] = 1
	return counts

static func count_types(types: Array) -> Dictionary:
	var counts := {}
	for type in types:
		var normalized_type := str(type).to_lower()
		if not counts.has(normalized_type):
			counts[normalized_type] = 0
		counts[normalized_type] += 1
	return counts

static func normalize_color(v: Variant) -> Color:
	if v == null:
		return Color.WHITE
	if v is Color:
		return v

	if typeof(v) == TYPE_STRING or v is StringName:
		var s := str(v).strip_edges()
		if s.length() in [6, 8] and not s.begins_with("#"):
			s = "#" + s
		return Color(s)

	if v is Array and v.size() >= 3:
		var r := float(v[0])
		var g := float(v[1])
		var b := float(v[2])
		var a := 1.0
		if v.size() >= 4:
			a = float(v[3])
		if r > 1.0 or g > 1.0 or b > 1.0:
			r /= 255.0
			g /= 255.0
			b /= 255.0
		if a > 1.0:
			a /= 255.0
		return Color(r, g, b, a)

	if v is Dictionary:
		var r := float(v.get("r", 0))
		var g := float(v.get("g", 0))
		var b := float(v.get("b", 0))
		var a := float(v.get("a", 1))
		if r > 1.0 or g > 1.0 or b > 1.0:
			r /= 255.0
			g /= 255.0
			b /= 255.0
		if a > 1.0:
			a /= 255.0
		return Color(r, g, b, a)

	return Color.WHITE

static func combine_percentile_dice(percentile: int, ones: int) -> int:
	var total := percentile + ones
	if percentile == 0 and ones == 0:
		return 100
	return total
