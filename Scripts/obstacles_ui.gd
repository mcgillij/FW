extends TextureRect

signal pause_game
signal level_edit_concrete
signal level_edit_heavy_concrete
signal level_edit_ice
signal level_edit_lock
signal level_edit_slime
signal level_edit_pink_slime

func _on_pause_pressed() -> void:
    emit_signal("pause_game")
    get_tree().paused = true

func _on_concrete_button_pressed() -> void:
    emit_signal("level_edit_concrete")

func _on_heavy_concrete_button_pressed() -> void:
    emit_signal("level_edit_heavy_concrete")

func _on_ice_button_pressed() -> void:
    emit_signal("level_edit_ice")

func _on_lock_button_pressed() -> void:
    emit_signal("level_edit_lock")

func _on_slime_button_pressed() -> void:
    emit_signal("level_edit_slime")

func _on_pink_slime_button_pressed() -> void:
    emit_signal("level_edit_pink_slime")
