extends "res://CombatantPrefab/CombatantPrefab.gd"

@export var health_and_shield_bar: PackedScene = load("res://HealthBar/HealthAndSheildBar.tscn")
@onready var hp_bar_container: HBoxContainer = %hp_bar_container

var hp_and_shield_bar_instance: Control

func _init() -> void:
	is_player = false

func set_combatant_values(monster: FW_Monster_Resource) -> void:
	# This is a bit of a hack, but we need to make sure the base class's ready logic runs
	# after we've assigned the nodes.
	super._ready()
	if !hp_bar_container:
		hp_bar_container = %hp_bar_container
	# Assign specific nodes to generic base class properties
	combatant_image = %monster_image
	combatant_name_label = %monster_name_label
	red_affinity = %red_affinity
	blue_affinity = %blue_affinity
	green_affinity = %green_affinity
	orange_affinity = %orange_affinity
	pink_affinity = %pink_affinity
	var hp_and_shield = health_and_shield_bar.instantiate()
	hp_and_shield.is_right_facing = true  # Monster is on the right side
	hp_bar_container.add_child(hp_and_shield)
	hp_and_shield_bar_instance = hp_and_shield
	# Connect signals now that combatant_image is assigned
	if not combatant_image.pressed.is_connected(_on_monster_image_pressed):
		combatant_image.pressed.connect(_on_monster_image_pressed)

	show_hide_affinities(monster)
	combatant_image.texture_normal = monster.texture

	# Always use centralized state for both current and max HP, so the label is always correct
	# Compute max/current HP and shields. Prefer using the passed-in monster
	# resource directly for previews (especially PvP snapshots). Fall back
	# to the centralized EffectManager state when the combat state is active.
	var env_effects = GDM.env_manager.get_environmental_effects() if GDM.env_manager else {}
	if monster and monster.get("is_pvp_monster") and monster.stats:
		# Use central collect_effects to merge snapshot + env (no temp re-add)
		if GDM.effect_manager:
			var char_effects = monster.get("character_effects")
			if typeof(char_effects) != TYPE_DICTIONARY:
				char_effects = {}
			var merged = GDM.effect_manager.collect_effects(monster.stats, char_effects, env_effects)
			max_hp = int(merged.get("hp", monster.max_hp))
			shields = int(merged.get("shields", monster.shields))
			# debug trace removed
		else:
			max_hp = int(monster.stats.get_stat_values().get("hp", monster.max_hp))
			shields = int(monster.stats.get_stat_values().get("shields", monster.shields))
		# If combat state is initialized, prefer centralized current values
		if GDM.effect_manager and GDM.effect_manager.is_combat_state_initialized():
			current_hp = GDM.effect_manager.get_current_monster_hp()
		else:
			current_hp = max_hp
	else:
		# Non-PvP monsters use the old logic (base + env)
		max_hp = GDM.effect_manager.get_monster_max_hp()
		if GDM.effect_manager.is_combat_state_initialized():
			current_hp = GDM.effect_manager.get_current_monster_hp()
			shields = GDM.effect_manager.get_current_monster_shields()
		else:
			current_hp = max_hp
			shields = GDM.effect_manager.get_monster_shields()

	combatant_name_label.text = monster.name

	# If a job is assigned, append it to the name in color
	if monster.get("job") != null:
		var job = monster.job
		if job and job.get("name") != null and str(job.name) != "" and str(job.name).to_lower() != "unassigned":
			# Compute job color from monster abilities first, fallback to job resource
			var jc = Color.WHITE
			# Use get("abilities") to avoid calling nonexistent `has` on Resource
			if monster.get("abilities") != null and typeof(monster.abilities) == TYPE_ARRAY and monster.abilities.size() > 0:
				jc = FW_Utils.job_color_from_ability_types(monster.abilities)
			elif job.get("job_color") != null:
				jc = FW_Utils.normalize_color(job.job_color)
			combatant_name_label.bbcode_enabled = true
			combatant_name_label.text = "%s [color=%s]%s[/color]" % [combatant_name_label.text, jc.to_html(false), str(job.name)]

	# Always sync to EffectManager's current state after setup
	sync_state_from_central()

func sync_state_from_central() -> void:
	super.sync_state_from_central()
	if hp_and_shield_bar_instance:
		if not hp_and_shield_bar_instance.is_node_ready():
			await hp_and_shield_bar_instance.ready
		#FW_Debug.debug_log(["[MonsterPrefab] updating hp_and_shield_bar_instance (atomic): max_hp=", max_hp, " current_hp=", current_hp, " shields=", shields])
		if hp_and_shield_bar_instance.has_method("apply_state"):
			hp_and_shield_bar_instance.apply_state(max_hp, current_hp, max_shields, shields)
		else:
			hp_and_shield_bar_instance.set_max_health(max_hp)
			hp_and_shield_bar_instance.set_health(current_hp)
			hp_and_shield_bar_instance.set_max_shield(max_shields)
			hp_and_shield_bar_instance.set_shield(shields)



func _do_damage_numbers(damage: int, bypass := false, shields_value := false) -> CanvasItem:
	# Monster-specific stat tracking
	GDM.tracker.track_highest_damage(damage)
	if !bypass and !shields_value:
		GDM.tracker.damage_done += damage
	if !bypass and shields_value:
		GDM.tracker.damage_done_blocked_by_sheilds += damage
	if bypass and !shields_value:
		GDM.tracker.damage_done_bypassed_sheilds += damage

	# Call base class for visual effects
	var current_floating_numbers = super._do_damage_numbers(damage, bypass, shields_value)

	# Adjust position for monster
	if current_floating_numbers and current_floating_numbers is CanvasItem:
		current_floating_numbers.position.x = 170
		current_floating_numbers.position.y = 50
	return current_floating_numbers

func _on_monster_image_pressed() -> void:
	EventBus.monster_clicked.emit()
