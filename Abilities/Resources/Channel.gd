extends FW_Ability

func activate_booster(_grid: Node, _params) -> void:
    # Activation (silent in normal runs)

    # Trigger any configured visual effects (on_cast)
    # Ensure we only pass a Dictionary to trigger_visual_effects to avoid runtime errors
    var extra = {}
    if _params and typeof(_params) == TYPE_DICTIONARY:
        extra = _params
    trigger_visual_effects("on_cast", extra)

    # Visual effects are handled via `visual_effects` (trigger_visual_effects) defined on the resource
    # and by EffectResource when invoked in combat. No explicit EventBus.emit here to avoid duplicates.

    var target_color = ""
    # Prefer explicit config in effects or params
    if effects.has("channel"):
        target_color = str(effects["channel"])
    elif _params.has("target_color"):
        target_color = str(_params["target_color"])

    # Determine whose turn it is
    var is_player = GDM.game_manager.turn_manager.is_player_turn()

    # Safety: require a target color
    var attacker_name = GDM.player.character.name if is_player else GDM.monster_to_fight.name
    if target_color == "":
        push_warning("Channel.activate_booster: no target color specified")
        # Still emit a generic log so the ability use isn't silent
        EventBus.publish_combat_log.emit(get_formatted_log_message({"attacker": attacker_name}))
        return

    # Access the correct mana dictionary
    var mana_obj = GDM.game_manager.mana
    var pool = mana_obj.player if is_player else mana_obj.enemy

    # Collect conversions: take half of each non-target color and add to target
    var to_add := 0
    var colors = ["red", "blue", "green", "orange", "pink"]
    for c in colors:
        if c == target_color:
            continue
        var v = int(pool.get(c, 0))
        if v <= 0:
            continue
        var conv = int(floor(v * 0.5))
        to_add += conv
        pool[c] = 0

    # Apply the converted mana to the target via CombatManager helpers (which emit update events)
    var gain_dict = {target_color: to_add}
    if is_player:
        CombatManager.apply_mana_gain_to_player(gain_dict)
    else:
        CombatManager.apply_mana_gain_to_monster(gain_dict)

    # Emit a combat log message
    EventBus.publish_combat_log.emit(get_formatted_log_message({"attacker": attacker_name}))
