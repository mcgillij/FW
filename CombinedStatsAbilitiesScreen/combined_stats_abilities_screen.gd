extends "res://Scripts/base_menu_panel.gd"

signal back_button

@export var stat_prefab: PackedScene
@export var stat_label_prefab: PackedScene
@export var skill_prefab: PackedScene
@export var skill_breakdown_prefab: PackedScene
@export var char_view_prefab: PackedScene
@export var ability_view_prefab: PackedScene
@export var character_viewer_prefab: PackedScene

@onready var stat_label_container: HBoxContainer = %stat_label_container
@onready var skills_container: VBoxContainer = %skills_container
@onready var skills_container_2: VBoxContainer = %skills_container2

@onready var job_label: RichTextLabel = %job_label
@onready var job_name: Label = %job_name
@onready var tab_container: TabContainer = %TabContainer
@onready var char_info: VBoxContainer = %"Char Info"
@onready var job_completed: Label = %job_completed

@onready var hover_container: VBoxContainer = %hover_container

const MANA_LABELS_GROUP = "booster1_mana_labels"
const bark_stat = preload("res://Stats/bark.tres")
const reflex_stat = preload("res://Stats/reflex.tres")
const alertness_stat = preload("res://Stats/alertness.tres")
const vigor_stat = preload("res://Stats/vigor.tres")
const enthusiasm_stat = preload("res://Stats/enthusiasm.tres")
const stats_array: Array[FW_Stat] = [bark_stat, reflex_stat, alertness_stat, vigor_stat, enthusiasm_stat]

var inventory_size = 20
var action_bar_size = 5

var job_manager := FW_JobManager.new()

# Highlight effect
# The color to flash the tab header.
@export var highlight_color: Color = Color("ffff00") # Yellow
# The duration of one full blink cycle.
@export var blink_duration: float = 0.5
# How many times the tab should blink.
@export var blink_count: int = 3

var tab_blink_tween: Tween
var tab_blink_active: bool = false

# Job name animation variables
var animation_duration: float = 1.0
var animation_scale_start: Vector2 = Vector2(1.2, 1.2)
var job_name_color_tween: Tween
var job_name_scale_tween: Tween
var job_name_fade_tween: Tween

const RUNE_REVEAL_SHADER := null

var job_label_animation_duration: float = 1.6
var job_label_rune_tween: Tween
var job_label_material: ShaderMaterial
var job_label_reveal: float = 1.0

# Flag to prevent animation on initial scene load
var is_initial_setup: bool = true

# Cached nodes to avoid rebuilding UI every time stats change
var stat_nodes: Dictionary = {}
var skill_nodes: Dictionary = {}

# Cache for stat resources loaded from disk
var stat_resource_cache: Dictionary = {}

