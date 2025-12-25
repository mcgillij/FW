extends Panel

class_name FW_ManaDisplayPrefab

@onready var red_mana_used: Label = %red_mana_used
@onready var red_mana_gained: Label = %red_mana_gained
@onready var green_mana_used: Label = %green_mana_used
@onready var green_mana_gained: Label = %green_mana_gained
@onready var blue_mana_used: Label = %blue_mana_used
@onready var blue_mana_gained: Label = %blue_mana_gained
@onready var orange_mana_used: Label = %orange_mana_used
@onready var orange_mana_gained: Label = %orange_mana_gained
@onready var pink_mana_used: Label = %pink_mana_used
@onready var pink_mana_gained: Label = %pink_mana_gained

func set_used_mana(mana_dict: Dictionary) -> void:
    for color in mana_dict.keys():
        match color:
            "red":
                red_mana_used.text = str(mana_dict[color])
            "green":
                green_mana_used.text = str(mana_dict[color])
            "blue":
                blue_mana_used.text = str(mana_dict[color])
            "orange":
                orange_mana_used.text = str(mana_dict[color])
            "pink":
                pink_mana_used.text = str(mana_dict[color])

func set_gained_mana(mana_dict: Dictionary) -> void:
    for color in mana_dict.keys():
        match color:
            "red":
                red_mana_gained.text = str(mana_dict[color])
            "green":
                green_mana_gained.text = str(mana_dict[color])
            "blue":
                blue_mana_gained.text = str(mana_dict[color])
            "orange":
                orange_mana_gained.text = str(mana_dict[color])
            "pink":
                pink_mana_gained.text = str(mana_dict[color])
