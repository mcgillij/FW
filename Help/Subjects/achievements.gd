extends Control

@onready var achievement_list: VBoxContainer = %achievement_list
@export var achievement_prefab: PackedScene

var achievements = []

func _ready() -> void:
	# Ensure help-style token injection runs for this subtree so tokens like
	# "Achievements" are colorized according to `help_style_registry.gd`.
	# Run the new static injector API (no instance required)
	var help_injector = preload("res://Help/help_generic_injector.gd")
	# run deferred to avoid conflicts if other code mutates labels in _ready
	call_deferred("_deferred_run_injector", help_injector)

	# injector will run deferred via _deferred_run_injector defined at file scope
	var show_num: int = 2
	var keys = Array(Achievements.achievements_keys)
	keys.shuffle()
	for i in range(min(show_num, keys.size())):
		var a = achievement_prefab.instantiate()
		%achievement_list.add_child(a)
		a.setup(Achievements.get_achievement(keys[i]))

func _deferred_run_injector(help_injector_script) -> void:
	# Deferred helper executed after _ready of all children
	help_injector_script.inject_into_node(self)
