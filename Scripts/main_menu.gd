extends "res://Scripts/base_menu_panel.gd"

signal play_pressed
signal play2_pressed
signal play_atiya_solitaire
signal settings_pressed
signal tutorial_pressed
signal achievement_pressed
signal master_tracker_pressed
signal announcement_button_pressed

# shader things
@onready var play_aq: TextureButton = %PlayAQ
@onready var settings_button: TextureButton = %SettingsButton
@onready var tutorial_button: TextureButton = %TutorialButton
@onready var play_button: TextureButton = %PlayAQ2
@onready var achievements_button: TextureButton = %achievements_button
@onready var title_image: TextureButton = %TitleImage
@onready var mastery_tracker_button: TextureButton = %mastery_tracker_button
@onready var announcement_button: TextureButton = %announcement_button

@export var network_prefab: PackedScene
@export var steam_status_prefab: PackedScene
@export var steam_avatar_prefab: PackedScene
@onready var discord_button: TextureButton = %discord_button
@onready var play_atiya_solitaire_button: TextureButton = %PlaySolitaire
@onready var sudoku_button: TextureButton = %sudoku_button

var show_achievements: bool = false

var title_images: Array[Texture2D] = [
	preload("res://Title_Backgrounds/pom_and_dragon.png"),
	preload("res://Title_Backgrounds/pom_castle.png"),
	preload("res://Title_Backgrounds/pom_castle2.png")
]

var title_click_times: Array[float] = []
const CLICK_WINDOW: float = 10.0
const CLICKS_NEEDED: int = 5
const SUDOKU_CLICKS_NEEDED: int = 10

func _ready() -> void:
	GDM.player = null
	Achievements._ready()
	UnlockManager._ready()
	SoundManager.wire_up_all_buttons()
	title_image.texture_normal = title_images[randi() % title_images.size()]
	show_achievements = UnlockManager.get_progress("welcome")
	if show_achievements:
		play_button.show()
		achievements_button.show()

	if UnlockManager.get_job_wins_count() > 0:
		mastery_tracker_button.show()

	if UnlockManager.is_solitaire_unlocked():
		play_atiya_solitaire_button.show()

	if UnlockManager.is_sudoku_unlocked():
		sudoku_button.show()

	if NetworkUtils.network_enabled:
		var network_widget = network_prefab.instantiate()
		add_child(network_widget)
		network_widget.position = Vector2(640,1200)
		# Check server availability and toggle announcements button accordingly (deferred check)
		NetworkUtils.is_server_up(self, Callable(self, "_on_network_status_checked"))
	if Steamworks.steam_enabled:
		var steam_widget = steam_status_prefab.instantiate()
		add_child(steam_widget)
		steam_widget.position = Vector2(600,1200)
		var steam_avatar_widget = steam_avatar_prefab.instantiate()
		add_child(steam_avatar_widget)
		steam_avatar_widget.position = Vector2(620,1100)
		Steamworks.set_avatar_widget(steam_avatar_widget)

func _on_settings_button_pressed() -> void:
	emit_signal("settings_pressed")

func _on_tutorial_button_pressed() -> void:
	emit_signal("tutorial_pressed")

func _on_play_aq_2_pressed() -> void:
	emit_signal("play2_pressed")

func _on_play_aq_pressed() -> void:
	emit_signal("play_pressed")

func _on_quit_button_pressed() -> void:
	ConfigManager.save_current_window_size()
	ConfigManager.save_current_window_position()
	get_tree().quit()

func _on_achievements_button_pressed() -> void:
	emit_signal("achievement_pressed")

func _on_achievements_button_mouse_entered() -> void:
	achievements_button.self_modulate = Color.YELLOW

func _on_achievements_button_mouse_exited() -> void:
	achievements_button.self_modulate = Color.WHITE

func _on_mastery_tracker_button_mouse_entered() -> void:
	mastery_tracker_button.self_modulate = Color.YELLOW

func _on_mastery_tracker_button_mouse_exited() -> void:
	mastery_tracker_button.self_modulate = Color.WHITE

func _on_annoucement_button_mouse_entered() -> void:
	announcement_button.self_modulate = Color.YELLOW

func _on_annoucement_button_mouse_exited() -> void:
	announcement_button.self_modulate = Color.WHITE

func _on_mastery_tracker_button_pressed() -> void:
	emit_signal("master_tracker_pressed")


func _on_texture_button_pressed() -> void:
	OS.shell_open("https://discord.gg/cv6jYeKycu")

func _on_texture_button_mouse_entered() -> void:
	discord_button.modulate = Color(1,1,1,.5)

func _on_texture_button_mouse_exited() -> void:
	discord_button.modulate = Color(1,1,1,1)


func _on_network_status_checked(is_up: bool) -> void:
	# Show announcement button only when the server is reachable and network is enabled
	if is_up and NetworkUtils.network_enabled:
		announcement_button.show()
	else:
		announcement_button.hide()


func _on_title_image_pressed() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	title_click_times.append(now)
	# Remove old clicks
	while title_click_times.size() > 0 and now - title_click_times[0] > CLICK_WINDOW:
		title_click_times.remove_at(0)
	if title_click_times.size() >= CLICKS_NEEDED and not UnlockManager.is_solitaire_unlocked():
		UnlockManager.unlock_solitaire()
		play_atiya_solitaire_button.show()
		# Tween
		var tween = create_tween()
		tween.tween_property(play_atiya_solitaire_button, "scale", Vector2(1.2, 1.2), 0.2)
		tween.tween_property(play_atiya_solitaire_button, "scale", Vector2(1, 1), 0.2)
		# Sound
		SoundManager._play_random_positive_sound()

	if title_click_times.size() >= SUDOKU_CLICKS_NEEDED and not UnlockManager.is_sudoku_unlocked():
		UnlockManager.unlock_sudoku()
		sudoku_button.show()
		var sudoku_tween = create_tween()
		sudoku_tween.tween_property(sudoku_button, "scale", Vector2(1.2, 1.2), 0.2)
		sudoku_tween.tween_property(sudoku_button, "scale", Vector2(1, 1), 0.2)
		SoundManager._play_random_positive_sound()


func _on_play_solitaire_pressed() -> void:
	emit_signal("play_atiya_solitaire")


func _on_announcement_button_pressed() -> void:
	emit_signal("announcement_button_pressed")


func _on_sudoku_button_pressed() -> void:
	GDM.game_mode = GDM.game_types.sudoku
	ScreenRotator.change_scene("res://Sudoku/Sudoku.tscn")
