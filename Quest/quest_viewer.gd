extends "res://Scripts/base_menu_panel.gd"

signal back_button

@export var quest_prefab: PackedScene

@onready var quest_list: VBoxContainer = %quest_list

func setup() -> void:
	for c in quest_list.get_children():
		c.queue_free()
	var active_quests = QuestManager.get_active_quests()
	if active_quests.is_empty():
		var placeholder_panel = Panel.new()
		placeholder_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		placeholder_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		placeholder_panel.custom_minimum_size = Vector2(300, 100)
		placeholder_panel.set("theme_override_styles/panel", load("res://Styles/inventory_panel_style.tres"))
		var margin_container = MarginContainer.new()
		margin_container.set("theme_override_constants/margin_left", 4)
		margin_container.set("theme_override_constants/margin_right", 4)
		margin_container.set("theme_override_constants/margin_top", 4)
		margin_container.set("theme_override_constants/margin_bottom", 4)
		margin_container.set("anchors_preset", Control.PRESET_FULL_RECT)
		var vbox = VBoxContainer.new()
		vbox.alignment = VBoxContainer.ALIGNMENT_CENTER
		var label = Label.new()
		label.text = "You don't have any quests yet."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder_panel.add_child(margin_container)
		margin_container.add_child(vbox)
		vbox.add_child(label)
		quest_list.add_child(placeholder_panel)
	else:
		for q in active_quests:
			var quest = quest_prefab.instantiate()
			quest_list.add_child(quest)
			quest.setup(q)
			q.check_if_complete()

func _on_back_button_pressed() -> void:
	GDM.vs_save()
	emit_signal("back_button")
