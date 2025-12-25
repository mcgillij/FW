extends Control

@onready var desc: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/Description
@onready var red_desc: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer2/red_affinity_desc
@onready var green_desc: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer3/green_affinity_desc
@onready var blue_desc: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer4/blue_affinity_desc
@onready var orange_desc: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer5/orange_affinity_desc
@onready var pink_desc: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer6/pink_affinity_desc
@onready var desc_bottom: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/desc

func _ready() -> void:
	var registry = preload("res://Help/help_style_registry.gd")

	for lbl in [red_desc, green_desc, blue_desc, orange_desc, pink_desc, desc_bottom]:
		if not lbl:
			continue
		var text: String = ""
		if lbl.text != "":
			text = String(lbl.text)
		else:
			text = String(lbl.bbcode_text)
		var found = registry.find_tokens_in_text(text)
		if found.size() == 0:
			continue
		var mapping = {}
		for t in found:
			mapping[t] = registry.lookup_resolved(t)
		FW_Colors.inject_into_label(lbl, mapping)
