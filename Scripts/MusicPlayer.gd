extends Node


func click_play_noise() -> void:
	SoundManager._play_sound(1)

# these should probably be moved to the sound manager
func play_random_noise(streak: int) -> void:
	SoundManager._play_random_sound(streak)

func _on_grid_play_sound(streak: int) -> void:
	play_random_noise(streak)

func _on_grid_play_sinker_sound() -> void:
	SoundManager._play_sinker_spawn_sound()

func _on_grid_play_bomb_sound(streak: int) -> void:
	SoundManager._play_random_explosion_sound(streak)
