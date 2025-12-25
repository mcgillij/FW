extends "res://Scripts/base_menu_panel.gd"

class_name FW_SettingsScreen

signal back_button_pressed
@onready var version_label: Label = %version_label
@onready var music_slider: HSlider = %MusicSlider
@onready var sound_slider: HSlider = %SoundSlider

@onready var confirmation_screen: CanvasLayer = %confirmation_screen

var music_on_texture: Texture = preload("res://Buttons/Music_On_Button.png")
var music_on_focused: Texture = preload("res://Buttons/Music_On_Button_focused.png")
var music_off_texture: Texture = preload("res://Buttons/Music_Off_Button.png")
var music_off_focused: Texture = preload("res://Buttons/Music_Off_Button_focused.png")

var sound_on_texture: Texture = preload("res://Buttons/Sound On Button.png")
var sound_on_focused: Texture = preload("res://Buttons/Sound On Button_focused.png")
var sound_off_texture: Texture = preload("res://Buttons/Sound Off Button.png")
var sound_off_focused: Texture = preload("res://Buttons/Sound Off Button_focused.png")

var animated_bg_on_texture: Texture = preload("res://Buttons/AnimatedBGOn.png")
var animated_bg_off_texture: Texture = preload("res://Buttons/AnimatedBGOff.png")

func _ready() -> void:
	change_button_texture()
	version_label.text = "Version: " + FW_Utils.get_version_info() + "\n"
	version_label.text += "OS: " + OS.get_name() + "\n" # 2
	version_label.text += "Distro: " + OS.get_distribution_name() + "\n" # 3
	version_label.text += "CPU: " + OS.get_processor_name() + "\n" # 4
	version_label.text += "GPU: " + RenderingServer.get_rendering_device().get_device_name() + "\n" # 5

	music_slider.value = ConfigManager.music_volume
	sound_slider.value = ConfigManager.sound_volume

func change_button_texture() -> void:
	if ConfigManager.sound_on:
		%SoundButton.texture_normal = sound_on_texture
		%SoundButton.texture_focused = sound_on_focused
		sound_slider.editable = true
	else:
		%SoundButton.texture_normal = sound_off_texture
		%SoundButton.texture_focused = sound_off_focused
		sound_slider.editable = false

	if ConfigManager.music_on:
		%MusicButton.texture_normal = music_on_texture
		%MusicButton.texture_focused = music_on_focused
		music_slider.editable = true
	else:
		%MusicButton.texture_normal = music_off_texture
		%MusicButton.texture_focused = music_off_focused
		music_slider.editable = false

	if ConfigManager.animated_bg:
		%AnimatedBG.texture_normal = animated_bg_on_texture
	else:
		%AnimatedBG.texture_normal = animated_bg_off_texture

func _on_sound_button_pressed() -> void:
	ConfigManager.sound_on = !ConfigManager.sound_on
	change_button_texture()
	ConfigManager.save_config()
	SoundManager.set_sound_volume()
	SoundManager._play_sound(5)

func _on_back_button_pressed() -> void:
	SoundManager._play_sound(5)
	emit_signal("back_button_pressed")

func _on_music_button_pressed() -> void:
	ConfigManager.music_on = !ConfigManager.music_on
	change_button_texture()
	ConfigManager.save_config()
	SoundManager.set_music_volume()
	SoundManager._play_sound(5)

func _on_clear_save_data_pressed() -> void:
	confirmation_screen.slide_in()

func _on_animated_bg_pressed() -> void:
	ConfigManager.animated_bg = !ConfigManager.animated_bg
	change_button_texture()
	ConfigManager.save_config()
	SoundManager._play_sound(5)

func _on_rotate_button_pressed() -> void:
	ScreenRotator.toggle_rotation()

func _on_music_slider_value_changed(value: float) -> void:
	ConfigManager.music_volume = value
	SoundManager.set_music_volume()
	ConfigManager.save_config()

func _on_sound_slider_value_changed(value: float) -> void:
	ConfigManager.sound_volume = value
	SoundManager.set_sound_volume()
	ConfigManager.save_config()
