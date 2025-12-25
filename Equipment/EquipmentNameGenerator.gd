extends RefCounted

class_name FW_EquipmentNameGenerator

var _last_opener_idx := -1
var _last_middle_idx := -1
var _last_closer_idx := -1

var _current_prefix_effects: Dictionary = {}
var _current_suffix_effects: Dictionary = {}

const _TEMPLATE_KEY_PREFIX := "prefix"
const _TEMPLATE_KEY_SUFFIX := "suffix"
const _TEMPLATE_KEY_SUFFIX_SHORT := "suffix_short"
const _TEMPLATE_KEY_PREFIX_ATTR := "prefix_attr"
const _TEMPLATE_KEY_SUFFIX_ATTR := "suffix_attr"

const _ALLOWED_TEMPLATE_KEYS: Array[String] = [
	_TEMPLATE_KEY_PREFIX,
	_TEMPLATE_KEY_SUFFIX,
	_TEMPLATE_KEY_SUFFIX_SHORT,
	_TEMPLATE_KEY_PREFIX_ATTR,
	_TEMPLATE_KEY_SUFFIX_ATTR,
]

const _FLAVOR_OPENERS: Array[String] = [
	"It bears the name {prefix}.",
	"They call it {suffix}.",
	"The old smiths etched {prefix} into its bones.",
	"A quiet relic, branded {suffix_short}.",
	"Forged under patient hands and bitter smoke.",
	"Pulled from a chest that should not have existed.",
	"Recovered from a battlefield no map admits to.",
	"Stolen from a shrine and somehow forgiven.",
	"Found wrapped in cloth that never frays.",
	"It looks ordinary until you hold it.",
	"A simple piece with a complicated history.",
	"A hunter’s keepsake, traded for a kingdom’s worth of gold.",
	"The metal remembers the first oath it heard.",
	"It arrives colder than the room it’s in.",
	"It warms at the edges when danger is near.",
	"It wants to be used, not admired.",
	"Its surface is calm; its intent is not.",
	"It feels light—until the moment it matters.",
	"It hums, faintly, with its own confidence.",
	"It refuses to be forgotten.",
]

const _FLAVOR_MIDDLES: Array[String] = [
	"It leans into {prefix_attr} and never apologizes.",
	"It rewards {prefix_attr} with clean, decisive outcomes.",
	"It turns {prefix_attr} into momentum.",
	"It makes {prefix_attr} feel like certainty.",
	"It demands {prefix_attr}—and pays you back in kind.",
	"It’s most honest in the hands of someone who trusts {prefix_attr}.",
	"It sharpens {prefix_attr} into something practical.",
	"It refuses panic, preferring {prefix_attr} instead.",
	"It teaches {prefix_attr} the hard way.",
	"It turns small advantages into lasting leverage.",
	"It thrives on timing and punishes sloppy rhythms.",
	"It is patient. Then suddenly it isn’t.",
	"It makes mistakes expensive—for everyone else.",
	"It doesn’t win fights. It ends them.",
	"It keeps your hands steady when the world wobbles.",
	"It’s built for choices you can’t take back.",
	"It hates waste: every motion has a purpose.",
	"It turns the second-best plan into the best one.",
	"It makes hesitation feel like a bad habit.",
	"It always seems to be in the right place.",
]

const _FLAVOR_CLOSERS: Array[String] = [
	"In the end, it leaves you with {suffix_attr}.",
	"What it takes, it returns as {suffix_attr}.",
	"It finishes every story with {suffix_attr}.",
	"It carries a trace of {suffix_attr} that lingers.",
	"It answers in {suffix_attr} when you ask too much.",
	"It makes {suffix_attr} feel inevitable.",
	"It turns {suffix_attr} into a habit.",
	"It makes room for {suffix_attr}, even under pressure.",
	"It insists the price is always paid in {suffix_attr}.",
	"It offers {suffix_attr}—but never for free.",
	"It turns close calls into clean wins.",
	"It makes the next fight feel smaller.",
	"It turns luck into a plan.",
	"It’s not kind. It’s effective.",
	"It’s a promise you get to keep.",
	"It’s a lesson written in results.",
	"It doesn’t shine. It performs.",
	"It waits for the moment you commit.",
	"It makes your instincts look like strategy.",
	"It leaves the world a little quieter.",
]

func generate_name(prefix: String, base_name: String, suffix: String) -> String:
	return prefix + " " + base_name + " " + suffix


func set_effect_context(prefix_effects: Dictionary, suffix_effects: Dictionary) -> void:
	_current_prefix_effects = prefix_effects if prefix_effects != null else {}
	_current_suffix_effects = suffix_effects if suffix_effects != null else {}


