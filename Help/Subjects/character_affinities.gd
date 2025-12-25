extends Control

@onready var desc: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/Description
@onready var desc_bottom: RichTextLabel = $VBoxContainer/Panel/MarginContainer/HBoxContainer/VBoxContainer/desc
@export var character_prefab: PackedScene
@onready var demo_container: HBoxContainer = %demo_container
@onready var warning_label: RichTextLabel = %warning_label

var atiya = preload("res://Characters/Atiya.tres")
var bonk = preload("res://Characters/Bonk.tres")
var rosie = preload("res://Characters/Rosie.tres")
var boomer = preload("res://Characters/Boomer.tres")

func _ready() -> void:
	for c in [atiya, bonk, rosie, boomer]:
		var prefab = character_prefab.instantiate()
		demo_container.add_child(prefab)
		prefab.set_combatant_values_for_help(c)
	var registry = preload("res://Help/help_style_registry.gd")

	for lbl in [desc, desc_bottom]:
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
