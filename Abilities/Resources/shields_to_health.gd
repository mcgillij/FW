extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
    # Trigger visual effect
    trigger_visual_effects("on_cast", {
        "duration": 1.1
    })
    
    # TODO: Implement actual ability logic (convert shields to health)
    #var color = "green"
    #grid._handle_color_booster(color, self)
    pass
