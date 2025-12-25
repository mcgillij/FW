extends FW_Ability

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, _params) -> void:
    # Trigger visual effect
    trigger_visual_effects("on_cast", {
        "duration": 1.0
    })
    
    var _shatter_resource: Resource = load("res://Buffs/Shatter.tres")