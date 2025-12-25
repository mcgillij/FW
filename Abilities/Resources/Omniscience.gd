extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
    # Damage and drain logic handled elsewhere; trigger the capstone visual effect
    trigger_visual_effects("on_cast")
