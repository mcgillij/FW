extends Resource

class_name FW_Monster_Resource

enum monster_type { SCRUB, GRUNT, ELITE, BOSS }
enum monster_subtype { MERCENARY, DEMON, ELF, MONSTROUS, ORC, SKELETON, SHADOW, VAMPIRE }

# monster information
var boss_abilities: Array = [
	"res://Abilities/BossAbilities/Castle.tres",
	"res://Abilities/BossAbilities/Chains.tres",
	"res://Abilities/BossAbilities/Fortress.tres",
	"res://Abilities/BossAbilities/Ice.tres",
	"res://Abilities/BossAbilities/PinkSlime.tres",
	"res://Abilities/BossAbilities/PoisonSlime.tres",

]
var monster_compatible_abilities: Array = [
	"res://Abilities/Resources/bite2.tres",
	"res://Abilities/Resources/bite3.tres",
	"res://Abilities/Resources/bite.tres",
	"res://Abilities/Resources/blastwave.tres",
	"res://Abilities/Resources/bleed.tres",
	"res://Abilities/Resources/blur.tres",
	"res://Abilities/Resources/bork.tres",
	"res://Abilities/Resources/brace.tres",
	"res://Abilities/Resources/brutalstrike.tres",
	"res://Abilities/Resources/chew.tres",
	"res://Abilities/Resources/claw2.tres",
	"res://Abilities/Resources/claw3.tres",
	"res://Abilities/Resources/claw.tres",
	"res://Abilities/Resources/coral_burst.tres",
	"res://Abilities/Resources/dash.tres",
	"res://Abilities/Resources/deflect.tres",
	"res://Abilities/Resources/displacement.tres",
	"res://Abilities/Resources/doubleslash2.tres",
	"res://Abilities/Resources/doubleslash3.tres",
	"res://Abilities/Resources/doubleslash.tres",
	"res://Abilities/Resources/draining_strike.tres",
	"res://Abilities/Resources/jadestrike.tres",
	"res://Abilities/Resources/Omniscience.tres",
	"res://Abilities/Resources/phaseweb2.tres",
	"res://Abilities/Resources/phaseweb3.tres",
	"res://Abilities/Resources/phaseweb.tres",
	"res://Abilities/Resources/pierce.tres",
	"res://Abilities/Resources/pindrop.tres",
	"res://Abilities/Resources/radiance.tres",
	"res://Abilities/Resources/rage.tres",
	"res://Abilities/Resources/rage_bomb.tres",
	"res://Abilities/Resources/regenerate.tres",
	"res://Abilities/Resources/rend.tres",
	"res://Abilities/Resources/sap_mana.tres",
	"res://Abilities/Resources/Scatterstrike.tres",
	"res://Abilities/Resources/shatter.tres",
	"res://Abilities/Resources/shieldbash.tres",
	"res://Abilities/Resources/shout.tres",
	"res://Abilities/Resources/Slam.tres",
	"res://Abilities/Resources/stormsurge.tres",
	"res://Abilities/Resources/thrash.tres",
	"res://Abilities/Resources/turtleup.tres",
	"res://Abilities/Resources/spiral.tres",
	"res://Abilities/Resources/spiral2.tres",
	"res://Abilities/Resources/spiral3.tres",
	"res://Abilities/Resources/berzerk.tres",
	"res://Abilities/Resources/mountain_defense.tres",
	"res://Abilities/Resources/Shields_to_Health.tres",
	"res://Abilities/Resources/evasive_recovery.tres"
]

@export var texture: Texture2D
@export var max_hp: int
@export var shields: int
@export var name: String
@export_multiline var description: String
@export var xp: int
@export var type: monster_type
@export var subtype: monster_subtype
@export var affinities: Array[FW_Ability.ABILITY_TYPES]
@export var abilities: Array[FW_Ability]
var stats: FW_StatsManager
@export var buffs: FW_BuffManager
@export var job: FW_Job
@export var ai_type: FW_MonsterAI.monster_ai
var ai: FW_MoveSelector

# Flag to indicate if this is a PvP monster with pre-configured stats
var is_pvp_monster: bool = false

