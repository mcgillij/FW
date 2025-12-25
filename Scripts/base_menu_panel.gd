extends CanvasLayer

signal slide_in_started
signal slide_in_finished
signal slide_out_started
signal slide_out_finished

@export var entry_layer: int = -1
@export var exit_layer: int = -1

func slide_in() -> void:
	emit_signal("slide_in_started")
	# Only change CanvasLayer.layer if an entry_layer was configured
	if entry_layer >= 0:
		layer = entry_layer
	$AnimationPlayer.play("slide_in")
	await $AnimationPlayer.animation_finished
	emit_signal("slide_in_finished")
	enable_buttons()

func slide_out() -> void:
	disable_buttons()
	emit_signal("slide_out_started")
	# Only change CanvasLayer.layer if an exit_layer was configured
	if exit_layer >= 0:
		layer = exit_layer
	$AnimationPlayer.play_backwards("slide_in")
	await $AnimationPlayer.animation_finished
	emit_signal("slide_out_finished")

func disable_buttons() -> void:
	for child in get_all_children():
		if child is Button:
			child.disabled = true

func enable_buttons() -> void:
	for child in get_all_children():
		if child is Button:
			child.disabled = false

func get_all_children(node: Node = self) -> Array:
	var children = []
	for child in node.get_children():
		children.append(child)
		children.append_array(get_all_children(child))
	return children
