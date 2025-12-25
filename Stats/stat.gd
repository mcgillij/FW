extends Resource

class_name FW_Stat

enum STAT_TYPE { INT, FLOAT }

@export var stat_name: String
@export var stat_image: Texture2D
@export var int_or_float: STAT_TYPE
@export_multiline var description: String
