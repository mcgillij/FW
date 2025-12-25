extends Resource

class_name FW_EventResource

enum event_type { STARTER, COMMON, UNCOMMON, RARE, LEGENDARY }

const TYPE_COLORS = {
	"STARTER": Color.RED,
	"COMMON": Color.BLUE,
	"UNCOMMON": Color.PURPLE,
	"RARE": Color.DARK_GREEN,
	"LEGENDARY": Color.ORANGE
}

# Constants for buff ownership and pending buff management
const OWNER_TYPE_PLAYER := "player"
const PENDING_COMBAT_BUFFS_KEY := "pending_combat_buffs"

@export var name: String
@export var type: event_type
@export_multiline var flavor_text: String
@export_multiline var description: String
@export var event_image: Texture2D
@export var event_choices: Array[Dictionary]
@export var failure_effects: Array[Resource] = []  # Effects to apply on event failure

# Runtime view keys (returned by build_view)
const VIEW_DESCRIPTION_KEY := "description"
const VIEW_CHOICES_KEY := "choices"

# Choice dictionary keys (runtime)
const CHOICE_ID_KEY := "id"
const CHOICE_TEXT_KEY := "text"
const CHOICE_SKILL_CHECK_KEY := "skill_check"

func _to_string() -> String:
	return "[Event: %s (%s)]" % [name, type]

func get_type_color() -> Color:
	var type_name = event_type.keys()[type]
	if TYPE_COLORS.has(type_name):
		return TYPE_COLORS[type_name]
	return Color.WHITE  # Fallback in case of missing type

func _event_resolve(_choice, _skill_success: bool = true) -> Array:
	return [true, "Should not be called, in the base class"]

func build_view(_context: Dictionary = {}) -> Dictionary:
	"""Return a runtime view for the event UI without mutating exported fields.

	Expected return shape:
	{
		"description": String,
		"choices": Array[Dictionary]
	}
	
	Each choice dictionary should include:
	- "id": stable identifier
	- "text": display text
	Optional:
	- "skill_check": FW_SkillCheckRes
	"""
	var view_choices: Array[Dictionary] = []
	for i in range(event_choices.size()):
		var c: Dictionary = event_choices[i]
		var id_val = c.get(CHOICE_ID_KEY, str(i))
		var text_val = c.get(CHOICE_TEXT_KEY, c.get("choice", ""))
		# Maintain back-compat with existing UI nodes that still expect "choice".
		var out_choice: Dictionary = c.duplicate(true)
		out_choice[CHOICE_ID_KEY] = id_val
		out_choice[CHOICE_TEXT_KEY] = text_val
		out_choice["choice"] = text_val
		view_choices.append(out_choice)
	return {
		VIEW_DESCRIPTION_KEY: description,
		VIEW_CHOICES_KEY: view_choices,
	}

func resolve_choice(choice: Dictionary, skill_success: bool, _context: Dictionary = {}) -> Array:
	"""Resolve a selected choice.

	Default behavior calls legacy _event_resolve(choice_text, skill_success).
	Override in subclasses and key off choice["id"] instead of display text.
	"""
	var choice_text: String = choice.get(CHOICE_TEXT_KEY, choice.get("choice", ""))
	return _event_resolve(choice_text, skill_success)

func make_deterministic_rng(context: Dictionary, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var seed_parts: Array[String] = []
	seed_parts.append(str(context.get("run_seed", 0)))
	seed_parts.append(str(context.get("map_hash", 0)))
	seed_parts.append(str(context.get("level_hash", 0)))
	seed_parts.append(str(context.get("event_path", resource_path)))
	seed_parts.append(salt)
	var seed_val: int = hash(":".join(seed_parts))
	if seed_val < 0:
		seed_val = -seed_val
	rng.seed = seed_val
	return rng

func shuffled_copy(arr: Array, rng: RandomNumberGenerator) -> Array:
	"""Return a deterministically shuffled copy of arr using the provided RNG."""
	var out: Array = arr.duplicate(true)
	if out.size() <= 1:
		return out
	# Fisher–Yates shuffle
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out

func apply_failure_effects() -> void:
	"""Apply generic failure effects to the player."""
	apply_effects(failure_effects)

func apply_effects(effects: Array[Resource]) -> void:
	"""Apply a list of effect resources to the player.

	- Buff resources are added to the player (or queued if combat_only).
	- EffectResource is executed immediately with a player-targeted context.
	"""
	for effect in effects:
		if effect == null:
			continue
		if effect is FW_Buff:
			var buff_template: FW_Buff = effect
			var buff_instance: FW_Buff = buff_template.duplicate(true)
			buff_instance.owner_type = OWNER_TYPE_PLAYER
			if buff_instance.has_meta("combat_only") and buff_instance.get_meta("combat_only"):
				add_pending_combat_buff(buff_instance)
			else:
				if GDM.player and GDM.player.buffs:
					GDM.player.buffs.add_buff(buff_instance)
				else:
					push_warning("apply_effects: player buffs manager missing")
		elif effect is FW_EffectResource:
			(effect as FW_EffectResource).execute({
				"target_is_player": true,
				"is_player_turn": false,
			})
		else:
			push_warning("Unknown effect type in effects: %s" % effect)

func add_pending_combat_buff(buff: FW_Buff) -> void:
	"""Add a buff to the pending combat buffs list"""
	if not GDM.has_meta(PENDING_COMBAT_BUFFS_KEY):
		GDM.set_meta(PENDING_COMBAT_BUFFS_KEY, [])

	var pending_buffs: Array = GDM.get_meta(PENDING_COMBAT_BUFFS_KEY)
	pending_buffs.append(buff)
	GDM.set_meta(PENDING_COMBAT_BUFFS_KEY, pending_buffs)

func get_pending_combat_buffs() -> Array:
	"""Get the current list of pending combat buffs"""
	if not GDM.has_meta(PENDING_COMBAT_BUFFS_KEY):
		return []
	return GDM.get_meta(PENDING_COMBAT_BUFFS_KEY)

func clear_pending_combat_buffs() -> void:
	"""Clear all pending combat buffs"""
	GDM.set_meta(PENDING_COMBAT_BUFFS_KEY, [])
