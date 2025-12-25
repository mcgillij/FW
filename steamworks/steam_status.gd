extends TextureRect

func _ready() -> void:
	if Steamworks.steam_enabled:
		show()
