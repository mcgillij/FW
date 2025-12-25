extends "res://Scripts/base_menu_panel.gd"

signal trigger_story

@onready var loot_panel_container: HBoxContainer = %loot_panel_container

@onready var you_win_label: Label = %you_win_label

@onready var monster_panel_container: VBoxContainer = %monster_container
@onready var ability_panel_container: VBoxContainer = %ability_container
@onready var mana_panel_container: VBoxContainer = %mana_container
@onready var damage_panel_container: VBoxContainer = %damage_container
@onready var continue_button: Button = %ContinueButton
@onready var no_loot_label: Label = %no_loot_label

@export var mana_panel: PackedScene
@export var ability_panel: PackedScene
@export var damage_panel: PackedScene
@export var monster_panel: PackedScene
@export var loot_item_panel: PackedScene
@export var roll_for_loot: PackedScene
@export var floating_numbers_prefab: PackedScene

#const CombatLogOverlay = preload("res://Scripts/FW_CombatLogOverlay.gd")

@onready var loot_scroll_area: ScrollContainer = %loot_scroll_area

@onready var see_combat_log: Button = %see_combat_log

var combat_log_overlay: Panel = null
var is_combat_log_showing: bool = false

var noise := load("res://Noise/Noise.tres")
var is_out = false

func _ready() -> void:
	var rfl = roll_for_loot.instantiate()
	loot_panel_container.add_child(rfl)
	rfl.setup(GDM.monster_to_fight)
	continue_button.disabled = true
	EventBus.roll_lost.connect(_loot_roll_lost)
	EventBus.roll_won.connect(_loot_roll_won)
	EventBus.gain_gold.connect(_on_gain_gold)
	#see_combat_log.pressed.connect(_on_see_combat_log_pressed)

func _loot_roll_won() -> void:
	await melt_card_with_loot_reveal()
	continue_button.disabled = false

func _loot_roll_lost() -> void:
	no_loot_label.show()
	await melt_card()
	continue_button.disabled = false

func _on_game_manager_game_won_vs() -> void:
	#get_tree().paused = true
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_add_mana_panel()
	_add_ability_panel()
	_add_damage_panel()
	_add_monster_panel()
	_handle_achievements_and_quests()
	GDM.vs_save()
	_setup_juicy_label()

	if not is_out:
		is_out = true
		slide_in()
		continue_button.disabled = true

func _setup_juicy_label() -> void:
	# Render label to texture
	var viewport := SubViewport.new()
	viewport.size = you_win_label.size
	viewport.transparent_bg = true # <-- Add this line
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(viewport)

	var label_copy := you_win_label.duplicate()
	label_copy.position = Vector2.ZERO
	label_copy.visible = true
	viewport.add_child(label_copy)

	await get_tree().process_frame

	var tex := viewport.get_texture()
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://Shaders/JuicyLabel.gdshader")
	shader_material.set_shader_parameter("strength", 0.015) # Initialize parameter

	var tex_rect := TextureRect.new()
	tex_rect.texture = tex
	tex_rect.size = you_win_label.size
	tex_rect.material = shader_material
	tex_rect.position = you_win_label.position
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	you_win_label.hide()
	you_win_label.get_parent().add_child(tex_rect)

	# Optionally, add particles as before
	var particles = CPUParticles2D.new()
	particles.position = Vector2(300, 50)
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 1.5
	particles.one_shot = false
	particles.speed_scale = 1.5
	particles.explosiveness = 0.8
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 50.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 150.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color.GOLD
	tex_rect.add_child(particles)

	# Tween setup as before
	var tween = get_tree().create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shader_material, "shader_parameter/strength", 0.01, 0.8)
	tween.tween_property(shader_material, "shader_parameter/strength", 0.02, 0.7)

func _add_mana_panel() -> void:
	var mp = mana_panel.instantiate()
	mana_panel_container.add_child(mp)
	mp.set_used_mana(GDM.tracker.mana_spent)
	mp.set_gained_mana(GDM.tracker.mana_gained)

func _add_ability_panel() -> void:
	var ability_array: Array[FW_Ability] = []
	for ability in GDM.player.abilities:
		if ability:
			ability_array.append(ability)
	var ap = ability_panel.instantiate()
	ability_panel_container.add_child(ap)
	ap.make_ability_stats(ability_array)

func _add_damage_panel() -> void:
	var dp = damage_panel.instantiate()
	damage_panel_container.add_child(dp)

func _add_monster_panel() -> void:
	var monster_p = monster_panel.instantiate()
	monster_panel_container.add_child(monster_p)
	monster_p.setup_monster_display(GDM.monster_to_fight)

func _handle_loot() -> void:
	var lm = FW_LootManager.new()
	var loot = lm.generate_loot_for_victory(GDM.monster_to_fight)
	lm.grant_loot_to_player(loot)
	lm.create_loot_panels(loot, loot_item_panel, loot_panel_container)

func _handle_achievements_and_quests() -> void:
	Achievements.increment_achievement_progress_by_type("eliminate_monsters")
	GDM.safe_steam_increment_stat("monsters_defeated")
	if GDM.monster_to_fight.type == FW_Monster_Resource.monster_type.ELITE:
		Achievements.increment_achievement_progress_by_type("eliminate_elites")
		GDM.safe_steam_increment_stat("elites_defeated")
	elif GDM.monster_to_fight.type == FW_Monster_Resource.monster_type.BOSS:
		Achievements.increment_achievement_progress_by_type("eliminate_bosses")
		GDM.safe_steam_increment_stat("bosses_defeated")
	# filter undead for quest
	if GDM.monster_to_fight.subtype in [FW_Monster_Resource.monster_subtype.SKELETON, FW_Monster_Resource.monster_subtype.VAMPIRE, FW_Monster_Resource.monster_subtype.SHADOW]:
		QuestManager.update_quest_progress(FW_QuestGoal.GOAL_TYPE.ELIMINATE, "undead")
	QuestManager.update_quest_progress(FW_QuestGoal.GOAL_TYPE.ELIMINATE, "any")
	GDM.vs_save()

