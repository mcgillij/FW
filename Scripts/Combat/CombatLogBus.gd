extends Node
class_name FW_CombatLogBus

@export var merge_window := 0.15 # seconds to wait before flushing aggregates

var _shield_buffer: Dictionary = {}
var _flush_timer: Timer

func _ready() -> void:
	# Subscribe to legacy low-level events we want to normalize/aggregate
	if EventBus.has_signal("do_player_gain_shields"):
		EventBus.do_player_gain_shields.connect(_on_do_player_gain_shields)
	if EventBus.has_signal("do_monster_gain_shields"):
		EventBus.do_monster_gain_shields.connect(_on_do_monster_gain_shields)
	if EventBus.has_signal("do_booster_effect"):
		EventBus.do_booster_effect.connect(_on_generic_booster_effect)

	# Listen for explicit context end events so we can flush aggregates immediately
	if EventBus.has_signal("combat_context_end"):
		EventBus.combat_context_end.connect(_on_combat_context_end)

	# Start-of-turn messages
	if EventBus.has_signal("start_of_player_turn"):
		EventBus.start_of_player_turn.connect(_on_start_of_player_turn)
	if EventBus.has_signal("start_of_monster_turn"):
		EventBus.start_of_monster_turn.connect(_on_start_of_monster_turn)

	# Centralize final damage logging here (migrate formatting out of UI)
	if EventBus.has_signal("publish_damage"):
		EventBus.publish_damage.connect(_on_publish_damage)
	if EventBus.has_signal("publish_bypass_damage"):
		EventBus.publish_bypass_damage.connect(_on_publish_bypass_damage)

	if EventBus.has_signal("publish_crit"):
		EventBus.publish_crit.connect(_on_publish_crit)
	if EventBus.has_signal("publish_evasion"):
		EventBus.publish_evasion.connect(_on_publish_evasion)
	if EventBus.has_signal("publish_damage_resist"):
		EventBus.publish_damage_resist.connect(_on_publish_damage_resist)
	if EventBus.has_signal("publish_lifesteal"):
		EventBus.publish_lifesteal.connect(_on_publish_lifesteal)

	# Note: do NOT subscribe to the same final publish_combat_log signals we emit.
	# Subscribing and re-emitting them created infinite recursion.

	_flush_timer = Timer.new()
	_flush_timer.one_shot = true
	_flush_timer.wait_time = merge_window
	add_child(_flush_timer)
	_flush_timer.timeout.connect(_flush_aggregates)

func _on_do_player_gain_shields(amount: int, ability_texture: Texture2D, target_name: String) -> void:
	_buffer_shield(target_name, amount, ability_texture)

func _on_do_monster_gain_shields(amount: int, ability_texture: Texture2D, target_name: String) -> void:
	_buffer_shield(target_name, amount, ability_texture)

func _buffer_shield(target: String, amount: int, texture: Texture2D) -> void:
	if not _shield_buffer.has(target):
		_shield_buffer[target] = {"amount": 0, "tex": texture}
	_shield_buffer[target]["amount"] += amount
	# keep a texture if provided
	if texture and not _shield_buffer[target]["tex"]:
		_shield_buffer[target]["tex"] = texture
	# restart timer so we aggregate events occurring in quick succession
	_flush_timer.start()

func _flush_aggregates() -> void:
	for target in _shield_buffer.keys():
		var entry = _shield_buffer[target]
		var amt = int(entry["amount"]) if entry.has("amount") else 0
		var text = "%s gains [color=lightblue]%d[/color] 🛡️ shields!" % [target, amt]
		EventBus.publish_combat_log.emit(text)
	_shield_buffer.clear()

