extends Resource

class_name FW_Player

# experience points
enum DIFFICULTY { CASUAL, NORMAL, BRAVE, IRONDOG }

# Internal flag to prevent default ability reset when loading from save
var _loading_from_save: bool = false

var _current_ascension_level: int = 0

@export var current_ascension_level: int = 0:
	get:
		return _current_ascension_level
	set(value):
		_current_ascension_level = max(0, value)

@export var ascension_level_manually_selected: bool = false

@export var current_level: int = 1
@export var skill_points: int = 0:
	set(value):
		skill_points = clampi(value, 0, 999)

@export var xp: int:
	set(value):
		xp = clampi(value, 0, 9999999999)

@export var gold: int = 0:
	set(value):
		gold = clampi(value, 0, 9999999999)

@export var character: FW_Character: # = load("res://Characters/Atiya.tres")
	set(value):
		var old_character = character
		character = value
		# When character changes, ensure default abilities are updated
		# Skip during save loading to preserve exact saved abilities
		if character and character != old_character and not _loading_from_save:
			ensure_default_abilities()
# abilities
@export var unlocked_abilities: Array[FW_Ability] = []
@export var abilities: Array[FW_Ability] = [null, null, null, null, null]
# tail, chest, bracer, colar, helmet, weapon
@export var equipment: Array[FW_Equipment] = [null, null, null, null, null, null]
@export var consumable_slots: Array[FW_Consumable] = [null]  # Quick-use consumable slots (starts with 1)
@export var inventory : Array[FW_Item] = []

# BRAVE stats
@export var levelup: bool = false
@export var stats: FW_StatsManager = FW_StatsManager.new()
@export var skill_tree_values: String
@export var skill_tree := {}
@export var monster_kills: Array[FW_Monster_Resource]

# Doghouse loot generation tracking (resets on new game)
@export var pressed_forge_items: Array[String] = []
@export var pressed_garden_potions: Array[int] = []

@export var quests: Array[FW_Quest] = []
# Reference to the BuffManager
@export var buffs: FW_BuffManager

@export var difficulty: DIFFICULTY
@export var continues: int
@export var job: FW_Job

# UI preferences that persist across game sessions
@export var world_map_scroll_position: int = 0

func _init(player_abilities: Array[FW_Ability] = [null, null, null, null, null], player_xp: int = 0, player_current_level: int = 1, player_skill_points: int = 0, player_character: FW_Character = null, player_quests: Array[FW_Quest] = [], player_difficulty: FW_Player.DIFFICULTY = FW_Player.DIFFICULTY.CASUAL) -> void:
	abilities = player_abilities
	xp = player_xp
	skill_points = player_skill_points
	current_level = player_current_level
	character = player_character
	quests = player_quests
	difficulty = player_difficulty

func setup() -> void:
	# process equipment bonus's
	setup_equipment()
	ensure_default_abilities()
	setup_ability_stats()
	recalculate_job()
	update_consumable_slots_size()

func recalculate_job() -> void:
	# Recalculate job and job color from abilities
	var abilities_types_array = get_ability_types()
	job = FW_JobManager.get_job(abilities_types_array)
	if job:
		var label_color: Color = FW_Utils.blend_type_colors(abilities_types_array)
		job.job_color = label_color
	else:
		job = null

func setup_equipment() -> void:
	stats.remove_all_equipment_bonus()
	for e in equipment:
		if e:
			e.apply_stats()

func ensure_default_abilities() -> void:
	"""Ensure player always has default abilities based on character affinities"""
	if not character:
		return

	# Map affinities to their default ability paths
	var affinity_to_default_ability = {
		FW_Ability.ABILITY_TYPES.Bark: "res://Abilities/Resources/default_red_attack.tres",
		FW_Ability.ABILITY_TYPES.Reflex: "res://Abilities/Resources/default_green_attack.tres",
		FW_Ability.ABILITY_TYPES.Alertness: "res://Abilities/Resources/default_blue_attack.tres",
		FW_Ability.ABILITY_TYPES.Vigor: "res://Abilities/Resources/default_orange_attack.tres",
		FW_Ability.ABILITY_TYPES.Enthusiasm: "res://Abilities/Resources/default_pink_attack.tres"
	}

	# First, remove any existing default abilities that don't match current character
	remove_old_default_abilities(affinity_to_default_ability)

	# Get default abilities for this character's affinities
	var default_abilities_needed: Array[FW_Ability] = []
	for affinity in character.affinities:
		if affinity_to_default_ability.has(affinity):
			var ability_path = affinity_to_default_ability[affinity]
			var ability = load(ability_path) as FW_Ability
			if ability:
				default_abilities_needed.append(ability)

	# Ensure default abilities are in unlocked_abilities
	for default_ability in default_abilities_needed:
		if default_ability not in unlocked_abilities:
			unlocked_abilities.append(default_ability)

