extends Resource

class_name FW_Combatant

# (debug scaffolding removed)

# Common properties for both players and monsters/other players
@export var texture: Texture2D
@export var name: String
@export_multiline var description: String
@export var affinities: Array[FW_Ability.ABILITY_TYPES]
@export var abilities: Array[FW_Ability] = []
@export var stats: FW_StatsManager
@export var buffs: FW_BuffManager

# Combat data (can be initialized from different sources)
var base_hp: int = 0
var base_shields: int = 0

# Player-specific data (only used for actual players)
@export var character_effects: Dictionary = {}  # For base character bonuses
@export var equipment: Array[FW_Equipment] = []
@export var unlocked_abilities: Array[FW_Ability] = []

# Metadata for PvP
@export var is_ai_controlled: bool = false
@export var ai_type: FW_MonsterAI.monster_ai = FW_MonsterAI.monster_ai.RANDOM
@export var player_id: String = ""  # For uploaded player data
@export var difficulty_level: int = 1  # For scaling downloaded players
@export var job_name: String = ""  # Job name for PvP display
@export var job_color: Color = Color.WHITE  # Job color for PvP display
@export var is_pvp_opponent: bool = false  # Flag to distinguish PvP opponents from regular monsters
@export var ascension_level: int = 0  # Ascension level for filtering

# Combat AI selector (only used if is_ai_controlled)
var ai: FW_MoveSelector

func setup() -> void:
	"""Initialize the combatant for combat"""
	# setup debug removed
	if is_ai_controlled:
		setup_ai()
	
	# Initialize base HP/shields from either character effects or direct values
	if character_effects.has("hp"):
		base_hp = character_effects["hp"]
	
	if stats:
		stats.setup_equipment()
		if stats.has_method("setup_ability_stats"):
			stats.setup_ability_stats()

func setup_ai() -> void:
	"""Setup AI for non-player combatants"""
	# setup_ai debug removed
	match ai_type:
		FW_MonsterAI.monster_ai.RANDOM:
			ai = FW_RandomSelector.new()
		FW_MonsterAI.monster_ai.SENTIENT:
			ai = FW_SentientSelector.new()
		FW_MonsterAI.monster_ai.BOMBER:
			ai = FW_BomberSelector.new()
			ai.next_selector = FW_SentientSelector.new()
			ai.next_selector.next_selector = FW_RandomSelector.new()
		FW_MonsterAI.monster_ai.SELF_AWARE:
			ai = FW_SelfAwareSelector.new()
			ai.next_selector = FW_BomberSelector.new()
			ai.next_selector.next_selector = FW_SentientSelector.new()
			ai.next_selector.next_selector.next_selector = FW_RandomSelector.new()
		_:
			printerr("AI type not implemented: ", ai_type)

# Factory methods to create combatants from existing resources
static func from_player_data(player: FW_Player) -> FW_Combatant:
	"""Create a combatant from player data for PvP"""
	var combatant = FW_Combatant.new()
	combatant.texture = player.character.texture
	combatant.name = player.character.name
	combatant.description = player.character.description
	combatant.affinities = player.character.affinities
	combatant.abilities = player.abilities.filter(func(a): return a != null)
	combatant.stats = player.stats.duplicate(true)  # Deep copy
	combatant.buffs = player.buffs.duplicate(true) if player.buffs else FW_BuffManager.new()
	# Mark duplicated/new BuffManager as belonging to a (opponent) monster so
	# BuffManager emits monster-side signals and updates the correct UI.
	if combatant.buffs:
		combatant.buffs.set_meta("owner_type", "monster")
	# Mark stats as a PvP opponent so StatsManager can return precomputed PvP values
	if combatant.stats:
		combatant.stats._is_pvp_opponent = true
	combatant.character_effects = player.character.effects
	combatant.equipment = player.equipment
	combatant.unlocked_abilities = player.unlocked_abilities
	combatant.is_ai_controlled = true  # Other players are AI controlled
	combatant.ai_type = FW_MonsterAI.monster_ai.SENTIENT  # Use smart AI for players
	combatant.player_id = "player_" + str(Time.get_unix_time_from_system())
	# from_player_data debug removed
	return combatant

static func from_monster_data(monster: FW_Monster_Resource) -> FW_Combatant:
	"""Create a combatant from monster data"""
	var combatant = FW_Combatant.new()
	combatant.texture = monster.texture
	combatant.name = monster.name
	combatant.description = monster.description
	combatant.affinities = monster.affinities
	combatant.abilities = monster.abilities
	combatant.stats = monster.stats.duplicate(true) if monster.stats else FW_StatsManager.new()
	combatant.buffs = monster.buffs.duplicate(true) if monster.buffs else FW_BuffManager.new()
	# Ensure BuffManager metadata marks this as monster-owned
	if combatant.buffs:
		combatant.buffs.set_meta("owner_type", "monster")
	if combatant.stats:
		combatant.stats._is_pvp_opponent = false
	# from_monster_data debug removed
	combatant.base_hp = monster.max_hp
	combatant.base_shields = monster.shields
	combatant.is_ai_controlled = true
	combatant.ai_type = monster.ai_type
	return combatant

static func from_current_player() -> FW_Combatant:
	"""Create a combatant from the current player (for the player side in combat)"""
	var combatant = FW_Combatant.new()
	combatant.texture = GDM.player.character.texture
	combatant.name = GDM.player.character.name
	combatant.description = GDM.player.character.description
	combatant.affinities = GDM.player.character.affinities
	combatant.abilities = GDM.player.abilities.filter(func(a): return a != null)
	combatant.stats = GDM.player.stats  # Reference, not copy
	combatant.buffs = GDM.player.buffs if GDM.player.buffs else FW_BuffManager.new()
	# Current player is the player side for buff signals
	if combatant.buffs:
		combatant.buffs.set_meta("owner_type", "player")
	if combatant.stats:
		combatant.stats._is_pvp_opponent = false
	# from_current_player debug removed
	combatant.character_effects = GDM.player.character.effects
	combatant.equipment = GDM.player.equipment
	combatant.unlocked_abilities = GDM.player.unlocked_abilities
	combatant.is_ai_controlled = false  # Current player is human controlled
	return combatant

func get_max_hp() -> int:
	"""Calculate max HP with all modifiers"""
	var hp = base_hp
	if character_effects.has("hp"):
		hp += character_effects["hp"]
	if stats:
		hp += stats.get_stat("hp")
	return max(hp, 1)

func get_max_shields() -> int:
	"""Calculate max shields with all modifiers"""
	var shields = base_shields
	if stats:
		shields += stats.get_stat("shields")
	return max(shields, 0)

func _to_string() -> String:
	return "[Combatant: %s (%s)]" % [name, "AI" if is_ai_controlled else "Human"]
