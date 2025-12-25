extends Node

class_name FW_Colors
# probably gonna have to move all my colors in here at some point,
# they are strewn about everywhere

const bark = Color(1.0, 0.333, 0.333)
const reflex = Color(0.314, 0.98, 0.482)
const alertness = Color(0.384, 0.447, 0.643)
const vigor = Color(1.0, 0.722, 0.424)
const enthusiasm = Color(1.0, 0.475, 0.776)

# Map for static lookup by name (lowercase keys)
const _MAP := {
	"bark": bark,
	"reflex": reflex,
	"alertness": alertness,
	"vigor": vigor,
	"enthusiasm": enthusiasm,
}

const _MANA_COLOR_MAP := {
	"red": bark,
	"blue": alertness,
	"green": reflex,
	"orange": vigor,
	"pink": enthusiasm,
}

# Map from FW_Ability.ABILITY_TYPES to our mana color keys for affinities.
# Using ints (enum values) for keys so callers can pass FW_Ability.ABILITY_TYPES.* directly.
const _AFFINITY_TO_MANA_KEY := {
	FW_Ability.ABILITY_TYPES.Bark: "red",
	FW_Ability.ABILITY_TYPES.Reflex: "green",
	FW_Ability.ABILITY_TYPES.Alertness: "blue",
	FW_Ability.ABILITY_TYPES.Vigor: "orange",
	FW_Ability.ABILITY_TYPES.Enthusiasm: "pink",
}

static func get_stat_color(stat:FW_Stat) -> Color:
	var k = stat.stat_name.to_lower()
	if _MAP.has(k):
		return _MAP[k]
	return Color(1,1,1)

# Static helpers so other code can call FW_Colors.has(name) / FW_Colors.get(name)
static func has_color(key: String) -> bool:
	if key == null:
		return false
	return _MAP.has(key.to_lower())

static func get_color(key: String):
	if key == null:
		return null
	return _MAP.get(key.to_lower(), null)


static func get_mana_color(key: String) -> Color:
	if key == null:
		return Color.WHITE
	return _MANA_COLOR_MAP.get(key.to_lower(), Color.WHITE)


static func get_affinity_mana_key(affinity) -> String:
	"""Return the mana key string for a given affinity
	Accepts either an ABILITY_TYPES enum or a string key (case-insensitive).
	"""
	if affinity == null:
		return ""

	# Accept the ABILITY_TYPES enums (which are integers)
	if typeof(affinity) == TYPE_INT:
		if _AFFINITY_TO_MANA_KEY.has(affinity):
			return _AFFINITY_TO_MANA_KEY[affinity]
		return ""

	# Or accept strings for convenience
	if typeof(affinity) == TYPE_STRING:
		var s = affinity.to_lower()
		# Accept either the explicit mana color keys or ability type names
		if _MANA_COLOR_MAP.has(s):
			return s
		# Try mapping from ability name (like "bark")
		if _MAP.has(s):
			var fallback := {
				"bark": "red",
				"reflex": "green",
				"alertness": "blue",
				"vigor": "orange",
				"enthusiasm": "pink",
			}
			return fallback.get(s, "")
		return ""

	# Default fallback
	return ""


static func get_color_for_affinities(affinities: Array) -> Color:
	"""Blend and return a Color for a list of affinities.

	- Accepts an Array of FW_Ability.ABILITY_TYPES or strings.
	- If affinities is empty or null, returns Color.WHITE.
	- Blending is a simple linear average across channels (RGB). Alpha is set to 1.0.
	"""
	if affinities == null or affinities.is_empty():
		return Color(1,1,1)

	var colors := []
	for aff in affinities:
		var key := get_affinity_mana_key(aff)
		if key == "":
			continue
		var c := get_mana_color(key)
		if c != null:
			colors.append(c)

	if colors.is_empty():
		return Color(1,1,1)

	# Compute average color channels
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	var a: float = 0.0
	for c in colors:
		r += c.r
		g += c.g
		b += c.b
		a += c.a
	var count := float(colors.size())
	return Color(r / count, g / count, b / count, a / count)


