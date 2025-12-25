extends TextureButton

@onready var buff_duration = $buff_duration

var buff_id: int
var buff_ref: FW_Buff = null
var owner_type: String = ""

func set_values(image: Texture2D, duration: int, id: int, buff: FW_Buff = null) -> void:
	if !buff_duration:
		buff_duration = $buff_duration

	texture_normal = image
	buff_duration.text = str(duration)
	buff_id = id
	buff_ref = buff
	if buff:
		owner_type = buff.owner_type


func _on_pressed() -> void:
	if buff_ref:
		if owner_type == "monster":
			EventBus.monster_buff_clicked.emit(buff_ref)
		else:
			EventBus.player_buff_clicked.emit(buff_ref)
