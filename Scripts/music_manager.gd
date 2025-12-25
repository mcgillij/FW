extends AudioStreamPlayer

var possible_music: Array[Resource] = [
	preload("res://Music/theme-1.ogg"),
	preload("res://Music/theme-2.ogg"),
	preload("res://Music/theme-3.ogg"),
	preload("res://Music/theme-4.ogg"),
	preload("res://Music/01. Slay The Evil.mp3"),
	preload("res://Music/02. Perilous Dungeon.mp3"),
	preload("res://Music/03. Boss Battle.mp3"),
	preload("res://Music/04. Mechanical Complex.mp3"),
	preload("res://Music/05. Last Mission.mp3"),
	preload("res://Music/06. Unknown Planet.mp3"),
	preload("res://Music/07. MonsterVania #1.mp3"),
	preload("res://Music/08. Space Adventure.mp3"),
	preload("res://Music/09. Crisis.mp3"),
	preload("res://Music/11. Jester Battle.mp3"),
	preload("res://Music/12. Strong Boss.mp3"),
	preload("res://Music/14. MonsterVania #2.mp3"),
	preload("res://Music/15. Rush FW_Point.mp3"),
	preload("res://Music/16. Truth.mp3"),
	preload("res://Music/18. Infinite Darkness.mp3"),
	preload("res://Music/DKBD/01 - DavidKBD - Belmont Chronicles Pack - Belmont Chronicles.ogg"),
	preload("res://Music/DKBD/02 - DavidKBD - Belmont Chronicles Pack - The Mystic Forest.ogg"),
	preload("res://Music/DKBD/03 - DavidKBD - Belmont Chronicles Pack - Caverns.ogg"),
	preload("res://Music/DKBD/04 - DavidKBD - Belmont Chronicles Pack - Awakening After the War.ogg"),
	preload("res://Music/DKBD/05 - DavidKBD - Belmont Chronicles Pack - Abandoned Church.ogg"),
	preload("res://Music/DKBD/06 - DavidKBD - Belmont Chronicles Pack - Cathedral.ogg"),
	preload("res://Music/DKBD/07 - DavidKBD - Belmont Chronicles Pack - Boss.ogg"),
	preload("res://Music/DKBD/08 - DavidKBD - Belmont Chronicles Pack - The Dungeons.ogg"),
	preload("res://Music/DKBD/09 - DavidKBD - Belmont Chronicles Pack - The Catacombs.ogg"),
	preload("res://Music/DKBD/10 - DavidKBD - Belmont Chronicles Pack - Final Boss.ogg"),
	preload("res://Music/DKBD/11 - DavidKBD - Belmont Chronicles Pack - Credits Theme.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 01 - Pink Bloom.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 02 - Portal to Underworld.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 03 - To the Unknown.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 04 - Valley of Spirits.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 05 - Western Cyberhorse.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 06 - Diamonds on The Ceiling.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 07 - The Hidden One.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 08 - Lost Spaceship's Signal.ogg"),
	preload("res://Music/DKBD/DavidKBD - Pink Bloom Pack - 09 - Lightyear City.ogg")
	]

func _play_music() -> void:
	if stream:
		return
	stream = possible_music[randi() % possible_music.size()]
	play()

func _on_finished() -> void:
	stream = possible_music[randi() % possible_music.size()]
	play()