func _on_generic_booster_effect(resource: Resource, effect_category: String) -> void:
	if not resource or not resource.has_method("get_formatted_log_message"):
		return

	# Prefer explicit owner/target provided on the resource or via context; fall back to current turn only if missing
	var owner_name = null
	var target_name = null
	# Some resources may carry an owner_type property
	if resource.get("owner_type") != null:
		owner_name = GDM.player.character.name if resource.owner_type == "player" else GDM.monster_to_fight.name
	# If the resource has templating context embedded, use it
	# Look for context embedded on the resource (either 'context' or 'last_context')
	var ctx = null
	if resource.get("context") != null and typeof(resource.context) == TYPE_DICTIONARY:
		ctx = resource.context
	elif resource.get("last_context") != null and typeof(resource.last_context) == TYPE_DICTIONARY:
		ctx = resource.last_context
	if ctx != null:
		if ctx.has("attacker"):
			owner_name = ctx["attacker"]
		if ctx.has("target"):
			target_name = ctx["target"]

	# fallback to current turn names if still missing
	if owner_name == null:
		owner_name = GDM.player.character.name if GDM.game_manager.turn_manager.is_player_turn() else GDM.monster_to_fight.name
	if target_name == null:
		# For buffs/debuffs, the target should be the owner of the effect, not the opposite of current turn
		if resource.get("owner_type") != null:
			target_name = GDM.player.character.name if resource.owner_type == "player" else GDM.monster_to_fight.name
		else:
			# Fallback to turn-based logic only if owner_type is not available
			target_name = GDM.monster_to_fight.name if GDM.game_manager.turn_manager.is_player_turn() else GDM.player.character.name

	var format_vars = {"owner": owner_name, "target": target_name, "effect_category": effect_category}
	format_vars["icon"] = resource.texture if resource.get("texture") else null

	var message = resource.get_formatted_log_message(format_vars)
	var img = format_vars.get("icon", null)
	if img:
		EventBus.publish_combat_log_with_icon.emit(message, img)
	else:
		EventBus.publish_combat_log.emit(message)

func _on_start_of_player_turn() -> void:
	pass

func _on_start_of_monster_turn() -> void:
	pass

func _on_combat_context_end(_context_id: String) -> void:
	# For now we flush all aggregated buffers when a context ends.
	# Later we can flush only specific context buckets if needed.
	_flush_aggregates()


func _on_publish_damage(amount: int, reason: String, is_player: bool) -> void:
	# Format a standard damage message and publish via the final log signals
	var attacker = GDM.player.character.name if is_player else GDM.monster_to_fight.name
	var target = GDM.monster_to_fight.name if is_player else GDM.player.character.name
	var text = "%s deals [color=orange]%d[/color] damage to %s" % [attacker, amount, target]
	if reason and reason.strip_edges() != "":
		text += " " + reason
	EventBus.publish_combat_log.emit(text)

func _on_publish_bypass_damage(amount: int, _reason: String = "") -> void:
	# Bypass messages emphasize shields being bypassed
	# We don't have attacker flag here, rely on current turn for wording
	var text: String
	if GDM.game_manager.turn_manager.is_player_turn():
		text = "%s [color=purple]bypasses[/color]: [color=lightblue]%d[/color] %s shields!" % [GDM.player.character.name, amount, GDM.monster_to_fight.name]
	else:
		text = "%s [color=purple]bypasses[/color]: [color=lightblue]%d[/color] %s shields!" % [GDM.monster_to_fight.name, amount, GDM.player.character.name]
	EventBus.publish_combat_log.emit(text)

func _on_publish_crit() -> void:
	var actor_name = GDM.player.character.name if GDM.game_manager.turn_manager.is_player_turn() else GDM.monster_to_fight.name
	var text = "%s unleashes a [color=yellow]\u2728 CRITICAL HIT! \u2728[/color] Massive damage!" % actor_name
	EventBus.publish_combat_log.emit(text)

func _on_publish_evasion(player_turn: bool) -> void:
	var text: String
	if player_turn:
		text = GDM.player.character.name + " has [color=cyan]\ud83d\udca8 EVADED \ud83d\udca8[/color] the attack!"
	else:
		text = GDM.monster_to_fight.name + " has [color=cyan]\ud83d\udca8 EVADED \ud83d\udca8[/color] the attack!"
	EventBus.publish_combat_log.emit(text)

func _on_publish_damage_resist(amount: int) -> void:
	var text: String
	if GDM.game_manager.turn_manager.is_player_turn():
		text = GDM.monster_to_fight.name + " [color=skyblue]\ud83d\udee1\ufe0f RESISTED! \ud83d\udee1\ufe0f[/color] blocks [color=yellow]" + str(amount) + "[/color] damage!"
	else:
		text = GDM.player.character.name + " [color=skyblue]\ud83d\udee1\ufe0f RESISTED! \ud83d\udee1\ufe0f[/color] blocks [color=yellow]" + str(amount) + "[/color] damage!"
	EventBus.publish_combat_log.emit(text)

func _on_publish_lifesteal(amount: int, owner_is_player: bool) -> void:
	var owner_name = GDM.player.character.name if owner_is_player else GDM.monster_to_fight.name
	var text = "%s is healed for [color=green]%d[/color] via lifesteal!" % [owner_name, amount]
	EventBus.publish_combat_log.emit(text)
