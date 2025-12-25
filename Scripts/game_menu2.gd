extends Control

@export var parallax_bg: PackedScene

var transitioning = false

func _ready() -> void:
	var bg = parallax_bg.instantiate()
	add_child(bg)
	get_tree().paused = false
	MusicManager._play_music()
	GDM.safe_steam_set_rich_presence("#main_menu")
	transitioning = true
	$main_menu.slide_in()
	await $main_menu.slide_in_finished
	transitioning = false

func perform_transition(from_panel: CanvasLayer, to_panel: CanvasLayer) -> void:
	if transitioning:
		return
	transitioning = true
	if from_panel:
		from_panel.slide_out()
		await from_panel.slide_out_finished
	to_panel.slide_in()
	await to_panel.slide_in_finished
	transitioning = false

func _on_main_menu_settings_pressed() -> void:
	if transitioning:
		return
	perform_transition($main_menu, $settings)
	GDM.safe_steam_set_rich_presence("#settings")

func _on_settings_back_button_pressed() -> void:
	perform_transition($settings, $main_menu)
	GDM.safe_steam_set_rich_presence("#main_menu")

func _on_main_menu_tutorial_pressed() -> void:
	perform_transition($main_menu, $HelpPanel)

func _on_main_menu_play_pressed() -> void:
	if $main_menu.play_aq.disabled:
		return
	if transitioning:
		return
	$main_menu.play_aq.disabled = true
	transitioning = true
	GDM.game_mode = GDM.game_types.normal
	GDM.set_data() # single player setup
	ScreenRotator.change_scene("res://Scenes/level_select.tscn")

func _on_main_menu_play_2_pressed() -> void:
	if $main_menu.play_button.disabled:
		return
	if transitioning:
		return
	$main_menu.play_button.disabled = true
	transitioning = true
	GDM.game_mode = GDM.game_types.vs
	GDM.setup_worldstate()
	ScreenRotator.change_scene("res://DifficultySelect/DifficultySelect.tscn")

func _on_achievements_back_button() -> void:
	perform_transition($Achievements, $main_menu)

func _on_main_menu_achievement_pressed() -> void:
	perform_transition($main_menu, $Achievements)

func _on_help_panel_back_button() -> void:
	perform_transition($HelpPanel, $main_menu)

func _on_mastery_tracker_back_button() -> void:
	perform_transition($MasteryTracker, $main_menu)

func _on_main_menu_master_tracker_pressed() -> void:
	perform_transition($main_menu, $MasteryTracker)

func _on_main_menu_play_atiya_solitaire() -> void:
	GDM.game_mode = GDM.game_types.solitaire
	ScreenRotator.change_scene("res://Solitaire/Solitaire.tscn")

func _on_announcements_back_button() -> void:
	perform_transition($Announcements, $main_menu)

func _on_main_menu_announcement_button_pressed() -> void:
	perform_transition($main_menu, $Announcements)
