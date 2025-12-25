extends Node2D

@onready var buff_bar: HBoxContainer = %buff_bar

var buff_prefab: PackedScene = load("res://Scenes/BuffIcon_prefab.tscn")
@export var owner_type: String = "player" # "player" or "monster"
var owner_buffs: FW_BuffManager

func _ready() -> void:
	if owner_type == "player":
		buff_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
		EventBus.player_add_buff.connect(_add_buff)
		EventBus.player_remove_buff.connect(_remove_buff)
		EventBus.player_update_buff_bar.connect(_update_buff_icons)
	elif owner_type == "monster":
		buff_bar.alignment = BoxContainer.ALIGNMENT_END
		EventBus.monster_add_buff.connect(_add_buff)
		EventBus.monster_remove_buff.connect(_remove_buff)
		EventBus.monster_update_buff_bar.connect(_update_buff_icons)

func _add_buff(buff: FW_Buff) -> void:
	var buf = buff_prefab.instantiate()
	buff_bar.add_child(buf)
	buf.set_values(buff.texture, buff.duration, buff.get_instance_id(), buff)

func _remove_buff(buff: FW_Buff):
	for j in buff_bar.get_children():
		if j.buff_id == buff.get_instance_id():
			j.queue_free()
			return

func _update_buff_icons() -> void:
	for i in owner_buffs.active_buffs.keys():
		for j in buff_bar.get_children():
			if j.buff_id == i:
				j.buff_duration.text = str(owner_buffs.active_buffs[i].duration_left)