func setup_signals() -> void:
	#$MarginContainer.add_theme_constant_override("margin_left", 0)
	#$MarginContainer.add_theme_constant_override("margin_right", 0)
	#$MarginContainer.add_theme_constant_override("margin_top", 0)
	#$MarginContainer.add_theme_constant_override("margin_bottom", 0)
	if not EventBus.is_connected("stat_hover", Callable(self, "_show_stat_prefab")):
		EventBus.connect("stat_hover", Callable(self, "_show_stat_prefab"))
	if not EventBus.is_connected("stat_unhover", Callable(self, "_hide_stat_prefab")):
		EventBus.connect("stat_unhover", Callable(self, "_hide_stat_prefab"))
	if not EventBus.is_connected("skill_hover", Callable(self, "_show_skill_prefab")):
		EventBus.connect("skill_hover", Callable(self, "_show_skill_prefab"))
	if not EventBus.is_connected("skill_unhover", Callable(self, "_hide_skill_prefab")):
		EventBus.connect("skill_unhover", Callable(self, "_hide_skill_prefab"))
	if not EventBus.is_connected("ability_hover", Callable(self, "_set_ability_prefab")):
		EventBus.connect("ability_hover", Callable(self, "_set_ability_prefab"))
	if not EventBus.is_connected("ability_unhover", Callable(self, "_clear_ability_prefab")):
		EventBus.connect("ability_unhover", Callable(self, "_clear_ability_prefab"))
	if not EventBus.is_connected("tab_highlight", Callable(self, "do_tab_highlight")):
		EventBus.connect("tab_highlight", Callable(self, "do_tab_highlight"))
	create_slots()
	load_abilities()
	if not EventBus.is_connected("calculate_job", Callable(self, "_calc_job")):
		EventBus.connect("calculate_job", Callable(self, "_calc_job"))
	_calc_job()
	var tab_bar = tab_container.get_tab_bar()
	if is_instance_valid(tab_bar):
		tab_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func do_tab_highlight() -> void:
	var tab_bar = tab_container.get_tab_bar()
	if not is_instance_valid(tab_bar):
		return

	# If a blink animation is already active, do not trigger again
	if tab_blink_active:
		return

	# Switch to the "Stats and Skills" tab when an ability is placed in the action bar.
	# The Stats and Skills tab is at index 1 in the scene (see CombinedStatsAbilitiesScreen.tscn).
	# This makes sure players immediately see the stat/skill changes when they assign abilities.
	if is_instance_valid(tab_container):
		tab_container.current_tab = 1

	# Cleanup any previous tween and restore styles
	if tab_blink_tween and tab_blink_tween.is_valid():
		tab_blink_tween.kill()
		var original_stylebox_unselected = tab_bar.get_theme_stylebox("tab_unselected", "TabBar")
		tab_bar.add_theme_stylebox_override("tab_unselected", original_stylebox_unselected)
		var original_stylebox_selected = tab_bar.get_theme_stylebox("tab_selected", "TabBar")
		tab_bar.add_theme_stylebox_override("tab_selected", original_stylebox_selected)

	tab_blink_active = true
	var current_tab = tab_container.current_tab
	if current_tab == 0:
		_blink_tab_unselected(tab_bar)
	else:
		_blink_tab_selected(tab_bar)

func _blink_tab(tab_bar: TabBar, style_name: String) -> void:
	var original_stylebox = tab_bar.get_theme_stylebox(style_name, "TabBar")
	var highlight_stylebox := StyleBoxFlat.new()
	highlight_stylebox.bg_color = highlight_color
	highlight_stylebox.corner_radius_top_left = 8
	highlight_stylebox.corner_radius_top_right = 8
	highlight_stylebox.corner_radius_bottom_left = 8
	highlight_stylebox.corner_radius_bottom_right = 8
	highlight_stylebox.set_border_width_all(2)
	highlight_stylebox.border_color = Color.WHITE

	var blink_times = blink_count * 2
	var local_highlight := [false] # Use array to allow mutation in lambda

	var tween = create_tween()
	tab_blink_tween = tween
	tween.set_loops(blink_times)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		local_highlight[0] = !local_highlight[0]
		tab_bar.add_theme_stylebox_override(style_name, highlight_stylebox if local_highlight[0] else original_stylebox)
	).set_delay(blink_duration / 2.0)

	tween.finished.connect(func():
		tab_bar.add_theme_stylebox_override(style_name, original_stylebox)
		tab_blink_active = false
	)

func _blink_tab_unselected(tab_bar: TabBar) -> void:
	_blink_tab(tab_bar, "tab_unselected")

func _blink_tab_selected(tab_bar: TabBar) -> void:
	_blink_tab(tab_bar, "tab_selected")

func setup_char() -> void:
	for c in char_info.get_children():
		c.queue_free()
	var character = char_view_prefab.instantiate()
	char_info.add_child(character)
	character.setup(GDM.player.character)

func setup_stats(old_stats: Dictionary = {}, modified_stats: Array = []) -> void:
	# Use PRIMARY_STATS for main stats
	for stat_name in GDM.player.stats.PRIMARY_STATS:
		var stat_res = _get_stat_resource(stat_name)
		var stat_label = stat_nodes.get(stat_name, null)
		if not stat_label or not is_instance_valid(stat_label):
			stat_label = stat_label_prefab.instantiate()
			stat_label_container.add_child(stat_label)
			stat_nodes[stat_name] = stat_label
		var is_modified = stat_name in modified_stats
		stat_label.setup(stat_res, old_stats.get(stat_name, 0), is_modified)