func melt_card() -> void:
	var roll_panel = loot_panel_container.get_child(0)
	var roll_panel_global_pos = roll_panel.global_position

	var viewport := SubViewport.new()
	viewport.size = roll_panel.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(viewport)

	var roll_panel_copy = roll_panel.duplicate()
	roll_panel_copy.process_mode = Node.PROCESS_MODE_ALWAYS
	roll_panel_copy.position = Vector2.ZERO
	viewport.add_child(roll_panel_copy)

	await get_tree().process_frame

	# Hide the original immediately after snapshot
	roll_panel.visible = false

	var tex := viewport.get_texture()
	var overlay := TextureRect.new()
	overlay.texture = tex
	overlay.size = roll_panel.size
	overlay.global_position = roll_panel_global_pos
	overlay.material = burn_shader_material()
	overlay.ignore_texture_size = true
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	await get_tree().process_frame

	if not is_inside_tree():
		overlay.queue_free()
		roll_panel_copy.queue_free()
		roll_panel.queue_free()
		return

	var tween = get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay.material, "shader_parameter/dissolve_value", 0, .75)
	tween.tween_callback(Callable(overlay, "queue_free"))
	tween.tween_callback(Callable(roll_panel_copy, "queue_free"))
	tween.tween_callback(Callable(roll_panel, "queue_free"))
	tween.play()
	await tween.finished

func melt_card_with_loot_reveal() -> void:
	var roll_panel = loot_panel_container.get_child(0)
	var roll_panel_global_pos = roll_panel.global_position

	# 1. Snapshot the roll panel
	var viewport := SubViewport.new()
	viewport.size = roll_panel.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(viewport)

	var roll_panel_copy = roll_panel.duplicate()
	roll_panel_copy.process_mode = Node.PROCESS_MODE_ALWAYS
	roll_panel_copy.position = Vector2.ZERO
	viewport.add_child(roll_panel_copy)

	await get_tree().process_frame

	# 2. Hide the original roll panel
	roll_panel.visible = false

	# 3. Add the loot panels (now behind the overlay)
	_handle_loot()

	# 4. Add the overlay and burn
	var tex := viewport.get_texture()
	var overlay := TextureRect.new()
	overlay.texture = tex
	overlay.size = roll_panel.size
	overlay.global_position = roll_panel_global_pos
	overlay.material = burn_shader_material()
	overlay.ignore_texture_size = true
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	await get_tree().process_frame

	if not is_inside_tree():
		overlay.queue_free()
		roll_panel_copy.queue_free()
		roll_panel.queue_free()
		return

	var tween = get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay.material, "shader_parameter/dissolve_value", 0, .75)
	tween.tween_callback(Callable(overlay, "queue_free"))
	tween.tween_callback(Callable(roll_panel_copy, "queue_free"))
	tween.tween_callback(Callable(roll_panel, "queue_free"))
	tween.play()
	await tween.finished

func burn_shader_material() -> ShaderMaterial:
	var shader := ShaderMaterial.new()
	shader.shader = load("res://Shaders/Burn.gdshader").duplicate()
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	shader.set_shader_parameter("dissolve_value", 1.0)
	shader.set_shader_parameter("burn_size", .23)
	shader.set_shader_parameter("burn_color", Color.DARK_BLUE)
	shader.set_shader_parameter("dissolve_texture", nt)
	return shader

func _on_continue_button_pressed() -> void:
	continue_button.disabled = true
	# Clean up combat log overlay if showing
	if is_combat_log_showing:
		FW_CombatLogOverlay.hide_combat_log_overlay(combat_log_overlay)
		combat_log_overlay = null
		is_combat_log_showing = false
	get_tree().paused = false
	GDM.tracker.reset()
	if $"../GameManager".triggers_story:
		pass
		#slide_out()
		# probably have to make a vs mode specific story handler if
		# we want to go about it that way.
		#emit_signal("trigger_story", $"../GameManager".level)
	else:
		if GDM.current_info.level.level_depth == GDM.current_info.level_to_generate["max_depth"]:
			# to the world map
			ScreenRotator.change_scene("res://WorldMap/world_map.tscn")
		else:
			# to the level select
			ScreenRotator.change_scene("res://Scenes/level_select2.tscn")

func _on_gain_gold(amount: int) -> void:
	SoundManager._player_random_money_sound()
	var current = floating_numbers_prefab.instantiate()
	current._gain_gold(amount)
	current.position.x = 700  # Adjust position as needed for victory screen
	current.position.y = 550
	add_child(current)

func _on_see_combat_log_pressed() -> void:
	if not is_combat_log_showing:
		combat_log_overlay = FW_CombatLogOverlay.show_combat_log_overlay(self)
		is_combat_log_showing = true
		see_combat_log.text = "Hide Combat Log"
	else:
		FW_CombatLogOverlay.hide_combat_log_overlay(combat_log_overlay)
		combat_log_overlay = null
		is_combat_log_showing = false
		see_combat_log.text = "See Combat Log"

func enable_buttons() -> void:
	super.enable_buttons()
	continue_button.disabled = true
