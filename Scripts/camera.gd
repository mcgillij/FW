extends Camera2D
""" camera zoom is set to 1.25 but should really be set to 1 normally"""
var default_zoom: Vector2 = Vector2(1.25, 1.25)
var default_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
    zoom = default_zoom
    default_offset = offset

func move_camera(loc: Vector2) -> void:
    offset = loc
    default_offset = loc # update default_offset when camera is moved

func camera_effect() -> void:
    var tween = get_tree().create_tween()
    tween.tween_property(self, "zoom", default_zoom, 0.2).from(Vector2(.9,.9)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
    tween.tween_callback(
        func(): reset_camera()
    ).set_delay(0.2)
    tween.play()

func _on_grid_place_camera(loc: Vector2) -> void:
    move_camera(loc)

func _on_grid_camera_effect() -> void:
    camera_effect()

func screenshake(intensity: float = 10.0, duration: float = 0.3) -> void:
    var original_offset = offset
    var tween = get_tree().create_tween()
    for i in range(int(duration / 0.03)):
        var shake = Vector2(
            randf_range(-intensity, intensity),
            randf_range(-intensity, intensity)
        )
        tween.tween_callback(
            func(): offset = original_offset + shake
        ).set_delay(i * 0.03)
    tween.tween_callback(
        func(): reset_camera()
    ).set_delay(duration)

func _on_top_ui_2_screen_shake() -> void:
    screenshake()

func _on_top_ui_screen_shake() -> void:
    screenshake()

func reset_camera() -> void:
    zoom = default_zoom
    offset = default_offset