func setup_skills(old_stats: Dictionary = {}, modified_stats: Array = []) -> void:
	# Use SECONDARY_STATS for skills/derived stats
	var secondary_stats = GDM.player.stats.SECONDARY_STATS
	var skill_count = secondary_stats.size()
	for i in secondary_stats.size():
		var sk = secondary_stats[i]
		@warning_ignore("integer_division")
		var container = skills_container if i < skill_count / 2 else skills_container_2
		var sk_prefab_node = skill_nodes.get(sk, null)
		if not sk_prefab_node or not is_instance_valid(sk_prefab_node):
			sk_prefab_node = skill_prefab.instantiate()
			skill_nodes[sk] = sk_prefab_node
			container.add_child(sk_prefab_node)
		elif sk_prefab_node.get_parent() != container:
			container.add_child(sk_prefab_node)
		var is_modified = sk in modified_stats
		sk_prefab_node.setup(sk, old_stats.get(sk, 0), is_modified)

func setup() -> void:
	# Ensure equipment bonuses are up to date before displaying stats
	if GDM.player:
		GDM.player.setup_equipment()
	setup_signals()
	_ensure_job_label_material()
	_set_job_label_reveal(1.0)
	clear_containers()
	setup_char()
	setup_stats()
	setup_skills()

func _show_stat_prefab(stat:FW_Stat) -> void:

	# Clear any existing prefabs first to prevent multiples
	_clear_hover_container()
	var stat_display = stat_prefab.instantiate()
	hover_container.add_child(stat_display)
	stat_display.setup(stat)

func _hide_stat_prefab() -> void:
	_clear_hover_container()

func _show_skill_prefab(skill_name: String) -> void:

	# Clear any existing prefabs first to prevent multiples
	_clear_hover_container()
	var skill_display = skill_breakdown_prefab.instantiate()
	hover_container.add_child(skill_display)
	skill_display.setup(skill_name)

func _hide_skill_prefab() -> void:
	_clear_hover_container()

func _on_back_button_pressed() -> void:
	if tab_blink_tween and tab_blink_tween.is_valid():
		tab_blink_tween.kill()
		tab_blink_active = false
		var tab_bar = tab_container.get_tab_bar()
		if is_instance_valid(tab_bar):
			var original_stylebox_unselected = tab_bar.get_theme_stylebox("tab_unselected", "TabBar")
			tab_bar.add_theme_stylebox_override("tab_unselected", original_stylebox_unselected)
			var original_stylebox_selected = tab_bar.get_theme_stylebox("tab_selected", "TabBar")
			tab_bar.add_theme_stylebox_override("tab_selected", original_stylebox_selected)

	# Stop job animation if running
	if job_name_scale_tween and job_name_scale_tween.is_valid():
		job_name_scale_tween.kill()
	if job_name_color_tween and job_name_color_tween.is_valid():
		job_name_color_tween.kill()
	if job_name_fade_tween and job_name_fade_tween.is_valid():
		job_name_fade_tween.kill()
	job_name.scale = Vector2.ONE
	job_name.modulate.a = 1.0

	# Stop job label animation if running
	if job_label_rune_tween and job_label_rune_tween.is_valid():
		job_label_rune_tween.kill()
	_set_job_label_reveal(1.0)

	save()
	GDM.vs_save()
	emit_signal("back_button")
	# cleanup
	clear_containers()

func clear_containers() -> void:
	for c in stat_label_container.get_children():
		c.queue_free()
	for d in skills_container.get_children():
		d.queue_free()
	for r in skills_container_2.get_children():
		r.queue_free()
	# Also clear hover container
	for h in hover_container.get_children():
		h.queue_free()
	stat_nodes.clear()
	skill_nodes.clear()

func create_slots() -> void:
	if %inventory.get_child_count() > 0:
		return
	for i in inventory_size:
		var slot := FW_AbilityInventorySlot.new()
		slot.init(GDM.inventory_item_size)
		%inventory.add_child(slot)
	# init the action bar at the bottom
	var index := 1 # this and the above array will need to change if we add more slots
	for i in action_bar_size:
		var slot := FW_AbilityInventorySlot.new()
		slot.init(GDM.inventory_item_size, index)
		%action_bar.add_child(slot)
		index += 1

