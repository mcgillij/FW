extends FW_EffectCommand

class_name FW_DamageCommand

@export var amount: int
@export var reason: String
@export var attacker_is_player: bool
@export var bypass: bool = false

func _init(p_amount: int = 0, p_reason: String = "", p_attacker_is_player: bool = true, p_bypass: bool = false) -> void:
	amount = p_amount
	reason = p_reason
	attacker_is_player = p_attacker_is_player
	bypass = p_bypass
	command_type = "damage"
	description = "Deal %d damage%s to %s" % [amount, " (bypass)" if bypass else "", "monster" if attacker_is_player else "player"]
	# Set default log message
	var attacker = "Player" if attacker_is_player else "Monster"
	var target = "Monster" if attacker_is_player else "Player"
	log_message = "%s deals %d damage%s to %s%s" % [attacker, amount, " (bypass)" if bypass else "", target, " with " + reason if reason else ""]

func execute() -> void:
	# Apply damage but suppress CombatManager's automatic publish events when running from queued commands
	CombatManager.apply_damage_with_checks(amount, reason, attacker_is_player, false, bypass, false)
	# Emit the precomputed log message (if provided by caller) for queued commands like bypass damage.
	# Prefer structured publish so CombatLogBus can format final UI messages
	EventBus.publish_damage.emit(amount, reason, attacker_is_player)
