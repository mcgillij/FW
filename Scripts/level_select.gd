extends CanvasLayer

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var vbox_container: VBoxContainer = %VBoxContainer

var unlock_particles = preload("res://Effects/unlock_level/unlock_effect.tscn")
var trippy_shader = preload("res://Shaders/trippy_wave_fade.gdshader")
var snow_shader = preload("res://Shaders/snow.gdshader")
var plateau_shader = preload("res://Shaders/plateau_wind.gdshader")
var spotlight_shader = preload("res://Shaders/spotlights.gdshader")
var storm_shader = preload("res://Shaders/dynamic_storm.gdshader")
var neon_glow_shader = preload("res://Shaders/neon_glow.gdshader")
var wet_distortion = preload("res://Shaders/wet_distortion.gdshader")
var nebula = preload("res://Shaders/majestic_sky.gdshader")

func _ready() -> void:
	GDM.safe_steam_set_rich_presence("#puzzle_map")
	SoundManager.wire_up_all_buttons()
	scroll_container.scroll_ended.connect(scroll)
	scroll_container.tree_exiting.connect(scroll)

	# Keep track of the last unlocked panel to scroll to
	var last_unlocked_panel: Control = null
	var last_unlocked_backdrop: Control = null

	# Show unlocked acts and identify the latest one
	if UnlockManager.get_progress("puzzle_act1"):
		var act1_panel = vbox_container.get_node("act1")
		act1_panel.show()
		var backdrop2 = vbox_container.get_node("level_backdrop2")
		show_backdrop_with_shader(backdrop2, snow_shader)
		if UnlockManager.just_unlocked_act == "act1":
			last_unlocked_panel = act1_panel
			last_unlocked_backdrop = backdrop2

	if UnlockManager.get_progress("puzzle_act2"):
		var act2_panel = vbox_container.get_node("act2")
		act2_panel.show()
		var backdrop3 = vbox_container.get_node("level_backdrop3")
		show_backdrop_with_shader(backdrop3, plateau_shader)
		if UnlockManager.just_unlocked_act == "act2":
			last_unlocked_panel = act2_panel
			last_unlocked_backdrop = backdrop3

	if UnlockManager.get_progress("puzzle_act3"):
		var act3_panel = vbox_container.get_node("act3")
		act3_panel.show()
		var backdrop4 = vbox_container.get_node("level_backdrop4")
		show_backdrop_with_shader(backdrop4, spotlight_shader)
		if UnlockManager.just_unlocked_act == "act3":
			last_unlocked_panel = act3_panel
			last_unlocked_backdrop = backdrop4

	if UnlockManager.get_progress("puzzle_act4"):
		var act4_panel = vbox_container.get_node("act4")
		act4_panel.show()
		var backdrop5 = vbox_container.get_node("level_backdrop5")
		show_backdrop_with_shader(backdrop5, storm_shader)
		if UnlockManager.just_unlocked_act == "act4":
			last_unlocked_panel = act4_panel
			last_unlocked_backdrop = backdrop5

	if UnlockManager.get_progress("puzzle_act5"):
		var act5_panel = vbox_container.get_node("act5")
		act5_panel.show()
		var backdrop6 = vbox_container.get_node("level_backdrop6")
		show_backdrop_with_shader(backdrop6, neon_glow_shader)
		if UnlockManager.just_unlocked_act == "act5":
			last_unlocked_panel = act5_panel
			last_unlocked_backdrop = backdrop6

	if UnlockManager.get_progress("puzzle_act6"):
		var act6_panel = vbox_container.get_node("act6")
		act6_panel.show()
		var backdrop7 = vbox_container.get_node("level_backdrop7")
		show_backdrop_with_shader(backdrop7, wet_distortion)
		if UnlockManager.just_unlocked_act == "act6":
			last_unlocked_panel = act6_panel
			last_unlocked_backdrop = backdrop7

	if UnlockManager.get_progress("puzzle_bonus"):
		var bonus_panel = vbox_container.get_node("bonus")
		bonus_panel.show()
		var backdrop8 = vbox_container.get_node("level_backdrop8")
		show_backdrop_with_shader(backdrop8, nebula)
		if UnlockManager.just_unlocked_act == "bonus":
			last_unlocked_panel = bonus_panel
			last_unlocked_backdrop = backdrop8

	# If a new act was just unlocked, scroll to it and animate
	if last_unlocked_panel:
		call_deferred("_scroll_and_animate_panel", last_unlocked_panel, last_unlocked_backdrop)
	else:
		# Otherwise, just restore the previous scroll position
		scroll_container.set_deferred("scroll_vertical", GDM.normal_level_select_scroll_value)

func _scroll_and_animate_panel(panel: Control, level_backdrop: Control) -> void:
	# Step 1: Scroll to the new panel
	var scroll_tween = create_tween()
	scroll_tween.set_trans(Tween.TRANS_CUBIC)
	scroll_tween.set_ease(Tween.EASE_IN_OUT)
	scroll_tween.tween_property(scroll_container, "scroll_vertical", panel.position.y, 1).from_current()

	# Step 2: When scroll finishes, fire both fade tweens and particle effect
	scroll_tween.finished.connect(func():
		# Store original materials
		var original_panel_material = panel.material
		var original_backdrop_material = level_backdrop.material

		# Create shader materials for the unlock effect
		var panel_mat = ShaderMaterial.new()
		panel_mat.shader = trippy_shader
		panel.material = panel_mat
		panel_mat.set_shader_parameter("fade_amount", 0.0)

		var backdrop_mat = ShaderMaterial.new()
		backdrop_mat.shader = trippy_shader
		level_backdrop.material = backdrop_mat
		backdrop_mat.set_shader_parameter("fade_amount", 0.0)

		# Fire both fade tweens
		var panel_tween = create_tween()
		panel_tween.tween_property(panel_mat, "shader_parameter/fade_amount", 1.0, 0.3)

		var backdrop_tween = create_tween()
		backdrop_tween.tween_property(backdrop_mat, "shader_parameter/fade_amount", 1.0, 1).set_ease(Tween.EASE_OUT)

		# Fireworks-style staggered particle effects
		var center = panel.get_global_rect().position + panel.get_global_rect().size / 2
		var rng = RandomNumberGenerator.new()
		for i in range(5):
			await get_tree().create_timer(i * 0.15).timeout
			var fw_offset = Vector2(rng.randf_range(-60, 60), rng.randf_range(-40, 40))
			var particles = unlock_particles.instantiate()
			particles.global_position = center + fw_offset
			add_child(particles)
			move_child(particles, get_child_count() - 1)
		SoundManager._play_level_unlock_sound()
		# Step 3: Restore original materials after animation
		await get_tree().create_timer(4.0).timeout
		panel.material = original_panel_material
		level_backdrop.material = original_backdrop_material
	)

	# Reset the just_unlocked_act flag
	UnlockManager.clear_just_unlocked_act()

func set_scroll_from_controller(pos: Vector2) -> void:
	scroll_container.set_deferred("scroll_vertical", pos.y)

func _on_back_button_pressed() -> void:
	ScreenRotator.change_scene("res://Scenes/game_menu2.tscn")

func scroll() -> void:
	GDM.normal_level_select_scroll_value = scroll_container.scroll_vertical

func show_backdrop_with_shader(backdrop: Control, shader: Shader):
	backdrop.show()
	var mat = ShaderMaterial.new()
	mat.shader = shader
	backdrop.material = mat