func load_abilities() -> void:
	clear_slots()
	for j in GDM.player.unlocked_abilities.size():
		if GDM.player.unlocked_abilities[j]:
			if GDM.player.unlocked_abilities[j] not in GDM.player.abilities:
				var item := FW_AbilityInventoryItem.new()
				item.init(GDM.player.unlocked_abilities[j])
				item.gui_input.connect(_on_ability_click.bind(GDM.player.unlocked_abilities[j]))
				%inventory.get_child(j).add_child(item)
	for j in GDM.player.abilities.size():
		if GDM.player.abilities[j]:
			var item := FW_AbilityInventoryItem.new()
			item.init(GDM.player.abilities[j])
			%action_bar.get_child(j).add_child(item)

func clear_slots() -> void:
	for slot in %inventory.get_children():
		if slot.get_child_count() > 0:
			for child in slot.get_children():
				child.queue_free()
	for slot in %action_bar.get_children():
		if slot.get_child_count() > 0:
			for child in slot.get_children():
				child.queue_free()

func get_ability_types() -> Array[String]:
	var abilities_array: Array[String]
	for i in %action_bar.get_child_count():
		var item = %action_bar.get_child(i)
		if item:
			if item.get_child_count() > 0:
				var child = item.get_child(0)
				if child:
					abilities_array.append(FW_Ability.ABILITY_TYPES.keys()[child.data.ability_type])
	return abilities_array

func _calc_job() -> void:
	var abilities_array = get_ability_types()
	var job = FW_JobManager.get_job(abilities_array)
	var stats_dict := FW_JobManager.count_ability_types(abilities_array)
	var effects := FW_JobManager.generate_effects(stats_dict)
	var modified_stats = effects.keys().filter(func(k): return effects[k] != 0)
	var old_stats = GDM.player.stats.get_stat_values()
	GDM.player.stats.remove_all_job_bonus()
	GDM.player.stats.apply_job_bonus(effects)
	var label_color := FW_Utils.blend_type_colors(abilities_array)

	# Set final values without animation on initial setup
	if is_initial_setup:
		is_initial_setup = false
		if job:
			if str(job.name).to_lower() != "unassigned":
				job_name.text = job.name
				job_name.set("theme_override_colors/font_color", label_color)
			else:
				job_name.text = ""
				job_name.set("theme_override_colors/font_color", Color.WHITE)
			job_label.text = job.description
			_set_job_completed_text(job)
		else:
			job_name.text = ""
			job_name.set("theme_override_colors/font_color", Color.WHITE)
			job_label.text = ""
			_set_job_completed_text(job)
		_set_job_label_reveal(1.0)
		var new_stats = GDM.player.stats.get_stat_values()
		update_stats_and_skills(new_stats, modified_stats)
	else:
		# Animate when abilities change
		if job:
			# Don't show the 'Unassigned' placeholder job name
			if str(job.name).to_lower() != "unassigned":
				animate_job_name_change(job.name, label_color)
			else:
				animate_job_name_change("", Color.WHITE)
			animate_job_label_change(job.description)
			_set_job_completed_text(job)
		else:
			animate_job_name_change("", Color.WHITE)
			animate_job_label_change("")
			_set_job_completed_text(job)

		update_stats_and_skills(old_stats, modified_stats)

func update_stats_and_skills(old_stats: Dictionary, modified_stats: Array) -> void:
	setup_stats(old_stats, modified_stats)
	setup_skills(old_stats, modified_stats)

func _get_stat_resource(stat_name: String) -> FW_Stat:
	if stat_resource_cache.has(stat_name):
		return stat_resource_cache[stat_name]
	var stat_res: FW_Stat = load("res://Stats/%s.tres" % stat_name)
	stat_resource_cache[stat_name] = stat_res
	return stat_res