# Flag to prevent re-initialization of abilities after they've been set
var abilities_initialized: bool = false

func _init():
	# Initialize stats for all monsters except PvP monsters (which get stats set externally)
	if not is_pvp_monster:
		stats = FW_StatsManager.new()
		stats.is_monster_stats = true

func setup() -> void:
	# Stats should already be initialized in _init() for regular monsters
	# or externally for PvP monsters
	if not stats and not is_pvp_monster:
		# Fallback safety check - this should not normally happen
		printerr("Monster missing stats during setup: ", name)
		stats = FW_StatsManager.new()
		stats.is_monster_stats = true

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
			printerr("AI type not implemented for this archetype")

	if abilities.size() == 0 and not is_pvp_monster and not abilities_initialized:
		#FW_Debug.debug_log(["🔧 Monster.setup(): Generating random abilities for ", name, " (", abilities.size(), " current abilities)"])
		var ability_count := 1
		match type:
			monster_type.SCRUB:
				ability_count = 0
			monster_type.GRUNT:
				ability_count = 1
			monster_type.ELITE:
				ability_count = 2
			monster_type.BOSS:
				ability_count = 3

		var shuffled_abilities = monster_compatible_abilities.duplicate()
		shuffled_abilities.shuffle()
		#abilities = [
			#load("res://Abilities/BossAbilities/Fortress.tres"),
			#load("res://Abilities/BossAbilities/PinkSlime.tres"),
			#load("res://Abilities/BossAbilities/Ice.tres"),
			#load("res://Abilities/BossAbilities/PoisonSlime.tres"),
			#load("res://Abilities/BossAbilities/Castle.tres"),
			#load("res://Abilities/BossAbilities/Chains.tres")
			#load("res://Abilities/Resources/regenerate.tres"),
			#load("res://Abilities/rage_bomb.tres"),
			#load("res://Abilities/coral_burst.tres"),
			#load("res://Abilities/jadestrike.tres"),
			#load('res://Abilities/stormsurge.tres')
		#]

		for i in ability_count:
			abilities.append(load(shuffled_abilities[i]))

		if type == monster_type.BOSS:
			var shuffled_boss_abilities = boss_abilities.duplicate()
			shuffled_boss_abilities.shuffle()
			for boss_path in shuffled_boss_abilities:
				var boss_ability = load(boss_path)
				if boss_ability:
					abilities.append(boss_ability)
					break

		# Mark abilities as initialized to prevent re-randomization
		abilities_initialized = true

func apply_job_from_abilities() -> void:
	"""Assign a Job to this monster based on its abilities and apply job stat bonuses.
	This is a no-op for PvP monsters or monsters with no abilities.
	"""
	# Do not modify PvP snapshot monsters
	if is_pvp_monster:
		return

	if abilities.size() == 0:
		return

	var ability_types := []
	var ability_names := []
	for a in abilities:
		if not a:
			continue
		# Prefer direct property access; ability resources should expose `ability_type`
		if "ability_type" in a:
			ability_types.append(a.ability_type)
			if "name" in a:
				ability_names.append(a.name)
			else:
				ability_names.append(str(a))
		elif a.has_method("get_ability_type"):
			ability_types.append(a.get_ability_type())
			if a.has_method("get_name"):
				ability_names.append(a.get_name())
			else:
				ability_names.append(str(a))

	if ability_types.size() == 0:
		return

	# Abilities and types gathered for job mapping

	var job_res = null
	job_res = FW_JobManager.get_job(ability_types)

	if not job_res:
		return

	# Assign job resource for display / persistence
	job = job_res

	# Apply job stat bonuses if StatsManager has the expected API
	if stats:
		if stats.has_method("remove_all_job_bonus"):
			stats.remove_all_job_bonus()
		# Generate effects via JobManager if available
		var stat_counts = FW_JobManager.count_ability_types(ability_types)
		var job_effects = FW_JobManager.generate_effects(stat_counts)
		if job_effects and stats.has_method("apply_job_bonus"):
			stats.apply_job_bonus(job_effects)
			# job bonuses applied to this monster's StatsManager
