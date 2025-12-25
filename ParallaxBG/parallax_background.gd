extends ParallaxBackground

@onready var parallax_background: ParallaxBackground = $"."

@export var speed: int = 100
@export var rotation_speed: float = 0.2

var direction = Vector2(1, 1)

func _process(delta: float) -> void:
    parallax_background.scroll_offset += direction * speed * delta
    direction = direction.rotated(rotation_speed * delta)