func save() -> void:
	# abilities
	var abilities_array: Array[FW_Ability]
	for i in %action_bar.get_child_count():
		var item = %action_bar.get_child(i)
		if item:
			if item.get_child_count() > 0:
				var child = item.get_child(0)
				if child:
					abilities_array.append(child.data)
			else:
				abilities_array.append(null)
	GDM.player.abilities = abilities_array
	# job related
	var abilities_types_array = get_ability_types()
	var job = FW_JobManager.get_job(abilities_types_array)
	var label_color := FW_Utils.blend_type_colors(abilities_types_array)
	job.job_color = label_color
	GDM.player.job = job
	var stats_dict := FW_JobManager.count_ability_types(abilities_types_array)
	var effects := FW_JobManager.generate_effects(stats_dict)
	GDM.player.stats.remove_all_job_bonus()
	GDM.player.stats.apply_job_bonus(effects)

func _on_ability_click(event: InputEvent, ability: FW_Ability) -> void:
	# probably swap this to on mouse over etc similarly to the stats, but for now it's ok
	if event.is_action_pressed("ui_touch"):
		_clear_hover_container()
		var ab = ability_view_prefab.instantiate()
		hover_container.add_child(ab)
		ab.setup(ability)

func _clear_ability_prefab() -> void:
	_clear_hover_container()

func _set_ability_prefab(ability: FW_Ability) -> void:
	# Clear any existing prefabs first to prevent multiples
	_clear_hover_container()
	var ab = ability_view_prefab.instantiate()
	hover_container.add_child(ab)
	ab.setup(ability)


func _clear_hover_container() -> void:
	# Centralized helper to clear hover prefabs. Keeps code DRY and avoids subtle differences.
	for c in hover_container.get_children():
		c.queue_free()

func _set_job_completed_text(job: FW_Job) -> void:
	if job and UnlockManager.has_job_win(job.name):
		job_completed.text = "✓"
	else:
		job_completed.text = ""

# Job name animation functions
func animate_job_name_change(new_name: String, new_color: Color) -> void:
	var name_to_apply := new_name
	var color_to_apply := new_color

	# Stop any existing animations
	if job_name_color_tween and job_name_color_tween.is_valid():
		job_name_color_tween.kill()
	if job_name_scale_tween and job_name_scale_tween.is_valid():
		job_name_scale_tween.kill()
	if job_name_fade_tween and job_name_fade_tween.is_valid():
		job_name_fade_tween.kill()
	job_name.modulate.a = 1.0

	# Start scale and color tweens
	job_name_scale_tween = create_tween()
	job_name_scale_tween.tween_property(job_name, "scale", Vector2.ONE, animation_duration).from(animation_scale_start).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	job_name_color_tween = create_tween()
	job_name_color_tween.tween_property(job_name, "theme_override_colors/font_color", color_to_apply, animation_duration).from(job_name.get("theme_override_colors/font_color") if job_name.get("theme_override_colors/font_color") else Color.WHITE)

	job_name_fade_tween = create_tween()
	job_name_fade_tween.tween_property(job_name, "modulate:a", 0.0, 0.12)
	job_name_fade_tween.tween_callback(func():
		job_name.text = name_to_apply
		job_name.set("theme_override_colors/font_color", color_to_apply)
	)
	job_name_fade_tween.tween_property(job_name, "modulate:a", 1.0, 0.18)
	job_name_fade_tween.tween_callback(func():
		_start_job_name_glow(color_to_apply)
	)

func _start_job_name_glow(_unused_color: Color) -> void:
	# Emit a short burst of small UI particles (ColorRects) that rise and fade.
	# ensure the job label has no custom material/shader applied
	if job_name.material and is_instance_valid(job_name.material):
		job_name.material = null

	# also clear job_label shader/material so the rune shader is removed
	if job_label.material and is_instance_valid(job_label.material):
		job_label.material = null
	job_label_material = null

	var job_font_color: Color = job_name.get("theme_override_colors/font_color") if job_name.get("theme_override_colors/font_color") else Color(1,1,1,1)
	_emit_job_particles(job_font_color)

