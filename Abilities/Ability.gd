extends Resource

class_name FW_Ability
enum ABILITY_TYPES { Bark, Reflex, Alertness, Vigor, Enthusiasm }

const TYPE_COLORS = {
	"bark": Color("ff5555"),
	"alertness": Color("6272a4"),
	"reflex": Color("50fa7b"),
	"vigor": Color("ffb86c"),
	"enthusiasm": Color("ff79c6")
}

@export var name: String
@export var ability_type: ABILITY_TYPES
@export var level: int
@export var texture: Texture2D
@export var disabled_texture: Texture2D
@export var cost: Dictionary # mana cost
@export var damage: int
@export var initial_cooldown: int # in turns
@export var effects := {}
@export var sinker_effects := {}  # Effects that trigger when sinker reaches bottom, e.g., {"type": "explosion", "radius": 1, "levels": 3}
@export var visual_effect: Resource  # Optional single AbilityVisualEffect resource reference for this ability
@export var cast_visual_effect: Resource  # Optional visual effect to play when the ability is cast or when sinkers spawn
@export var sinker_impact_visual_effect: Resource  # Optional effect when a sinker reaches the bottom
@export_multiline var description: String
@export var effect_duration := .3
@export_multiline var log_message: String = ""  # Templated log message, e.g., "{attacker} uses {ability_name} dealing {damage} damage"

func get_formatted_log_message(vars: Dictionary = {}) -> String:
	# Default vars
	var default_vars = {
		"ability_name": name,
		"ability_type": ABILITY_TYPES.keys()[ability_type],
		"damage": damage,
		"level": level
	}
	# include a template-friendly icon placeholder (may be null)
	default_vars["icon"] = texture
	# Merge with provided vars
	for key in vars.keys():
		default_vars[key] = vars[key]
	if log_message and log_message.strip_edges() != "":
		var formatted := log_message.format(default_vars)
		# Remove any explicit icon tokens from the output; the UI will use the texture separately
		formatted = formatted.replace("[icon]", "")
		formatted = formatted.replace("{icon}", "")
		formatted = formatted.strip_edges()
		# Detect any leftover/unreplaced template tokens like {amount} and log them for debugging
		var unmatched: Array = []
		var start := formatted.find("{")
		while start != -1:
			var end := formatted.find("}", start)
			if end == -1:
				break
			var token := formatted.substr(start, end - start + 1)
			unmatched.append(token)
			start = formatted.find("{", end)
		if unmatched.size() > 0:
			var warn_msg := "[Ability:TEMPLATE] %s: unmatched tokens %s in message '%s'" % [name, str(unmatched), formatted]
			# Editor/console hint
			push_warning(warn_msg)
			# Prefer centralized debug writer if present (use safe get to avoid invalid-property errors)
			if typeof(GDM) != TYPE_NIL:
				var clm = GDM.get("combat_log_manager") if GDM.has_method("get") else null
				if clm != null and clm.has_method("record_template_warning"):
					clm.record_template_warning(warn_msg)
			else:
				# Fallback to writing directly
				var debug_path := "user://save/template_warnings.txt"
				if not FileAccess.file_exists(debug_path):
					var createf := FileAccess.open(debug_path, FileAccess.WRITE)
					if createf:
						createf.close()
				var df := FileAccess.open(debug_path, FileAccess.READ_WRITE)
				if df:
					df.seek_end()
					df.store_line(warn_msg)
					df.close()
		return formatted
	# No explicit template: generate a sensible default message from computed vars
	var attacker = default_vars.get("attacker", "")
	var ability_name = default_vars.get("ability_name", name)
	var dmg = int(default_vars.get("damage", 0))
	var amount = int(default_vars.get("amount", 0))
	var action = str(default_vars.get("action", ""))
	if dmg > 0:
		var target = default_vars.get("target", "the target")
		return "%s uses %s dealing %d damage to %s!" % [attacker, ability_name, dmg, target]
	if amount > 0:
		# Common actions: gain_shield, mana_to_shields, mana gain, heal
		if action == "gain_shield" or action == "mana_to_shields" or action.find("shield") != -1:
			return "%s uses %s and gains %d shields!" % [attacker, ability_name, amount]
		elif action.find("mana") != -1:
			return "%s uses %s and gains %d mana!" % [attacker, ability_name, amount]
		elif action == "radiance" or action.find("heal") != -1:
			return "%s uses %s and heals %d HP!" % [attacker, ability_name, amount]
		else:
			return "%s uses %s: %s %d" % [attacker, ability_name, action, amount]
	# Fallback minimal message
	return "%s uses %s" % [attacker, ability_name]

func _to_string() -> String:
	return "[Ability: %s (%s)]" % [name, ability_type]

@warning_ignore("unused_parameter")
func activate_booster(grid: Node, params) -> void:
	# To be overridden by child classes
	pass

func get_preview_tiles(_grid: Node) -> Variant:
	return []

