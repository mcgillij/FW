extends "res://Scripts/base_menu_panel.gd"

signal cleanup

@onready var continues_left: Label = %continues_left
@onready var run_away: Button = %run_away
@onready var continue_button: Button = %continue_button
@onready var abandon_run_button: Button = %abandon_run_button

@export var fdn:PackedScene


func _particle_minus_continue(position: Vector2, on_finished: Callable) -> void:
	var current = fdn.instantiate()
	current._minus_continue()
	current.position = position
	add_child(current)
	if on_finished:
		current.finished.connect(on_finished)

func setup() -> void:
	if GDM.player.continues == -1:
		continues_left.text = "Unlimited"
	else:
		continues_left.text = str(GDM.player.continues)
	if GDM.player.continues == 0:
		run_away.disabled = true
		run_away.hide()
	else:
		run_away.disabled = false
		run_away.show()
		continue_button.disabled = false
		continue_button.show()

	# Ensure other buttons are enabled/shown when the pause menu opens
	continue_button.disabled = false
	continue_button.show()
	abandon_run_button.disabled = false
	abandon_run_button.show()

	# Finished configuring buttons

func _disable_all_buttons() -> void:
	run_away.disabled = true
	continue_button.disabled = true
	abandon_run_button.disabled = true


func _on_run_away_button_pressed() -> void:
	# Disable buttons immediately, then run the action deferred so the UI updates
	_disable_all_buttons()
	call_deferred("_do_run_away")

func _do_run_away() -> void:
	if GDM.player.continues != -1 and GDM.player.continues > 0:
		GDM.player.continues -= 1
		GDM.vs_save()
	setup()
	var center = run_away.get_global_position() + run_away.size / 2
	Achievements.increment_achievement_progress_by_type("run_away")
	GDM.safe_steam_increment_stat("run_away")
	GDM.tracker.reset()
	get_tree().paused = false
	emit_signal("cleanup")
	_particle_minus_continue(center, func(): ScreenRotator.change_scene("res://Scenes/level_select2.tscn"))

func _on_abandon_run_button_pressed() -> void:
	_disable_all_buttons()
	call_deferred("_do_abandon_run")

func _do_abandon_run() -> void:
	get_tree().paused = false
	FW_RunArchiver.archive_run("Abandoned Run", "res://Scenes/game_menu2.tscn")

func _on_continue_button_pressed() -> void:
	_disable_all_buttons()
	call_deferred("_do_continue")

func _do_continue() -> void:
	get_tree().paused = false
	slide_out()

func _on_bottom_ui_2_pause_game() -> void:
	setup()
	slide_in()
