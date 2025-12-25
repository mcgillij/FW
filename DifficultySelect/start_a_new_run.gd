extends Panel

signal start_new_run

@onready var start_new_run_button: Button = %start_new_run_button

func _ready() -> void:
	start_new_run_button.connect("mouse_entered", _on_mouse_entered)
	start_new_run_button.connect("mouse_exited", _on_mouse_exited)

func _on_mouse_entered() -> void:
	self_modulate = Color.GREEN # Example: light yellow highlight

func _on_mouse_exited() -> void:
	self_modulate = Color(1, 1, 1) # Reset to default

func _on_start_new_run_button_pressed() -> void:
	emit_signal("start_new_run")
