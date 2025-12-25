extends Node

@export var enabled := true
@export var auto_resume := true

var _managed_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
	if !enabled:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_focus_lost()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_focus_gained()

func _focus_lost() -> void:
	if _managed_pause or get_tree() == null:
		return
	if get_tree().paused:
		return
	get_tree().paused = true
	_managed_pause = true

func _focus_gained() -> void:
	if !_managed_pause or get_tree() == null:
		return
	_managed_pause = false
	if auto_resume:
		get_tree().paused = false
