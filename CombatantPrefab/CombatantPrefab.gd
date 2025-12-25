extends TextureRect

var combatant_image: TextureButton
var combatant_name_label: RichTextLabel
#var hp_label: Label
#var shield_label: RichTextLabel

var red_affinity: MarginContainer
var blue_affinity: MarginContainer
var green_affinity: MarginContainer
var orange_affinity: MarginContainer
var pink_affinity: MarginContainer

@export var floating_damage_numbers: PackedScene
@export var heal_animation: PackedScene
@export var shield_animation: PackedScene
@export var damage_animation: PackedScene
@export var shield_texture: Texture2D

var shader_values = FW_Utils.ShaderValues.new()
var help_mode = false # This is for in the tutorial skip GDM things
var max_hp: int
var max_shields := 999
var current_hp: int:
	set(value):
		current_hp = clampi(value, 0, max_hp)
var shields: int:
	set(value):
		shields = clampi(value, 0, max_shields)

var is_player: bool = false # This will be set by the child classes
var animation_position := Vector2(70, 120)

func _ready() -> void:
	# Connect to visual effect signals based on whether it's player or monster
	if is_player:
		if not EventBus.show_player_damage_effects.is_connected(show_damage_effects):
			EventBus.show_player_damage_effects.connect(show_damage_effects)
		if not EventBus.show_player_heal_effects.is_connected(show_heal_effects):
			EventBus.show_player_heal_effects.connect(show_heal_effects)
		if not EventBus.show_player_shield_effects.is_connected(show_shield_effects):
			EventBus.show_player_shield_effects.connect(show_shield_effects)
		if not EventBus.player_state_changed.is_connected(_on_combatant_state_changed):
			EventBus.player_state_changed.connect(_on_combatant_state_changed)
	else:
		if not EventBus.show_monster_damage_effects.is_connected(show_damage_effects):
			EventBus.show_monster_damage_effects.connect(show_damage_effects)
		if not EventBus.show_monster_heal_effects.is_connected(show_heal_effects):
			EventBus.show_monster_heal_effects.connect(show_heal_effects)
		if not EventBus.show_monster_shield_effects.is_connected(show_shield_effects):
			EventBus.show_monster_shield_effects.connect(show_shield_effects)
		if not EventBus.monster_state_changed.is_connected(_on_combatant_state_changed):
			EventBus.monster_state_changed.connect(_on_combatant_state_changed)

	# Connect to combat state initialization
	if not EventBus.combat_state_initialized.is_connected(_on_combat_state_initialized):
		EventBus.combat_state_initialized.connect(_on_combat_state_initialized)

	# Check if combat state is already initialized (shouldn't be at this point)
	if GDM.effect_manager and GDM.effect_manager.is_combat_state_initialized():
		sync_state_from_central()


func _process(_delta: float) -> void:
	if self.material and self.material is ShaderMaterial:
		var shader_material = self.material as ShaderMaterial
		if help_mode:
			shader_material.set_shader_parameter("enable_highlight", true)
			return
		if is_player:
			if GDM.game_manager.turn_manager.is_player_turn():
				shader_material.set_shader_parameter("enable_highlight", true)
			else:
				shader_material.set_shader_parameter("enable_highlight", false)
		else: # Monster
			if GDM.game_manager.turn_manager.is_player_turn():
				shader_material.set_shader_parameter("enable_highlight", false)
			else:
				shader_material.set_shader_parameter("enable_highlight", true)

func show_hide_affinities(combatant_resource) -> void:
	# Ensure affinity nodes are ready
	if !red_affinity: red_affinity = %red_affinity
	if !blue_affinity: blue_affinity = %blue_affinity
	if !green_affinity: green_affinity = %green_affinity
	if !orange_affinity: orange_affinity = %orange_affinity
	if !pink_affinity: pink_affinity = %pink_affinity

	var aff_list = [red_affinity, blue_affinity, green_affinity, orange_affinity, pink_affinity]

	# Get active affinities
	var active_affinities = combatant_resource.affinities
	var num_affinities = active_affinities.size()

	# Hide all affinity nodes first
	for a in aff_list:
		a.set_visible(false)

	# If no affinities, return early
	if num_affinities == 0:
		return

	# Create color mapping
	var color_map = {
		FW_Ability.ABILITY_TYPES.Bark: FW_Colors.bark,
		FW_Ability.ABILITY_TYPES.Reflex: FW_Colors.reflex,
		FW_Ability.ABILITY_TYPES.Alertness: FW_Colors.alertness,
		FW_Ability.ABILITY_TYPES.Vigor: FW_Colors.vigor,
		FW_Ability.ABILITY_TYPES.Enthusiasm: FW_Colors.enthusiasm
	}

	var affinity_node_map = {
		FW_Ability.ABILITY_TYPES.Bark: red_affinity,
		FW_Ability.ABILITY_TYPES.Reflex: green_affinity,
		FW_Ability.ABILITY_TYPES.Alertness: blue_affinity,
		FW_Ability.ABILITY_TYPES.Vigor: orange_affinity,
		FW_Ability.ABILITY_TYPES.Enthusiasm: pink_affinity
	}

	# Apply shader to main prefab if multiple affinities
	if num_affinities > 1:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = load("res://Shaders/combined_affinity_highlight_with_electricity.gdshader")

		# Set up colors array for the shader - fill in order of active affinities
		var colors_array = []
		for j in range(5):
			if j < num_affinities:
				colors_array.append(color_map[active_affinities[j]])
			else:
				colors_array.append(Color(1, 1, 1, 1)) # White for unused slots

		shader_material.set_shader_parameter("affinity_colors", colors_array)
		shader_material.set_shader_parameter("num_affinities", num_affinities)
		shader_material.set_shader_parameter("split_rotation", 0.0)
		shader_material.set_shader_parameter("animate_split", true)
		shader_material.set_shader_parameter("pulse_intensity", 0.1)
		shader_material.set_shader_parameter("border_width", 0.02)
		shader_material.set_shader_parameter("highlight_strength", 0.5)
		shader_material.set_shader_parameter("highlight_speed", 1.0)
		shader_material.set_shader_parameter("enable_affinity_split", true)

		# Apply to the main TextureRect (this node)
		self.material = shader_material
	else:
		# Single affinity - apply shader with affinity split disabled but still show the color
		var shader_material = ShaderMaterial.new()
		shader_material.shader = load("res://Shaders/combined_affinity_highlight_with_electricity.gdshader")

		# Set up colors array for the shader - use the single affinity color
		var colors_array = []
		if num_affinities == 1:
			colors_array.append(color_map[active_affinities[0]])
		else:
			colors_array.append(Color(1, 1, 1, 1)) # White fallback

		# Fill remaining slots with white
		for j in range(1, 5):
			colors_array.append(Color(1, 1, 1, 1))

		shader_material.set_shader_parameter("affinity_colors", colors_array)
		shader_material.set_shader_parameter("num_affinities", 1)
		shader_material.set_shader_parameter("split_rotation", 0.0)
		shader_material.set_shader_parameter("animate_split", false)
		shader_material.set_shader_parameter("pulse_intensity", 0.1)
		shader_material.set_shader_parameter("border_width", 0.02)
		shader_material.set_shader_parameter("highlight_strength", 0.5)
		shader_material.set_shader_parameter("highlight_speed", 1.0)
		shader_material.set_shader_parameter("enable_affinity_split", false) # Disable split for single affinity

		# Apply to the main TextureRect (this node)
		self.material = shader_material	# Show individual affinity nodes
	for i in range(num_affinities):
		var affinity_type = active_affinities[i]
		var affinity_node = affinity_node_map[affinity_type]
		affinity_node.set_visible(true)