func trigger_visual_effects(phase: String, extra_params: Dictionary = {}) -> void:
	"""Trigger visual effects for a specific phase of this ability"""
	FW_Debug.debug_log(["FW_Ability.trigger_visual_effects: %s phase=%s" % [name, phase]])

	var resolved := resolve_visual_effect_for_phase(phase)
	var effect_res = resolved.get("resource")
	var effect_name: String = resolved.get("effect_name", "")
	var base_params = resolved.get("params", {})

	if effect_res == null:
		return

	if effect_name == "":
		push_warning("FW_Ability.trigger_visual_effects: effect has no effect_name for ability %s phase=%s" % [name, phase])
		return

	var params: Dictionary = {}
	if typeof(base_params) == TYPE_DICTIONARY:
		params = base_params.duplicate(true)

	for key in extra_params.keys():
		params[key] = extra_params[key]

	EventBus.ability_visual_effect_requested.emit(effect_name, params)

func resolve_visual_effect_for_phase(phase: String) -> Dictionary:
	"""Resolve which visual effect resource should handle the requested phase."""
	var effect_res: Resource = null
	match phase:
		"on_cast":
			if cast_visual_effect:
				effect_res = cast_visual_effect
			elif sinker_impact_visual_effect:
				effect_res = null
			else:
				effect_res = visual_effect
		"on_sinker_bottom":
			effect_res = sinker_impact_visual_effect if sinker_impact_visual_effect else visual_effect
		_:
			effect_res = visual_effect

	return _build_effect_payload(effect_res, phase)

func _build_effect_payload(effect_res, phase: String) -> Dictionary:
	var payload: Dictionary = {
		"effect_name": "",
		"params": {},
		"resource": effect_res,
		"phase": phase
	}

	if effect_res == null:
		return payload

	var effect_name := ""
	if typeof(effect_res) == TYPE_DICTIONARY:
		effect_name = str(effect_res.get("effect_name", ""))
		var shader_params = effect_res.get("shader_params")
		if typeof(shader_params) == TYPE_DICTIONARY:
			payload["params"] = shader_params.duplicate(true)
		var duration_val = effect_res.get("duration")
		if duration_val != null and typeof(duration_val) in [TYPE_INT, TYPE_FLOAT]:
			if float(duration_val) > 0.0:
				payload["params"]["duration"] = float(duration_val)
	elif typeof(effect_res) == TYPE_OBJECT:
		var res_name = effect_res.get("effect_name")
		if res_name != null:
			effect_name = str(res_name)
		var shader_params_obj = effect_res.get("shader_params")
		if typeof(shader_params_obj) == TYPE_DICTIONARY:
			payload["params"] = shader_params_obj.duplicate(true)
		var duration_obj = effect_res.get("duration")
		if duration_obj != null and typeof(duration_obj) in [TYPE_INT, TYPE_FLOAT]:
			if float(duration_obj) > 0.0:
				payload["params"]["duration"] = float(duration_obj)
	else:
		effect_name = str(effect_res)

	payload["effect_name"] = effect_name
	return payload

static func get_effect_display_info(ability: FW_Ability) -> Dictionary:
	var info = {"color": Color.YELLOW, "emoji": "💥", "type": "damage"}

	# Priority: bypass > damage_over_time > drain_with_heal > drain > channel > mana_convert > shield_health > heal > shield > damage

	if "bypass" in ability.effects:
		info.color = Color.PURPLE
		info.emoji = "⚡"
		info.type = "bypass"
	elif "damage_over_time" in ability.effects:
		info.color = Color.RED
		info.emoji = "☠️"
		info.type = "damage_over_time"
	elif "drain_with_heal" in ability.effects:
		info.color = Color.MAGENTA
		info.emoji = "🩸"
		info.type = "drain_heal"
	elif "drain" in ability.effects:
		info.color = Color.CYAN
		info.emoji = "💧"
		info.type = "mana_drain"
	elif "channel" in ability.effects:
		info.color = Color.TEAL
		info.emoji = "🔄"
		info.type = "channel"
	elif "mana_to_damage" in ability.effects or "mana_to_shields" in ability.effects:
		info.color = Color.ORANGE
		info.emoji = "✨"
		info.type = "mana_convert"
	elif "shields_to_health" in ability.effects:
		info.color = Color.PINK
		info.emoji = "🩹"
		info.type = "shield_health"
	elif "radiance" in ability.effects or "heal" in ability.effects:
		info.color = Color.GREEN
		info.emoji = "💚"
		info.type = "heal"
	elif "gain_shield" in ability.effects or "shield" in ability.effects:
		info.color = Color.BLUE
		info.emoji = "🛡️"
		info.type = "shield"
	elif ability.sinker_effects.size() > 0:
		if "damage" in ability.sinker_effects:
			info.color = Color.YELLOW
			info.emoji = "💥"
			info.type = "damage"
		elif "shield_gain" in ability.sinker_effects:
			info.color = Color.BLUE
			info.emoji = "🛡️"
			info.type = "shield"
		elif "buff_path" in ability.sinker_effects:
			info.color = Color.GOLD
			info.emoji = "⭐"
			info.type = "buff"
		elif "heal_amount" in ability.sinker_effects:
			info.color = Color.LIME
			info.emoji = "💚"
			info.type = "sinker_heal"
		elif "bypass_shields" in ability.sinker_effects:
			info.color = Color.PURPLE
			info.emoji = "⚡"
			info.type = "bypass"
	elif ability.damage > 0:
		# Default to damage
		pass
	else:
		info.type = "none"

	return info
