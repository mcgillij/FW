extends "res://Scripts/base_menu_panel.gd"

signal back_pressed

@onready var monster_list: ItemList = %monster_list
@onready var monster_container: HBoxContainer = %monster_container
@onready var bestiary_text: Label = %bestiary_text

@export var monster_prefab: PackedScene

var monster_array: Array

func _ready() -> void:
	if GDM.player.monster_kills.size() == 0:
		bestiary_text.text = "You have not vanquished any monsters yet. Come back later!"
	else:
		bestiary_text.text = "Click on a monster to see it's statistics"
	var monster_dict = FW_Utils.count_array(GDM.player.monster_kills)
	monster_array = monster_dict.keys()
	for i in monster_dict.keys():
		monster_list.add_item(i.name + " x" + str(monster_dict[i]))
	monster_list.item_selected.connect(list_trigger)

func list_trigger(index: int) -> void:
	show_monster_info(monster_array[index])

func show_monster_info(monster: FW_Monster_Resource) -> void:
	# clear the container if anythings in there first
	for c in monster_container.get_children():
		c.queue_free()
	var mob = monster_prefab.instantiate()
	monster_container.add_child(mob)
	mob.setup_monster_display(monster)

func _on_back_button_pressed() -> void:
	for c in monster_container.get_children():
		c.queue_free()
	emit_signal("back_pressed")
