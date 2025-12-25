extends CanvasLayer

var achievement_queue: Array = []
var is_animating: bool = false

func _ready() -> void:
	if EventBus and EventBus.has_signal("achievement_trigger"):
		EventBus.achievement_trigger.connect(_queue_slide_in)

func _queue_slide_in(achievement: Dictionary) -> void:
	achievement_queue.append(achievement)
	if not is_animating:
		_process_queue()

func _process_queue() -> void:
	if achievement_queue.size() > 0:
		var next_achievement = achievement_queue.pop_front()
		_do_slide_in(next_achievement)
	else:
		is_animating = false

func _do_slide_in(achievement: Dictionary) -> void:
	is_animating = true
	$AchievementPrefab.setup(achievement)
	$AnimationPlayer.play("slide_in")
	$Timer.start()

func _on_timer_timeout() -> void:
	$AnimationPlayer.play_backwards("slide_in")
	# Wait for the backwards animation to finish before processing next
	$AnimationPlayer.connect("animation_finished", Callable(self, "_on_slide_out_finished"), CONNECT_ONE_SHOT)

func _on_slide_out_finished(anim_name: String) -> void:
	if anim_name == "slide_in":
		_process_queue()
