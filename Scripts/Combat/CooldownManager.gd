class_name FW_CooldownManager
extends Node

# Dictionary to store abilities and their cooldowns
var abilities = {} # (owner_id, ability.name): cooldown
const COOLDOWN_MAX := 100

func add_ability(owner_id: String, ability: FW_Ability) -> void:
    var effects = GDM.effect_manager.get_modifier_effects()
    if ability.initial_cooldown > 0:
        var reduced_cd = ability.initial_cooldown - effects["cooldown_reduction"]
        var cd = clampi(reduced_cd, 1, COOLDOWN_MAX) # Minimum cooldown is 1
        abilities[[owner_id, ability.name]] = cd

func decrement_cooldowns() -> void:
    var keys_to_remove = []
    for key in abilities.keys():
        if abilities[key] > 0:
            abilities[key] -= 1
            abilities[key] = max(abilities[key], 0) # Prevent going below 0
            if abilities[key] == 0:
                keys_to_remove.append(key)
    for key in keys_to_remove:
        abilities.erase(key)
    EventBus.update_cooldowns.emit()

func remove_ability(owner_id: String, ability: FW_Ability) -> void:
    var key = [owner_id, ability.name]
    if abilities.has(key):
        abilities.erase(key)

func reset_cooldowns() -> void:
    abilities.clear()
