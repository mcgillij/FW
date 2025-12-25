extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
    # Trigger visual effect
    trigger_visual_effects("on_cast", {
        "duration": 0.8
    })

    var coords := _get_target_coords()
    grid._handle_coords_booster(coords, self)

func get_preview_tiles(_grid: Node) -> Variant:
    return _get_target_coords()

func _get_target_coords() -> Array:
    return [
        Vector2(3, 3),
        Vector2(2, 2), Vector2(2, 4), Vector2(4, 2), Vector2(4, 4),
        Vector2(1, 1), Vector2(1, 5), Vector2(5, 1), Vector2(5, 5),
        Vector2(0, 0), Vector2(0, 6), Vector2(6, 0), Vector2(6, 6)
    ]
