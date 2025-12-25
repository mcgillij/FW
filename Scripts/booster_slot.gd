extends VBoxContainer
class_name FW_BoosterSlot

@onready var booster_button: TextureButton = %booster_button
@onready var cooldown_label: Label = %cooldown
@onready var mana_cost_container: HBoxContainer = %mana_cost_container
@onready var damage_label: Label = %damage_label
@onready var emoji_indicator: Label = %emoji_indicator

var mana_panels: Dictionary = {}
var mana_labels: Dictionary = {}

func _ready() -> void:
	mana_panels = {
		"blue": %blue_panel,
		"red": %red_panel,
		"green": %green_panel,
		"orange": %orange_panel,
		"pink": %pink_panel
	}
	mana_labels = {
		"blue": %blue_label,
		"red": %red_label,
		"green": %green_label,
		"orange": %orange_label,
		"pink": %pink_label
	}
	reset_visuals()

func reset_visuals() -> void:
	cooldown_label.visible = false
	damage_label.visible = false
	damage_label.modulate.a = 0.0
	emoji_indicator.visible = false
	emoji_indicator.modulate.a = 0.0
	for color in mana_panels.keys():
		var panel: Panel = mana_panels[color]
		panel.visible = false
		panel.modulate.a = 1.0

func get_button() -> TextureButton:
	return booster_button

func get_cooldown_label() -> Label:
	return cooldown_label

func get_damage_label() -> Label:
	return damage_label

func get_emoji_indicator() -> Label:
	return emoji_indicator

func update_mana_cost(ability: FW_Ability, can_see: bool = true) -> void:
	for color in mana_panels.keys():
		var panel: Panel = mana_panels[color]
		var label: Label = mana_labels[color]
		if ability and ability.cost.has(color):
			label.text = str(ability.cost[color])
			panel.visible = true
			panel.modulate.a = 1.0 if can_see else 0.5
		else:
			panel.visible = false

func clear_mana_cost() -> void:
	for color in mana_panels.keys():
		mana_panels[color].visible = false
