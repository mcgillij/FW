extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
    # Shield granting is driven by the FW_Ability.effects dictionary and handled
    # centrally by CombatManager. Keep this method minimal so abilities are
    # configurable from their resource files.
    # If any bespoke visual or VFX behavior is needed it can be placed here.
    # No direct calls to GDM.effect_manager.add_shields or EventBus emission.
    var params = {}
    if _params and typeof(_params) == TYPE_DICTIONARY and _params.has("origin_position"):
        params["origin_position"] = _params["origin_position"]
    else:
        params["origin_position"] = Vector2(0.5, 0.5)

    trigger_visual_effects("on_cast", params)
