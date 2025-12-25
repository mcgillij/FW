extends FW_Item

class_name FW_Consumable

@export var gold_value: int
@export var cost: int

@export_group("Effect")
@export var effect_resource: FW_EffectResource  # Direct reference to existing effect
@export var effect_amount_override: int = 0  # Override amount if needed (0 = use resource default)
@export var effect_context: Dictionary = {}  # Additional context for the effect

# Use the consumable - integrates with existing combat system
func use_consumable() -> bool:
	# Check if it's player's turn
	if not _can_use_now():
		EventBus.publish_combat_log.emit("Consumables can only be used during your turn!")
		return false

	if not effect_resource:
		push_warning("Consumable '%s' has no effect resource assigned" % name)
		return false

	# Create a copy of the effect resource to avoid modifying the original
	var consumable_effect = effect_resource.duplicate()

	# Override amount if specified
	if effect_amount_override > 0:
		consumable_effect.amount = effect_amount_override

	# Prepare context for the effect
	var context = effect_context.duplicate()
	context["consumable_name"] = name
	context["is_consumable"] = true
	context["is_player_turn"] = true  # Consumables are typically used by player

	# Add attacker/target context for logging
	if GDM.player and GDM.player.character:
		context["attacker"] = GDM.player.character.name
	if GDM.monster_to_fight:
		context["target"] = GDM.monster_to_fight.name

	# Queue the effect through the existing combat system
	var cmd = FW_UniversalEffectCommand.new(consumable_effect, context)
	CombatManager.queue_command(cmd)
	CombatManager.process_queue()

	# Remove the consumable from player's inventory and slots
	if GDM.player:
		GDM.player.consume_item(self)

	return true

func _can_use_now() -> bool:
	# Check if it's player's turn and game allows actions
	if not GDM.game_manager or not GDM.game_manager.turn_manager:
		return false

	return (GDM.game_manager.turn_manager.is_player_turn() and
			GDM.game_manager.turn_manager.can_perform_action())

# Check if this consumable can be used (override for specific conditions)
func can_use() -> bool:
	# Basic check - ensure we have an effect resource
	if not effect_resource:
		return false

	# Check turn state
	if not _can_use_now():
		return false

	# Add any consumable-specific usage conditions here
	# For example: check if in combat, check cooldowns, etc.

	return true
