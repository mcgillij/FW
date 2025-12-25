extends Control

class_name FW_DamageDisplayPrefab

@onready var damage_done_value: Label = %damage_done_value
@onready var damage_done_bypass_value: Label = %damage_done_bypass_value
@onready var damage_done_to_shield_value: Label = %damage_done_to_shield_value
@onready var damage_taken_value: Label = %damage_taken_value
@onready var damage_taken_shields_value: Label = %damage_taken_shields_value
@onready var max_combo_value: Label = %max_combo_value
@onready var highest_damage_value: Label = %highest_damage_value

func _ready() -> void:
    damage_taken_value.text = str(GDM.tracker.damage_taken)
    damage_taken_shields_value.text = str(GDM.tracker.damage_taken_blocked)
    damage_done_value.text = str(GDM.tracker.damage_done)
    damage_done_bypass_value.text = str(GDM.tracker.damage_done_bypassed_sheilds)
    damage_done_to_shield_value.text = str(GDM.tracker.damage_done_blocked_by_sheilds)
    max_combo_value.text = "x" + str(GDM.tracker.max_combo) if GDM.tracker.max_combo > 0 else str(0)
    highest_damage_value.text = str(GDM.tracker.highest_damage_hit)
