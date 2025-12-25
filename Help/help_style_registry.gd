# Central registry for help/tutorial token styles
# Each entry maps a token (exact substring) to a value:
# - a Color constant name defined in FW_Colors.gd (eg "bark"), or
# - the special string "rainbow" for per-letter coloring

const TOKENS := {
	# Primary stats / affinities
	"Bark": "bark",
	"Reflex": "reflex",
	"Alertness": "alertness",
	"Vigor": "vigor",
	"Enthusiasm": "enthusiasm",
	"BRAVE": "rainbow",

	# Abilities / keywords (existing)
	"Berzerk": "bark",
	"Brace": "reflex",
	"blurry": "alertness",
	"Claw Rank3": "vigor",
	"Craze": "enthusiasm",

	# Gameplay keywords (existing)
	"Rainbow": "rainbow",

	# Additional tokens (from corpus analysis)
	"unlock abilities": "vigor",
	"lifesteal": "bark",
	"shield regeneration": "reflex",
	"evasion": "alertness",
	"break 3 rows": "vigor",
	"ability slots": "enthusiasm",
	"choose carefully": "enthusiasm",

	"affinity": "vigor",
	"matching tiles": "reflex",
	"Adventure Mode": "enthusiasm",
	"Chain multiplier": "alertness",
	"scaling damage": "vigor",
	"bypass shields": "enthusiasm",
	"double damage to shields": "vigor",

	# make Achievements gold in the help UI (use Color objects to avoid parsing issues)
	"Achievements": Color8(255, 209, 102),
	"Achievement": Color8(255, 209, 102),
	# explicit common UI tokens with Color objects
	"Skill Tree": Color8(141, 211, 199),
	"Ascension": Color8(255, 184, 108),
	# Main menu needs higher contrast on dark backgrounds
	"Main menu": Color8(79, 211, 255),
	"Permanent unlocks": "vigor",
	"Completing puzzles": "enthusiasm",
	"loops": "reflex",
	"baseline difficulty": "vigor",
	"monster AI": "alertness",
	"scales up": "enthusiasm",

	"Rainbow Bomb": "rainbow",
	"Matching 5": "vigor",
	"clear the board": "reflex",
	"bomb combo": "enthusiasm",
	"combo": "alertness",

	# Basics and bomb-related tokens (themed)
	"Basics": "alertness",
	"Bomb": "enthusiasm",
	"Bombs": "enthusiasm",
	"T Bomb": "vigor",
	"L Bomb": "reflex",
	"TL Bomb": "reflex",

	"Bypass shields": "enthusiasm",
	"shield regen": "reflex",
	"extra HP": "vigor",
	"Critical Strike": "bark",
	"Skills": "alertness",
}

static func lookup(token: String):
	if TOKENS.has(token):
		return TOKENS[token]
	return null

# Return a resolved value for a token: either a Color object, the string "rainbow",
# or null. This resolves color names, hex colors, or raw Color objects stored in TOKENS.
static func lookup_resolved(token: String):
	var raw = lookup(token)
	return resolve_value(raw)

static func keys() -> Array:
	return TOKENS.keys()

static func find_tokens_in_text(text: String) -> Array:
	# Return a list of tokens that appear in `text'.
	# Use case-insensitive matching by comparing lowercase forms.
	var found := []
	if text == null:
		return found
	var lower_text := String(text).to_lower()
	for k in TOKENS.keys():
		var low_k := String(k).to_lower()
		if lower_text.find(low_k) != -1:
			found.append(k)
	return found


static func resolve_value(val):
	# Accepts either a Color name (String), the special string "rainbow",
	# a Color object, or a hex color string like "#rrggbb". Returns either
	# a Color or the string "rainbow" or null.
	if val == null:
		return null
	if typeof(val) == TYPE_COLOR:
		return val
	if typeof(val) == TYPE_STRING:
		if val == "rainbow":
			return "rainbow"
		var s = String(val).strip_edges()
		# if it looks like a hex color, parse it first (robust)
		if s.begins_with("#") and (s.length() == 7 or s.length() == 9):
			var hex = s.substr(1,6)
			var r = int("0x" + hex.substr(0,2))
			var g = int("0x" + hex.substr(2,2))
			var b = int("0x" + hex.substr(4,2))
			# Use integer-based constructor to avoid precision surprises
			return Color(r/255.0, g/255.0, b/255.0)
		# attempt to find a Colors property with this name via static helpers
		if FW_Colors.has_color(val):
			var c = FW_Colors.get_color(val)
			if c is Color:
				return c
	return null