func remove_old_default_abilities(affinity_to_default_ability: Dictionary) -> void:
	"""Remove default abilities that don't belong to the current character"""
	if not character:
		return

	# Get all default ability resources
	var all_default_abilities: Array[FW_Ability] = []
	for ability_path in affinity_to_default_ability.values():
		var ability = load(ability_path) as FW_Ability
		if ability:
			all_default_abilities.append(ability)

	# Get default abilities that should exist for current character
	var current_character_defaults: Array[FW_Ability] = []
	for affinity in character.affinities:
		if affinity_to_default_ability.has(affinity):
			var ability_path = affinity_to_default_ability[affinity]
			var ability = load(ability_path) as FW_Ability
			if ability:
				current_character_defaults.append(ability)

	# Remove old defaults from unlocked_abilities
	var abilities_to_remove: Array[FW_Ability] = []
	for ability in unlocked_abilities:
		if ability in all_default_abilities and ability not in current_character_defaults:
			abilities_to_remove.append(ability)

	for ability in abilities_to_remove:
		unlocked_abilities.erase(ability)

	# Remove old defaults from active abilities array
	for i in range(abilities.size()):
		if abilities[i] and abilities[i] in all_default_abilities and abilities[i] not in current_character_defaults:
			abilities[i] = null

func reset_abilities_for_new_character(auto_equip_defaults: bool = true) -> void:
	"""Completely reset all abilities and set only the defaults for current character"""
	if not character:
		return

	# Clear all existing abilities
	abilities = [null, null, null, null, null]
	unlocked_abilities.clear()
	current_ascension_level = 0
	ascension_level_manually_selected = false

	# Add default abilities, optionally auto-equipping on fresh character creation
	if auto_equip_defaults:
		add_default_abilities_with_equip()
	else:
		add_default_abilities_for_character()

func add_default_abilities_for_character() -> void:
	"""Add only the default abilities for current character (no removal logic)"""
	if not character:
		return

	# Map affinities to their default ability paths
	var affinity_to_default_ability = {
		FW_Ability.ABILITY_TYPES.Bark: "res://Abilities/Resources/default_red_attack.tres",
		FW_Ability.ABILITY_TYPES.Reflex: "res://Abilities/Resources/default_green_attack.tres",
		FW_Ability.ABILITY_TYPES.Alertness: "res://Abilities/Resources/default_blue_attack.tres",
		FW_Ability.ABILITY_TYPES.Vigor: "res://Abilities/Resources/default_orange_attack.tres",
		FW_Ability.ABILITY_TYPES.Enthusiasm: "res://Abilities/Resources/default_pink_attack.tres"
	}

	# Get default abilities for this character's affinities
	var default_abilities_needed: Array[FW_Ability] = []
	for affinity in character.affinities:
		if affinity_to_default_ability.has(affinity):
			var ability_path = affinity_to_default_ability[affinity]
			var ability = load(ability_path) as FW_Ability
			if ability:
				default_abilities_needed.append(ability)

	# Add default abilities to unlocked_abilities (inventory only)
	for default_ability in default_abilities_needed:
		unlocked_abilities.append(default_ability)

func add_default_abilities_with_equip() -> void:
	"""Add default abilities and also equip them (for new character selection)"""
	if not character:
		return

	# Map affinities to their default ability paths
	var affinity_to_default_ability = {
		FW_Ability.ABILITY_TYPES.Bark: "res://Abilities/Resources/default_red_attack.tres",
		FW_Ability.ABILITY_TYPES.Reflex: "res://Abilities/Resources/default_green_attack.tres",
		FW_Ability.ABILITY_TYPES.Alertness: "res://Abilities/Resources/default_blue_attack.tres",
		FW_Ability.ABILITY_TYPES.Vigor: "res://Abilities/Resources/default_orange_attack.tres",
		FW_Ability.ABILITY_TYPES.Enthusiasm: "res://Abilities/Resources/default_pink_attack.tres"
	}

	# Get default abilities for this character's affinities
	var default_abilities_needed: Array[FW_Ability] = []
	for affinity in character.affinities:
		if affinity_to_default_ability.has(affinity):
			var ability_path = affinity_to_default_ability[affinity]
			var ability = load(ability_path) as FW_Ability
			if ability:
				default_abilities_needed.append(ability)

	# Add default abilities to unlocked_abilities
	for default_ability in default_abilities_needed:
		unlocked_abilities.append(default_ability)

	# Also equip defaults to action bar for new character
	for i in range(abilities.size()):
		if abilities[i] == null and default_abilities_needed.size() > 0:
			abilities[i] = default_abilities_needed.pop_front()

func allocate_points(points: int) -> void:
	skill_points += points
	# Logic to allocate points to stats

