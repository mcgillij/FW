extends FW_Ability

func activate_booster(grid: Node, _params) -> void:
    # Trigger visual effect
    trigger_visual_effects("on_cast", {
        "duration": 0.9
    })

    var coords := _get_target_coords()
    grid._handle_coords_booster(coords, self)

func get_preview_tiles(_grid: Node) -> Variant:
    return _get_target_coords()

func _get_target_coords() -> Array:
    return [
        Vector2(5, 3), Vector2(4, 3), Vector2(2, 3), Vector2(1, 3),
        Vector2(3, 1), Vector2(3, 2), Vector2(3, 4), Vector2(3, 5),
        Vector2(2, 2), Vector2(2, 3), Vector2(2, 4), Vector2(1, 3),
        Vector2(4, 2), Vector2(4, 4)
    ]
