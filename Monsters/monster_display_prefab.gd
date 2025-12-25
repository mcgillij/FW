extends Node2D

class_name FW_CombatantDisplayPrefab

@onready var monster_image = %monster_image
@onready var monster_name_label: RichTextLabel = %monster_name_label
@onready var monster_description_label: Label = %monster_description_label
@onready var monster_hp_label: Label = %monster_hp_label
@onready var monster_shields_label: Label = %monster_shields_label
@onready var monster_xp_label: Label = %monster_xp_label
@onready var monster_type_label: Label = %monster_type_label
@onready var monster_family_label: Label = %monster_family_label

@onready var job_label: Label = %job_label
@onready var job_value_label: Label = %job_value_label

@onready var red_affinity: MarginContainer = %red_affinity
@onready var blue_affinity: MarginContainer = %blue_affinity
@onready var green_affinity: MarginContainer = %green_affinity
@onready var orange_affinity: MarginContainer = %orange_affinity
@onready var pink_affinity: MarginContainer = %pink_affinity

# Store the combatant data (could be Monster_Resource or Combatant)
var combatant_data
var is_player_combatant: bool = false

# Legacy wrapper for backwards compatibility
func setup_monster_display(monster: FW_Monster_Resource) -> void:
	setup_combatant_display(monster, false)

# New unified setup method that handles both monsters and players
func setup_combatant_display(combatant, is_player: bool = false) -> void:
	combatant_data = combatant
	is_player_combatant = is_player

	# Common properties
	monster_name_label.text = combatant.name
	monster_description_label.text = combatant.description
	monster_image.texture = combatant.texture

	if is_player:
		_setup_player_display(combatant)
	else:
		_setup_monster_display(combatant)

	show_hide_affinities(combatant)

func _setup_player_display(player_combatant: FW_Combatant) -> void:
	# For players: show HP/shields, hide XP/type/family, show job
	monster_hp_label.text = str(player_combatant.get_max_hp())
	monster_shields_label.text = str(player_combatant.get_max_shields())

	# Hide monster-specific fields
	if monster_xp_label:
		monster_xp_label.visible = false
	if monster_type_label:
		monster_type_label.visible = false
	if monster_family_label:
		monster_family_label.visible = false

	# Show job information if available
	if job_label and job_value_label:
		if player_combatant.job_name != "":
			job_label.visible = true
			job_value_label.visible = true
			job_value_label.text = player_combatant.job_name
			var jc := FW_Utils.normalize_color(player_combatant.job_color)
			if jc != Color.WHITE:
				job_value_label.modulate = jc
		else:
			job_label.visible = false
			job_value_label.visible = false

func _setup_monster_display(monster: FW_Monster_Resource) -> void:
	# For monsters: show all monster-specific fields, hide job
	monster_hp_label.text = str(monster.max_hp)
	monster_shields_label.text = str(monster.shields)
	monster_xp_label.text = str(monster.xp)
	monster_type_label.text = FW_Monster_Resource.monster_type.keys()[monster.type]
	monster_family_label.text = FW_Monster_Resource.monster_subtype.keys()[monster.subtype]

	# Show monster-specific fields
	if monster_xp_label:
		monster_xp_label.visible = true
	if monster_type_label:
		monster_type_label.visible = true
	if monster_family_label:
		monster_family_label.visible = true

	# Hide job information for monsters
	if job_label:
		job_label.visible = false
	if job_value_label:
		job_value_label.visible = false

	# If a job exists on the monster resource, show it inline on the display as well
	if monster.job and job_label and job_value_label:
		job_label.visible = true
		job_value_label.visible = true
		var job_name_str := ""
		if monster.job and "name" in monster.job and str(monster.job.name).to_lower() != "unassigned":
			job_name_str = str(monster.job.name)
		job_value_label.text = job_name_str
		# Compute color from abilities first (jobs are derived from abilities); fallback to the job resource color
		var jc = Color.WHITE
		# Use get("abilities") to avoid calling nonexistent `has` on Resource
		if monster.get("abilities") != null and typeof(monster.abilities) == TYPE_ARRAY and monster.abilities.size() > 0:
			jc = FW_Utils.job_color_from_ability_types(monster.abilities)
		elif monster.job and "job_color" in monster.job:
			jc = FW_Utils.normalize_color(monster.job.job_color)
		if jc != Color.WHITE and job_name_str != "":
			job_value_label.modulate = jc

func show_hide_affinities(combatant_resource) -> void:
	if !red_affinity:
		red_affinity = %red_affinity
	if !blue_affinity:
		blue_affinity = %blue_affinity
	if !green_affinity:
		green_affinity = %green_affinity
	if !orange_affinity:
		orange_affinity = %orange_affinity
	if !pink_affinity:
		pink_affinity = %pink_affinity

	var aff_list = [%red_affinity, %blue_affinity, %green_affinity, %orange_affinity, %pink_affinity]
	for a in aff_list:
		a.set_visible(false)
	for aff in combatant_resource.affinities:
		match aff:
			FW_Ability.ABILITY_TYPES.Bark:
				red_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Alertness:
				blue_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Reflex:
				green_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Vigor:
				orange_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Enthusiasm:
				pink_affinity.set_visible(true)

func _on_button_pressed() -> void:
	if combatant_data is FW_Monster_Resource:
		EventBus.show_monster.emit(combatant_data)
	elif combatant_data is FW_Combatant:
		# For player combatants, emit the player signal to trigger the toggle logic
		EventBus.show_player_combatant.emit(combatant_data)
