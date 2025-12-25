extends TextureButton

func _on_mouse_entered() -> void:
	self_modulate = Color.WEB_GRAY

func _on_mouse_exited() -> void:
	self_modulate = Color.WHITE