# Process buffs at the end of the player's turn
func end_turn() -> void:
	# LEGACY CODE: FW_Buff processing moved to TurnManager
	# if buffs:
	#     buffs.process_turn()
	pass

# Example: Apply a new buff to the player
func apply_buff(buff: FW_Buff) -> void:
	if buffs:
		# Set caster type for turn-based processing
		if buff.caster_type == "":
			buff.caster_type = "player"  # Player is applying buff to themselves
		buffs.add_buff(buff)
	# Implement the immediate effect of the buff here, if needed

func get_ability_types() -> Array[String]:
	var abilities_array: Array[String] = []
	for ability in abilities:
		if ability != null:
			abilities_array.append(FW_Ability.ABILITY_TYPES.keys()[ability.ability_type])
	return abilities_array

func setup_ability_stats() -> void:
	# job related
	var abilities_types_array = get_ability_types()
	var stats_dict := FW_JobManager.count_ability_types(abilities_types_array)
	var effects := FW_JobManager.generate_effects(stats_dict)
	GDM.player.stats.remove_all_job_bonus()
	GDM.player.stats.apply_job_bonus(effects)

# Get the maximum number of consumable slots based on equipment/abilities
func get_max_consumable_slots() -> int:
	var base_slots = 1  # Default minimum 1 slot

	# Check equipment for consumable slot bonuses
	for piece in equipment:
		if piece and piece.effects.has("extra_consumable_slots"):
			base_slots += piece.effects["extra_consumable_slots"]

	# Check abilities for consumable slot bonuses (future feature)
	# for ability in abilities:
	#     if ability and ability.effects.has("extra_consumable_slots"):
	#         base_slots += ability.effects["extra_consumable_slots"]

	# Cap at maximum of 5 slots
	return clampi(base_slots, 1, 5)

# Ensure consumable_slots array matches the maximum available slots
func update_consumable_slots_size() -> void:
	var max_slots = get_max_consumable_slots()
	var old_size = consumable_slots.size()

	if max_slots < old_size:
		# Slots are being removed - need to handle items in removed slots
		handle_slot_reduction(old_size, max_slots)

	# Resize the array
	consumable_slots.resize(max_slots)

	# Fill new slots with null if expanding
	for i in range(consumable_slots.size()):
		if i >= old_size:
			consumable_slots[i] = null

# Handle items when consumable slots are reduced (e.g., equipment removed)
func handle_slot_reduction(old_size: int, new_size: int) -> void:
	var displaced_items: Array[FW_Consumable] = []

	# Collect items from slots that will be removed
	for i in range(new_size, old_size):
		if i < consumable_slots.size() and consumable_slots[i] != null:
			displaced_items.append(consumable_slots[i])
			consumable_slots[i] = null

	# Try to move displaced items to available slots
	for item in displaced_items:
		var placed = false

		# First, try to find an empty slot within the new size limit
		for i in range(new_size):
			if i < consumable_slots.size() and consumable_slots[i] == null:
				consumable_slots[i] = item
				placed = true
				FW_Debug.debug_log(["Moved %s to consumable slot %d" % [item.name, i + 1]])
				break

		# If no empty slots, return to inventory
		if not placed:
			# Only add to inventory if it's not already there
			if not inventory.has(item):
				inventory.append(item)
				FW_Debug.debug_log(["Returned %s to inventory (no available consumable slots)" % item.name])
			else:
				FW_Debug.debug_log(["Item %s already in inventory, skipping duplicate" % item.name])

# Remove a consumable from both inventory and consumable slots
func consume_item(consumable: FW_Consumable) -> bool:
	var was_removed = false

	# Remove from inventory if present
	if inventory.has(consumable):
		inventory.erase(consumable)
		was_removed = true

	# Remove from consumable slots if present
	for i in range(consumable_slots.size()):
		if consumable_slots[i] == consumable:
			consumable_slots[i] = null
			was_removed = true
			break

	# Notify UI that consumable slots have changed
	if was_removed:
		EventBus.consumable_slots_changed.emit()

	return was_removed

# Move a consumable from inventory to consumable slot
func move_consumable_to_slot(consumable: FW_Consumable, slot_index: int) -> bool:
	if slot_index >= 0 and slot_index < consumable_slots.size():
		# Store what was in the slot before (for potential future use)
		var _previous_item = consumable_slots[slot_index]

		# Put new item in slot
		consumable_slots[slot_index] = consumable

		# If there was a previous item, it stays in inventory
		# The new item is still in inventory too (slots are like shortcuts)

		return true
	return false

# Move a consumable from slot back to just inventory
func move_consumable_from_slot(slot_index: int) -> FW_Consumable:
	if slot_index >= 0 and slot_index < consumable_slots.size():
		var consumable = consumable_slots[slot_index]
		consumable_slots[slot_index] = null
		return consumable
	return null
