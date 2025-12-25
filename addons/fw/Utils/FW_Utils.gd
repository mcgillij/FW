extends RefCounted

# NOTE: FW_Utils is a compatibility layer.
# Prefer calling FW_CoreUtils directly in new code.

const _CORE := preload("res://addons/fw/Utils/FW_CoreUtils.gd")

# Back-compat: previous usage was `FW_Utils.ShaderValues.new()`.
const ShaderValues := preload("res://addons/fw/Utils/FW_ShaderValues.gd")

static func to_percent(value: float, decimals: int = 0) -> String:
	return _CORE.to_percent(value, decimals)

static func merge_dict(dict_one: Dictionary, dict_two: Dictionary) -> Dictionary:
	return _CORE.merge_dict(dict_one, dict_two)

static func count_array(arr: Array) -> Dictionary:
	return _CORE.count_array(arr)

static func count_types(types: Array) -> Dictionary:
	return _CORE.count_types(types)

static func normalize_color(v: Variant) -> Color:
	return _CORE.normalize_color(v)

static func _combine_percentile_dice(percentile: int, ones: int) -> int:
	return _CORE.combine_percentile_dice(percentile, ones)