# Helper: convert Color to HTML hex (eg #rrggbb)
static func _color_to_html(c: Color) -> String:
	# Convert Color to #rrggbb using integer channels to ensure stable output
	var r = int(c.r * 255.0)
	var g = int(c.g * 255.0)
	var b = int(c.b * 255.0)
	return "#%02X%02X%02X" % [r, g, b]


# Wrap a piece of text in BBCode color tags (optionally bold)
static func colorize_text(text: String, c: Color, bold: bool=false) -> String:
	var col := FW_Colors._color_to_html(c)
	var s := "[color=%s]%s[/color]" % [col, text]
	if bold:
		s = "[b]" + s + "[/b]"
	return s


# Rainbow-ify a string by coloring each letter from our primary colors in order
static func rainbowize(text: String) -> String:
	var cols := [bark, reflex, alertness, vigor, enthusiasm]
	var out := ""
	var idx := 0
	for ch in text:
		var s := String(ch)
		if s == " ":
			out += s
			continue
		var col = cols[idx % cols.size()]
		out += FW_Colors.colorize_text(s, col, false)
		idx += 1
	return out


# Replace occurrences inside a RichTextLabel's text with colored/bold BBCode variants.
# mapping: Dictionary where key is substring to find, value is either a Color, the string name of
# a Colors property (eg "bark"), or the special string "rainbow" to apply per-letter rainbow.

static func build_bbcode(text: String, mapping: Dictionary) -> String:
	var s := String(text)
	var out := ""
	var lower := s.to_lower()
	var pos := 0
	var text_len := s.length()
	var keys := mapping.keys()

	while pos < text_len:
		var best_key : String = ""
		var best_len := 0
		for k in keys:
			var kl = k.length()
			if pos + kl <= text_len and lower.substr(pos, kl) == k.to_lower():
				if kl > best_len:
					best_len = kl
					best_key = k
		if best_key != "":
			var matched_text = s.substr(pos, best_len)
			var val = mapping[best_key]
			if typeof(val) == TYPE_STRING and val == "rainbow":
				out += rainbowize(matched_text)
				pos += best_len
				continue
			var color_val = null
			if val is Color:
				color_val = val
			elif typeof(val) == TYPE_STRING:
				var candidate = FW_Colors.get_color(val)
				if candidate is Color:
					color_val = candidate
				elif String(val).strip_edges().begins_with("#"):
					var hex = String(val).strip_edges().substr(1, 6)
					var r = int("0x" + hex.substr(0, 2))
					var g = int("0x" + hex.substr(2, 2))
					var b = int("0x" + hex.substr(4, 2))
					color_val = Color(r / 255.0, g / 255.0, b / 255.0)
			if color_val != null and color_val is Color:
				out += colorize_text(matched_text, color_val)
			else:
				out += matched_text
			pos += best_len
		else:
			out += s.substr(pos, 1)
			pos += 1

	return out


static func inject_into_label(label: RichTextLabel, mapping: Dictionary) -> void:
	var s := ""
	if label.text != "":
		s = label.text
	else:
		s = label.bbcode_text
	var out = build_bbcode(s, mapping)
	label.bbcode_enabled = true
	label.bbcode_text = out


# end of inject_into_label

static func inject_into_plain_label(label: Label, mapping: Dictionary) -> void:
	# Plain Labels in Godot 4 do not support BBCode. If we receive a RichTextLabel
	# through this path, delegate to the richer injector. Otherwise tint the label
	# using the first resolved Color found in the mapping.
	if label == null:
		return
	if label.text == "":
		return
	var resolved_color := Color()
	var found_color := false
	for key in mapping.keys():
		var value = mapping[key]
		if value is Color:
			resolved_color = value
			found_color = true
			break
		elif typeof(value) == TYPE_STRING:
			var candidate = FW_Colors.get_color(value)
			if candidate is Color:
				resolved_color = candidate
				found_color = true
				break
	if found_color:
		label.self_modulate = resolved_color
