extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
    # Default power scaling: accept _params.power or fallback to 1.0
    var power = 1.0
    if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("power"):
        power = float(_params["power"])

    # Trigger dramatic Brutal Strike VFX. Scale intensity by power.
    var params = {}
    if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
        params["origin_position"] = _params["origin_position"]
    else:
        params["origin_position"] = Vector2(0.5, 0.5)
    # pass a runtime intensity multiplier to the manager which will set shader uniforms
    params["intensity"] = 1.0 + clamp(power - 1.0, 0.0, 3.0)

    trigger_visual_effects("on_cast", params)