func _emit_job_particles(color: Color) -> void:
	# Emit particles from the job_name label's global rect, positioning them on the CanvasLayer in global coordinates.
	var label_global_rect = job_name.get_global_rect()
	var rune_tex = null
	if ResourceLoader.exists("res://Icons/rune.png"):
		rune_tex = load("res://Icons/rune.png")

	var spawn_count := 14
	for i in spawn_count:
		var use_texture := rune_tex != null
		var dot: Control
		if use_texture:
			var tex_rect := TextureRect.new()
			tex_rect.texture = rune_tex
			tex_rect.expand = true
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dot = tex_rect
			dot.modulate = color
		else:
			var cr := ColorRect.new()
			cr.color = color
			dot = cr
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var s = 6 + randi() % 8
		dot.custom_minimum_size = Vector2(s, s)

		# start bigger to show rune detail
		dot.scale = Vector2(3, 3)

		# pick a random point inside the label's global rect
		var gx = label_global_rect.position.x + randf() * label_global_rect.size.x
		var gy = label_global_rect.position.y + randf() * label_global_rect.size.y * 0.6 + label_global_rect.size.y * 0.15
		# position in global canvas coordinates on the CanvasLayer
		dot.position = Vector2(gx, gy)
		add_child(dot)

		# animate upward with some horizontal drift, fade, scale down, and spin
		var rise = -60 - randf() * 40
		var horizontal = randf() * 80 - 40  # -40 to 40
		var life = 0.9 + randf() * 0.6
		var target_pos = dot.position + Vector2(horizontal, rise)
		var tw = create_tween()
		tw.tween_property(dot, "position", target_pos, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(dot, "scale", Vector2(0.2, 0.2), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(dot, "rotation", 2 * PI, life).set_trans(Tween.TRANS_LINEAR)
		# Tint particles from job color -> white during life
		if use_texture:
			tw.tween_property(dot, "modulate", Color(1,1,1,1), life)
		else:
			tw.tween_property(dot, "color", Color(1,1,1,1), life)
		tw.tween_property(dot, "modulate:a", 0.0, life).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			if is_instance_valid(dot):
				dot.queue_free()
		)
func animate_job_label_change(new_text: String) -> void:
	_ensure_job_label_material()
	if job_label_rune_tween and job_label_rune_tween.is_valid():
		job_label_rune_tween.kill()
	job_label.text = new_text
	if not job_label_material:
		return
	if new_text.is_empty():
		_set_job_label_reveal(1.0)
		return
	job_label_material.set_shader_parameter("seed", randf() * 64.0)
	job_label_material.set_shader_parameter("scroll_speed", 0.35)
	job_label_material.set_shader_parameter("flicker_speed", 2.4)
	job_label_material.set_shader_parameter("glint_strength", 0.45)
	_set_job_label_reveal(0.0)
	job_label_rune_tween = create_tween()
	job_label_rune_tween.set_trans(Tween.TRANS_SINE)
	job_label_rune_tween.set_ease(Tween.EASE_IN_OUT)
	job_label_rune_tween.tween_method(Callable(self, "_set_job_label_reveal"), 0.0, 1.0, job_label_animation_duration)
	job_label_rune_tween.finished.connect(func():
		_set_job_label_reveal(1.0)
	)

func _ensure_job_label_material() -> void:
	if job_label_material:
		return
	if not RUNE_REVEAL_SHADER:
		return
	job_label_material = ShaderMaterial.new()
	job_label_material.shader = RUNE_REVEAL_SHADER
	job_label.material = job_label_material
	job_label_material.set_shader_parameter("seed", randf() * 64.0)
	job_label_material.set_shader_parameter("scroll_speed", 0.0)
	job_label_material.set_shader_parameter("flicker_speed", 0.0)
	_set_job_label_reveal(1.0)

func _set_job_label_reveal(value: float) -> void:
	job_label_reveal = clamp(value, 0.0, 1.0)
	if job_label_material:
		job_label_material.set_shader_parameter("reveal", job_label_reveal)
		if job_label_reveal >= 0.999:
			job_label_material.set_shader_parameter("scroll_speed", 0.0)
			job_label_material.set_shader_parameter("flicker_speed", 0.0)
			job_label_material.set_shader_parameter("glint_strength", 0.0)
