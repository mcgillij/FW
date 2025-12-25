class_name FW_LevelNameGenerator
extends RefCounted

# Static data arrays for name generation
static var _adjectives: PackedStringArray = [
	"Ancient", "Whispering", "Shadowy", "Forgotten", "Mystic", "Silent", "Grim", "Sunken",
	"Emerald", "Crimson", "Azure", "Golden", "Silver", "Iron", "Stone", "Crystal",
	"Haunted", "Lost", "Hidden", "Sacred", "Cursed", "Blasted", "Winding", "Echoing"
]

static var _nouns: PackedStringArray = [
	"Ruins", "Forest", "Caverns", "Peaks", "Valley", "Swamp", "Wastes", "Citadel",
	"Crypt", "Labyrinth", "Grove", "Sanctuary", "Abyss", "Nexus", "Spire", "Dungeon",
	"Keep", "Outpost", "Pass", "River", "Lake", "Falls", "Glade", "Mire"
]

# Instance method for backward compatibility
func generate_name(context, node_type: String, extra_data: String = "") -> Array:
	return FW_LevelNameGenerator.generate_name_static(context, node_type, extra_data)

# Static method for direct use
static func generate_name_static(context, node_type: String, extra_data: String = "") -> Array:
	var seed_string = context.get_seed_string(node_type + extra_data)
	var hash_value = seed_string.hash()

	var rng = RandomNumberGenerator.new()
	rng.seed = abs(hash_value)

	var adjective = _adjectives[rng.randi_range(0, _adjectives.size() - 1)]
	var noun = _nouns[rng.randi_range(0, _nouns.size() - 1)]
	var suffix = str(abs(hash_value) % 1000).pad_zeros(3)

	var full_name = "%s %s %s" % [adjective, noun, suffix]
	var display_name = "%s %s" % [adjective, noun]

	return [full_name, display_name]

# Utility method for generating names with explicit parameters
static func generate_name_from_seed(seed_value: int, _node_type: String = "") -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = abs(seed_value)

	var adjective = _adjectives[rng.randi_range(0, _adjectives.size() - 1)]
	var noun = _nouns[rng.randi_range(0, _nouns.size() - 1)]
	var suffix = str(abs(seed_value) % 1000).pad_zeros(3)

	var full_name = "%s %s %s" % [adjective, noun, suffix]
	var display_name = "%s %s" % [adjective, noun]

	return [full_name, display_name]
