extends Control

@onready var desc: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/Description
@onready var desc2: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/Description2

func _ready() -> void:
	var registry = preload("res://Help/help_style_registry.gd")

	for lbl in [desc, desc2]:
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
