extends TextureButton

var data: FW_EnvironmentalEffect

func setup(d: FW_EnvironmentalEffect) -> void:
	data = d

func _ready() -> void:
	texture_normal = data.texture

func _on_pressed() -> void:
	EventBus.environment_clicked.emit(data)
