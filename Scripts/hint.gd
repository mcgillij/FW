extends Node2D

@onready var this_sprite = $Sprite2D

func wiggle() -> void:
    var tween = create_tween()
    var shake = 5
    var shake_duration = 0.1
    var shake_count = 10
    for i in shake_count:
        tween.tween_property(this_sprite, "position", Vector2(floor(randf_range(-shake, shake)), floor(randf_range(-shake, shake))), shake_duration)
    tween.play()

func setup(sprite: Texture2D) -> void:
    this_sprite.texture = sprite


func _ready() -> void:
    $Timer.start()

func _on_timer_timeout() -> void:
    wiggle()
