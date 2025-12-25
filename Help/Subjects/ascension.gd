extends Control

@onready var item_list: ItemList = %ItemList

func _ready() -> void:
	var first: bool = true
	for i in FW_GameConstants.ascension_levels:
		if first:
			first = false
			item_list.add_item(i)
		else:
			item_list.add_item(i, load("res://Icons/ascension_icon.png"))

	# ensure help tokens in this subtree are processed after ready
	var help_injector = preload("res://Help/help_generic_injector.gd")
	call_deferred("_deferred_run_injector", help_injector)

func _deferred_run_injector(help_injector_script) -> void:
	help_injector_script.inject_into_node(self)
