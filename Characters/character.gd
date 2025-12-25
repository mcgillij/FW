@icon('res://addons/dialogue_nodes/icons/FW_Character.svg')
extends Resource

class_name FW_Character
# character information
@export var texture: Texture2D
@export var name: String
@export_multiline var description: String
@export var affinities: Array[FW_Ability.ABILITY_TYPES]
@export var effects: Dictionary

# these vars are needed to work as a Character class with the dialog module
# the Dialog addon needs to be modified to ditch it's original Character class
# since I wanted to use my own
@export var image : Texture2D # used for character icon in dialog panel
@export var color : Color = Color.WHITE # color of the text in the dialog panel

func _to_string() -> String:
    return "[Character: %s]" % name