func generate_flavor_text(prefix: String, suffix: String) -> String:
	var context := _build_template_context(prefix, suffix, _current_prefix_effects, _current_suffix_effects)
	var opener := _pick_nonrepeating(_FLAVOR_OPENERS, "opener", context)
	var middle := _pick_nonrepeating(_FLAVOR_MIDDLES, "middle", context)
	var closer := _pick_nonrepeating(_FLAVOR_CLOSERS, "closer", context)
	var rendered := opener + "\n" + middle + "\n" + closer
	# Defensive: if formatting didn't substitute (or a template was edited incorrectly), fall back.
	if rendered.find("{") != -1 or rendered.find("}") != -1:
		push_warning("EquipmentNameGenerator: template substitution failed; falling back")
		FW_Debug.debug_log([
			"[EquipmentNameGenerator] template substitution failed",
			"prefix=", prefix,
			"suffix=", suffix,
			"ctx=", context
		], FW_Debug.Level.WARN)
		rendered = "Imbued with %s and bound to %s." % [context[_TEMPLATE_KEY_PREFIX_ATTR], context[_TEMPLATE_KEY_SUFFIX_ATTR]]
	return rendered

func validate_templates() -> Dictionary:
	# Returns: { ok: bool, errors: Array[String] }
	var errors: Array[String] = []
	var regex := RegEx.new()
	var compile_err := regex.compile("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
	if compile_err != OK:
		return {"ok": false, "errors": ["RegEx compile failed"]}

	var dummy_ctx := _build_template_context("Mighty", "of Strength")
	_validate_template_list(regex, dummy_ctx, "openers", _FLAVOR_OPENERS, errors)
	_validate_template_list(regex, dummy_ctx, "middles", _FLAVOR_MIDDLES, errors)
	_validate_template_list(regex, dummy_ctx, "closers", _FLAVOR_CLOSERS, errors)

	return {"ok": errors.is_empty(), "errors": errors}

func _pick_nonrepeating(templates: Array[String], kind: String, ctx: Dictionary) -> String:
	if templates.is_empty():
		return ""
	var last_idx := -1
	match kind:
		"opener":
			last_idx = _last_opener_idx
		"middle":
			last_idx = _last_middle_idx
		"closer":
			last_idx = _last_closer_idx
	var idx := randi() % templates.size()
	# Try a few times to avoid identical consecutive segments.
	for _i in range(5):
		if templates.size() <= 1 or idx != last_idx:
			break
		idx = randi() % templates.size()
	match kind:
		"opener":
			_last_opener_idx = idx
		"middle":
			_last_middle_idx = idx
		"closer":
			_last_closer_idx = idx
	return templates[idx].format(ctx)

func _validate_template_list(regex: RegEx, ctx: Dictionary, list_name: String, templates: Array[String], errors: Array[String]) -> void:
	for i in range(templates.size()):
		var t := templates[i]
		var matches := regex.search_all(t)
		for m in matches:
			var key := m.get_string(1)
			if not _ALLOWED_TEMPLATE_KEYS.has(key):
				errors.append("Template %s[%d] uses unknown placeholder '{%s}'" % [list_name, i, key])
		var rendered := t.format(ctx)
		if rendered.find("{") != -1 or rendered.find("}") != -1:
			errors.append("Template %s[%d] did not fully substitute placeholders" % [list_name, i])

func _build_template_context(prefix: String, suffix: String, prefix_effects: Dictionary = {}, suffix_effects: Dictionary = {}) -> Dictionary:
	var stat_mapping = _get_stat_mapping()
	var suffix_short := suffix.trim_prefix("of ").strip_edges()
	var prefix_attr := _attribute_from_effects(prefix_effects)
	if prefix_attr.is_empty():
		prefix_attr = str(stat_mapping.get(prefix, "mystical power"))
	var suffix_attr := _attribute_from_effects(suffix_effects)
	if suffix_attr.is_empty():
		suffix_attr = str(stat_mapping.get(suffix_short, "energy"))
	return {
		_TEMPLATE_KEY_PREFIX: prefix,
		_TEMPLATE_KEY_SUFFIX: suffix,
		_TEMPLATE_KEY_SUFFIX_SHORT: suffix_short,
		_TEMPLATE_KEY_PREFIX_ATTR: prefix_attr,
		_TEMPLATE_KEY_SUFFIX_ATTR: suffix_attr,
	}

func _attribute_from_effects(effect_dict: Dictionary) -> String:
	if effect_dict.is_empty():
		return ""
	# Pick a stat key from the dict to describe; randomized for variety.
	var keys := effect_dict.keys()
	if keys.is_empty():
		return ""
	var key := str(keys[randi() % keys.size()]).to_lower()
	var by_stat := {
		"bark": [
			"brutal bark strength",
			"iron-barked resolve",
			"thick-skinned stubbornness",
			"a knotted, old-growth toughness",
			"splinterproof endurance",
		],
		"reflex": [
			"quick reflexes",
			"knife-fast reactions",
			"a twitch of inevitability",
			"snap decisions",
			"clean timing",
		],
		"alertness": [
			"keen awareness",
			"watchful instincts",
			"a hunter’s attention",
			"eyes that miss nothing",
			"a threat-sense that won’t sleep",
		],
		"vigor": [
			"unyielding vigor",
			"second-wind stamina",
			"a stubborn heartbeat",
			"tireless drive",
			"unspent strength",
		],
		"enthusiasm": [
			"bright enthusiasm",
			"reckless optimism",
			"a spark that refuses to dim",
			"dangerous confidence",
			"an eager, restless spirit",
		],
		"affinity_damage_bonus": [
			"color-bound prowess",
			"a resonance with the wheel",
			"mana-synced violence",
			"affinity-tuned force",
			"a prismatic edge",
		],
		"hp": [
			"staying power",
			"hard-won vitality",
			"the kind of health that outlasts excuses",
			"a deeper breath",
			"life that doesn’t scare easily",
		],
		"shields": [
			"stubborn shielding",
			"layered protection",
			"a ward that holds",
			"a calm behind the storm",
			"defenses that don’t flinch",
		],
		"critical_strike_chance": [
			"ruthless precision",
			"predatory accuracy",
			"an eye for the soft spot",
			"a gambler’s timing",
			"clean openings",
		],
		"critical_strike_multiplier": [
			"finishing force",
			"a cruel follow-through",
			"overkill certainty",
			"closing power",
			"a hit that stays hit",
		],
		"evasion_chance": [
			"slippery footwork",
			"vanishing angles",
			"a habit of being elsewhere",
			"near-misses by design",
			"a shadow’s step",
		],
		"red_mana_bonus": [
			"red mana hunger",
			"ember-fed intensity",
			"a taste for red sparks",
			"heat in the veins",
			"scarlet appetite",
		],
		"green_mana_bonus": [
			"green mana flow",
			"wild growth",
			"a leaf-born pulse",
			"verdant momentum",
			"nature’s insistence",
		],
		"blue_mana_bonus": [
			"blue mana focus",
			"cold clarity",
			"a steady mind",
			"tidal calm",
			"deep-water discipline",
		],
		"orange_mana_bonus": [
			"orange mana heat",
			"a furnace grin",
			"burning impatience",
			"a flare of momentum",
			"molten urgency",
		],
		"pink_mana_bonus": [
			"pink mana spark",
			"a mischievous shimmer",
			"glittering nerve",
			"a bright, strange luck",
			"rosy static",
		],
		"red_mana_max": [
			"a deeper red reserve",
			"a larger scarlet well",
			"an emberbank that won’t empty",
			"a red horizon",
			"extra room for fury",
		],
		"green_mana_max": [
			"a deeper green reserve",
			"a wider verdant well",
			"roots that run longer",
			"extra room for growth",
			"a patient, expanding pool",
		],
		"blue_mana_max": [
			"a deeper blue reserve",
			"a wider sapphire well",
			"depth without end",
			"extra room for calm",
			"a steady, deep pool",
		],
		"orange_mana_max": [
			"a deeper orange reserve",
			"a wider amber well",
			"extra room for heat",
			"a roaring reserve",
			"a longer-burning tank",
		],
		"pink_mana_max": [
			"a deeper pink reserve",
			"a wider rose well",
			"extra room for shimmer",
			"a brighter reserve",
			"a lingering sparkstore",
		],
		"bomb_tile_bonus": [
			"volatile timing",
			"a taste for detonations",
			"danger in neat squares",
			"a fuse you can trust",
			"a demolitionist’s rhythm",
		],
		"cooldown_reduction": [
			"impatient tempo",
			"shorter waits",
			"a faster heartbeat",
			"a rush of readiness",
			"time cut down to size",
		],
		"tenacity": [
			"hard-earned grit",
			"refusal to break",
			"a jaw set against fate",
			"pain that bounces off",
			"stubborn survival",
		],
		"luck": [
			"a gambler’s edge",
			"a crooked smile from fate",
			"fortunate timing",
			"a blessed miscount",
			"improbable outcomes",
		],
		"shield_recovery": [
			"restored defenses",
			"shields that come back angry",
			"a returning ward",
			"mending protection",
			"repairs that don’t ask permission",
		],
		"lifesteal": [
			"hungry mercy",
			"borrowed life",
			"a cruel kind of healing",
			"blood-bought recovery",
			"a thief’s comfort",
		],
		"damage_resistance": [
			"unyielding protection",
			"impact-proof calm",
			"stone-cold endurance",
			"a refusal to take the full hit",
			"armor you can feel in your bones",
		],
		"extra_consumable_slots": [
			"pockets that never seem to empty",
			"room for one more trick",
			"a pack rat’s blessing",
			"extra space where there shouldn’t be any",
			"a hidden strap for spare answers",
		],
	}
	var options = by_stat.get(key, [])
	if options is Array and not options.is_empty():
		return str(options[randi() % options.size()])
	return "energy"

func _get_stat_mapping() -> Dictionary:
	return {
		"Mighty": "strength", "Swift": "speed", "Wise": "wisdom", "Sturdy": "endurance", "Charming": "charisma",
		"Fierce": "ferocity", "Agile": "agility", "Perceptive": "insight", "Resilient": "toughness", "Inspiring": "leadership",
		"Enduring": "vitality", "Unyielding": "resilience", "Bulwarked": "protection", "Fortified": "defense",
		"Stout": "endurance", "Valiant": "heroic courage", "Bold": "reckless confidence",
		"Cunning": "trickery", "Sly": "deception", "Keen": "sharp focus", "Stern": "iron discipline",
		"Blooded": "battle-hard experience", "Tempered": "measured strength", "Honed": "refined precision", "Polished": "smooth control",
		"Grim": "cold resolve", "Hollow": "quiet menace", "Vengeful": "payback", "Relentless": "unstoppable momentum",
		"Tireless": "unending stamina", "Zealous": "fanatic drive", "Reckless": "dangerous speed", "Patient": "calculated timing",
		"Sharp": "precision", "Precise": "accuracy", "Lethal": "lethality", "Deadly": "murderous intent",
		"Elusive": "evasion", "Ghostly": "stealth", "Fiery": "fire magic", "Blazing": "burning power",
		"Chilled": "cold magic", "Frozen": "icy power", "Verdant": "nature's vitality", "Lush": "overgrowth",
		"Explosive": "detonation force", "Volatile": "unpredictable power", "Hasty": "rapid energy",
		"Sparking": "electrical energy", "Static": "crackling charge", "Stormtouched": "storm-kissed power", "Cinder": "smoldering heat",
		"Frostbitten": "biting cold", "Dewed": "fresh vitality", "Rooted": "grounded resilience", "Thorned": "prickly defense",
		"Gleaming": "clean brilliance", "Radiant": "radiant energy", "Gilded": "golden confidence", "Graven": "carved intent",
		"Steadfast": "unshakeable resolve", "Lucky": "fortune", "Fortunate": "blessing",
		"Regenerative": "recovery", "Rejuvenating": "renewal", "Vampiric": "life drain", "Sanguine": "blood magic",
		"Stalwart": "defensive power", "Immovable": "unbreakable defense",
		"Thunderous": "storm power", "Arcane": "mystic energy", "Venomous": "poison mastery", "Stonebound": "earth resilience",
		"Shadowed": "dark magic", "Celestial": "divine magic", "Ethereal": "spirit essence", "Tempestuous": "wind fury",
		"Blighted": "decay power", "Astral": "cosmic energy", "Enchanted": "enchanted defense",
		"Sunlit": "sunfire", "Starlit": "quiet starlight", "Duskbound": "evening shadows", "Dawnborn": "fresh light",
		"Umbral": "shadow magic", "Voidtouched": "void energy", "Hallowed": "divine blessing", "Profane": "forbidden force",
		"Piercing": "sharp precision", "Merciless": "relentless attack", "Ferocious": "savage might", "Galvanized": "electric charge",
		"Shifting": "adaptive nature", "Empowered": "overwhelming strength", "Berserk": "uncontrollable rage",
		"Spectral": "ghostly power", "Volcanic": "magma force", "Glacial": "arctic chill",
		"Ravaging": "devastating force", "Stormforged": "storm blessing",
		"Runebound": "mystic runes", "Primeval": "ancient power", "Seismic": "earthquake force",
		"Runescarred": "ancient runes", "Sigiled": "sealed magic", "Glyphmarked": "etched sorcery", "Oathbound": "sworn purpose",
		"Dazzling": "radiant charm", "Revenant": "undying spirit", "Soulbound": "spiritual connection", "Emberforged": "fiery will",
		"Unholy": "dark sorcery", "Glimmering": "light sparkle", "Shimmering": "ethereal glow", "Eldritch": "eldritch power",
		"Bestial": "animal might", "Runic": "ancient runes", "Inferno": "blazing fire", "Moonlit": "lunar energy",
		"Starforged": "celestial crafting", "Plated": "fortified armor", "Iridescent": "shimmering defense",
		"Mystic": "arcane might", "Titanic": "colossal strength",
		"Spacious": "storage capacity", "Capacious": "holding space", "Expansive": "expansive storage",
		"Bottomless": "endless storage", "Pocketed": "extra pockets", "Stocked": "preparedness", "Provisioned": "supplies on hand",
		"Packrat": "hoarding instinct", "Haversacked": "travel readiness", "Strapped": "spare gear", "Loaded": "ready reserves",
		
		"Strength": "strength", "Dexterity": "dexterity", "Wisdom": "wisdom", "Vitality": "vitality",
		"Charisma": "charisma", "Power": "power", "Evasion": "evasion", "Insight": "insight",
		"Fortitude": "fortitude", "Leadership": "leadership", "Immortality": "life force", "Endurance": "endurance",
		"Might": "strength", "Focus": "focus", "Grit": "grit", "Resolve": "resolve",
		"Tempo": "tempo", "Readiness": "readiness", "Edge": "an advantage", "Patience": "patience", "Momentum": "momentum",
		"the Bulwark": "defense", "Protection": "protection", "Accuracy": "precision", "Precision": "accuracy",
		"Slaying": "lethality", "Carnage": "destruction", "Flames": "fire magic", "the Inferno": "infernal flames",
		"Frost": "cold magic", "Glaciers": "ice power", "Nature": "nature's force", "Growth": "natural growth",
		"the Blaze": "burning fire", "Fire": "flames", "Radiance": "radiant energy", "Brilliance": "brilliance",
		"Ash": "embers", "Cinders": "smoldering heat", "Smoke": "smoke and grit", "Embers": "warmth and ruin",
		"Tides": "flow", "Depths": "deep water calm", "Storms": "storm energy", "Lightning": "electric charge",
		"Detonation": "explosive force", "Annihilation": "complete destruction", "Speed": "quickness",
		"Haste": "hastened movements", "Willpower": "unshakable will",
		"Fortune": "luck", "Luck": "luck", "Regeneration": "regenerative power", "Renewal": "life renewal",
		"Vampires": "vampiric thirst", "Blood": "blood magic", "Shields": "shield recovery", "the Shield": "shield fortification",
		"Tenacity": "resilience", "Life": "life force", "Death": "death's embrace", "the Grave": "death",
		"Warding": "wards", "Aegis": "shielding", "Barrier": "layered protection", "Sanctuary": "safe ground",
		"Light": "light", "the Skies": "skyward energy", "Thunder": "storm energy", "the Storm": "tempestuous winds",
		"the Earth": "earth power", "Shadow": "shadow magic", "the Void": "void energy", "Ether": "spirit energy",
		"the Tempest": "wind fury", "Decay": "decay power", "the Stars": "cosmic energy", "the Arcane": "mystical force",
		"Souls": "spiritual power", "the Wolf": "animalistic might", "Beasts": "animal force", "the Titan": "giant strength",
		"Destiny": "fate", "Restoration": "restored shields",
		"the Leech": "life drain", "Bloodlust": "bloodthirst", "Resilience": "resilience",
		"Venom": "poison mastery",
		"Shadows": "darkness", "the Heavens": "divine aura", "the Ether": "spiritual energy", "Tempests": "storm power",
		"Enchantment": "magic charm", "Relentlessness": "endurance in battle", "the Savage": "untamed power", "Sparks": "electrical power",
		"Adaptability": "adaptiveness", "Rage": "fury", "Spirits": "ghostly essence", "Magma": "molten core",
		"the Tundra": "frozen landscapes", "the Forest": "forest vitality", "the Nether": "nether energy",
		"Ruin": "devastation", "Thunderstorms": "storm strength", "Runes": "ancient magic", "the Ancients": "ancient wisdom",
		"Tremors": "earthquake power", "Ember": "smoldering flame", "the Revenant": "undying spirit",
		"the Unholy": "dark sorcery", "Shimmer": "ethereal glow", "the Eldritch": "forbidden power",
		"Capacity": "storage space", "Storage": "item holding", "Expansion": "expanded capacity"
	}
