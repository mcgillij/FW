extends RefCounted
class_name FW_Platform

static func is_steam_deck() -> bool:
	# Best-effort detection. Steam Deck exports commonly include the "steamdeck" feature.
	if OS.has_feature("steamdeck"):
		return true
	# Fallback heuristic (kept intentionally conservative).
	return false
