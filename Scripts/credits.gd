extends CanvasLayer

@onready var text_list: Array = [
	%thanks_label, %part1, %mcgillij_label, %godot_label, %music_label, %Back
]
var is_out: bool = false
var current_index: int = 0

func slide_in() -> void:
	$AnimationPlayer.play("slide_in")

func slide_out() -> void:
	$AnimationPlayer.play_backwards("slide_in")

func _on_back_pressed() -> void:
	slide_out()
	ScreenRotator.change_scene("res://Scenes/level_select.tscn")

func _on_timer_timeout() -> void:
	if is_out:
		# show first text
		if current_index < text_list.size():
			var text_item = text_list[current_index] #.visible = true
			text_item.visible = true
			var tween = create_tween()
			var duration = 5
			tween.tween_property(text_item, "modulate", Color(1,1,1,1), duration).from(Color(1,1,1,0)
		 ).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.play()
			current_index += 1
		if current_index < text_list.size():
			$Timer.start()

func _on_story_trigger_credits() -> void:
	is_out = !is_out
	$Timer.start()
	slide_in()
