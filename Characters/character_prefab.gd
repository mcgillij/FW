extends "res://CombatantPrefab/CombatantPrefab.gd"

@onready var hp_bar_container: HBoxContainer = %hp_bar_container
@export var health_and_shield_bar: PackedScene = load("res://HealthBar/HealthAndSheildBar.tscn")

var hp_and_shield_bar_instance: Control

func _init() -> void:
	is_player = true

func set_combatant_values_for_help(character: FW_Character) -> void:
	super._ready()
	help_mode = true
	# Assign specific nodes to generic base class properties
	if !hp_bar_container:
		hp_bar_container = %hp_bar_container
	combatant_image = %character_image
	combatant_name_label = %character_name_label
	red_affinity = %red_affinity
	blue_affinity = %blue_affinity
	green_affinity = %green_affinity
	orange_affinity = %orange_affinity
	pink_affinity = %pink_affinity
	var hp_and_shield = health_and_shield_bar.instantiate()
	hp_bar_container.add_child(hp_and_shield)
	hp_and_shield_bar_instance = hp_and_shield

	show_hide_affinities(character)
	combatant_image.texture_normal = character.texture

	# Initialize from centralized state
	max_hp = 40 #GDM.effect_manager.get_player_max_hp()
	current_hp = max_hp
	shields = 30 # GDM.effect_manager.get_shields()
	combatant_name_label.text = character.name

func set_combatant_values(character: FW_Character) -> void:
	super._ready()
	# Assign specific nodes to generic base class properties
	if !hp_bar_container:
		hp_bar_container = %hp_bar_container
	combatant_image = %character_image
	combatant_name_label = %character_name_label
	red_affinity = %red_affinity
	blue_affinity = %blue_affinity
	green_affinity = %green_affinity
	orange_affinity = %orange_affinity
	pink_affinity = %pink_affinity
	var hp_and_shield = health_and_shield_bar.instantiate()
	hp_bar_container.add_child(hp_and_shield)
	hp_and_shield_bar_instance = hp_and_shield
	# Connect signals now that combatant_image is assigned
	if not combatant_image.pressed.is_connected(_on_character_image_pressed):
		combatant_image.pressed.connect(_on_character_image_pressed)

	show_hide_affinities(character)
	combatant_image.texture_normal = character.texture

	# Initialize from centralized state
	max_hp = GDM.effect_manager.get_player_max_hp()

	# Check if centralized state is initialized
	if GDM.effect_manager.is_combat_state_initialized():
		current_hp = GDM.effect_manager.get_current_player_hp()
		shields = GDM.effect_manager.get_current_player_shields()
	else:
		# Fallback: use max values as initial values
		current_hp = max_hp
		shields = GDM.effect_manager.get_shields()

		# We'll sync properly when combat state gets initialized

	combatant_name_label.text = character.name

	# If player has a job, append it to the displayed name with a computed color
	var jc := Color.WHITE
	# Prefer GDM.player.job when available (character passed here is usually the player)

	if GDM.player.job and GDM.player.job.name.to_lower() != "unassigned":
		jc = FW_Utils.job_color_from_ability_types(GDM.player.abilities)
		#combatant_name_label.bbcode_enabled = true
		combatant_name_label.text = "%s\n [color=%s]%s[/color]" % [combatant_name_label.text, jc.to_html(false), GDM.player.job.name]

	# Always sync to EffectManager's current state after setup
	sync_state_from_central()

func sync_state_from_central() -> void:
	super.sync_state_from_central()
	if hp_and_shield_bar_instance:
		if not hp_and_shield_bar_instance.is_node_ready():
			await hp_and_shield_bar_instance.ready
		if hp_and_shield_bar_instance.has_method("apply_state"):
			hp_and_shield_bar_instance.apply_state(max_hp, current_hp, max_shields, shields)
		else:
			hp_and_shield_bar_instance.set_max_health(max_hp)
			hp_and_shield_bar_instance.set_health(current_hp)
			hp_and_shield_bar_instance.set_max_shield(max_shields)
			hp_and_shield_bar_instance.set_shield(shields)

func _do_damage_numbers(damage: int, bypass := false, shields_value := false) -> CanvasItem:
	if shields_value:
		GDM.tracker.damage_taken_blocked += damage
	else:
		GDM.tracker.damage_taken += damage

	# Call base class for visual effects
	var current_floating_numbers = super._do_damage_numbers(damage, bypass, shields_value)

	# Adjust position for character
	if current_floating_numbers and current_floating_numbers is CanvasItem:
		current_floating_numbers.position.x = 300
		current_floating_numbers.position.y = 50
	return current_floating_numbers

func _on_character_image_pressed() -> void:
	EventBus.player_clicked.emit()