func sync_state_to_central() -> void:
	# This method is primarily for child classes to implement if they need to push state
	# For now, the centralized system (EffectsManager) is the source of truth.
	pass

func sync_state_from_central() -> void:
	if !GDM.effect_manager:
		return

	if !GDM.effect_manager.is_combat_state_initialized():
		return

	var new_max_hp: int
	var new_current_hp: int
	var new_shields: int

	if is_player:
		new_max_hp = GDM.effect_manager.get_player_max_hp()
		new_current_hp = GDM.effect_manager.get_current_player_hp()
		new_shields = GDM.effect_manager.get_current_player_shields()
	else:
		new_max_hp = GDM.effect_manager.get_monster_max_hp()
		new_current_hp = GDM.effect_manager.get_current_monster_hp()
		new_shields = GDM.effect_manager.get_current_monster_shields()

	# Always update HP label with the latest values from EffectManager (with all modifiers)
	max_hp = new_max_hp
	current_hp = new_current_hp
	shields = new_shields
	#FW_Debug.debug_log(["[CombatantPrefab] sync_state_from_central: is_player=", is_player, " max_hp=", max_hp, " current_hp=", current_hp, " shields=", shields])

func _do_damage_numbers(damage: int, bypass := false, shields_value := false) -> CanvasItem:
	# This method will be overridden by child classes for specific GDM.tracker calls
	# and position adjustments.

	# damage animation
	var damage_ani = damage_animation.instantiate()
	add_child(damage_ani)
	damage_ani.position = animation_position # Default position, can be overridden

	var current = floating_damage_numbers.instantiate()
	current.set_combatant_owner(is_player)
	current._emit_damage_numbers(damage, bypass, shields_value)
	add_child(current)
	return current

func is_alive() -> bool:
	if is_player:
		return GDM.effect_manager.get_current_player_hp() > 0
	else:
		return GDM.effect_manager.get_current_monster_hp() > 0

# Show visual effects only - no state changes
func show_damage_effects(amount: int, bypass: bool = false, shield_damage: bool = false) -> void:
	_do_damage_numbers(amount, bypass, shield_damage)

func show_heal_effects(amount: int) -> void:
	#FW_Debug.debug_log(["[CombatantPrefab] show_heal_effects: amount=", amount, " is_player=", is_player])
	var heal_ani = heal_animation.instantiate()
	add_child(heal_ani)
	heal_ani.position = animation_position

	# Instantiate floating damage numbers for healing effect
	var heal_numbers = floating_damage_numbers.instantiate()
	heal_numbers.set_combatant_owner(is_player)
	heal_numbers._heal(amount)
	add_child(heal_numbers)

func show_shield_effects(_amount: int) -> void:
	var shield_ani = shield_animation.instantiate()
	add_child(shield_ani)
	shield_ani.position = animation_position # Default position, can be overridden

func _on_combat_state_initialized() -> void:
	sync_state_from_central()


func _on_combatant_state_changed() -> void:
	sync_state_from_central()

# Abstract method to be implemented by child classes
@warning_ignore("unused_parameter")
func set_combatant_values(combatant_resource) -> void:
	# For player prefab, ensure HP label always reflects all effects (mirrors monster logic)
	if is_player:
		max_hp = GDM.effect_manager.get_player_max_hp()
		if GDM.effect_manager.is_combat_state_initialized():
			current_hp = GDM.effect_manager.get_current_player_hp()
			shields = GDM.effect_manager.get_current_player_shields()
		else:
			current_hp = max_hp
			shields = GDM.effect_manager.get_shields()
		## Always sync to EffectManager's current state after setup
		sync_state_from_central()
	else:
		push_error("set_combatant_values() must be implemented by child class!")
