extends "res://Scripts/base_menu_panel.gd"

@onready var run_away_button: Button = %run_away_button
@onready var try_again_button: Button = %try_again_button
@onready var game_over_button: Button = %game_over_button
@onready var continues_value: Label = %continues_value
@onready var see_combat_log: Button = %see_combat_log

@export var fdn:PackedScene

var combat_log_overlay: Panel = null
var is_combat_log_showing: bool = false

func _particle_minus_continue(position: Vector2, on_finished: Callable) -> void:
	var current = fdn.instantiate()
	current.position = position
	add_child(current)
	current.call_deferred("_minus_continue")
	if on_finished:
		current.finished.connect(on_finished)

func _update_continue_label() -> void:
	if GDM.player.continues == -1:
		continues_value.text = "Unlimited"
	else:
		continues_value.text = str(GDM.player.continues)

func _on_game_manager_game_lost_vs() -> void:
	GDM.tracker.reset()
	_update_continue_label()
	if GDM.player.continues == 0:
		run_away_button.disabled = true
		run_away_button.hide()
		try_again_button.disabled = true
		try_again_button.hide()
		game_over_button.disabled = false
		game_over_button.show()
	else:
		run_away_button.disabled = false
		run_away_button.show()
		try_again_button.disabled = false
		try_again_button.show()
		game_over_button.disabled = true
		game_over_button.hide()
	slide_in()

func _disable_all_buttons() -> void:
	run_away_button.disabled = true
	try_again_button.disabled = true
	game_over_button.disabled = true
	# Clean up combat log overlay if showing
	if is_combat_log_showing and is_instance_valid(combat_log_overlay):
		FW_CombatLogOverlay.hide_combat_log_overlay(combat_log_overlay)
		combat_log_overlay = null
		is_combat_log_showing = false

func _on_run_away_button_pressed() -> void:
	_disable_all_buttons()
	if GDM.player.continues != -1 and GDM.player.continues > 0:
		GDM.player.continues -= 1
		GDM.vs_save()
	_update_continue_label()
	var center = run_away_button.get_global_position() + run_away_button.size / 2
	_particle_minus_continue(center, func(): ScreenRotator.change_scene("res://Scenes/level_select2.tscn"))

func _on_try_again_button_pressed() -> void:
	_disable_all_buttons()
	if GDM.player.continues != -1 and GDM.player.continues > 0:
		GDM.player.continues -= 1
		GDM.vs_save()
	_update_continue_label()
	var center = try_again_button.get_global_position() + try_again_button.size / 2
	_particle_minus_continue(center, func(): ScreenRotator.change_scene(ScreenRotator.get_current_scene_path()))

func _on_game_over_button_pressed() -> void:
	_disable_all_buttons()

	# Upload player data and refresh cache if network is enabled
	var _net := get_node("/root/NetworkUtils")
	if _net.should_use_network():
		FW_PlayerDataManager.upload_player_data(GDM.player)
		FW_PvPCache.refresh_for_new_game()

	_archive_run_and_exit()

func _archive_run_and_exit() -> void:
	"""Archive the run and exit to main menu"""
	# actual gameover write stats to disk, and clear save then back to the title for now
	FW_RunArchiver.archive_run(GDM.monster_to_fight.name, "res://Scenes/game_menu2.tscn")

func _on_see_combat_log_pressed() -> void:
	if not is_combat_log_showing:
		combat_log_overlay = FW_CombatLogOverlay.show_combat_log_overlay(self)
		is_combat_log_showing = true
		see_combat_log.text = "Hide Combat Log"
		var close_btn = combat_log_overlay.get_node("close_btn")
		close_btn.pressed.connect(_on_close_combat_log_overlay)
	else:
		FW_CombatLogOverlay.hide_combat_log_overlay(combat_log_overlay)
		combat_log_overlay = null
		is_combat_log_showing = false
		see_combat_log.text = "See Combat Log"

func _on_close_combat_log_overlay() -> void:
	FW_CombatLogOverlay.hide_combat_log_overlay(combat_log_overlay)
	combat_log_overlay = null
	is_combat_log_showing = false
	see_combat_log.text = "See Combat Log"
