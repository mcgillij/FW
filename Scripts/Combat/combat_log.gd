extends Panel

var log_manager = FW_CombatLogManager.new($MarginContainer/CombatLog)

func _ready() -> void:
	if ConfigManager.ingame_combat_log:
		show()
	else:
		hide()
	EventBus.publish_bonus_damage.connect(_on_game_manager_publish_bonus_damage)
	var bus = FW_CombatLogBus.new()
	add_child(bus)

	EventBus.publish_combat_log.connect(_on_publish_combat_log)
	EventBus.publish_combat_log_with_icon.connect(_on_publish_combat_log_with_icon)
	EventBus.publish_monster_used_ability.connect(_on_combat_resolver_monster_ability)

	log_manager.clear_log()

func get_player_name() -> String:
	return GDM.player.character.name

func get_monster_name() -> String:
	return GDM.monster_to_fight.name

func log_with_turn(player_msg: String, monster_msg: String, with_image: Texture = null):
	var text: String
	if GDM.game_manager.turn_manager.is_player_turn():
		text = player_msg
	else:
		text = monster_msg
	if with_image:
		log_manager.add_text_with_image(text, with_image)
	else:
		log_manager.add_text(text)

func log_with_damage_source(player_msg: String, monster_msg: String, sinker_owner: FW_Piece.OWNER):
	var text: String
	if sinker_owner == FW_Piece.OWNER.PLAYER:
		text = player_msg
	else:
		text = monster_msg
	log_manager.add_text(text)

# Generic booster effect handler - ONLY system now
	# Generic booster messages are handled by CombatLogBus for aggregation/templating

func _on_game_manager_publish_mana(mana: Dictionary) -> void:
	if GDM.game_manager.turn_manager.is_player_turn():
		log_manager.update_log_player_mana(mana, GDM.player.character.name)
	else:
		log_manager.update_log_enemy_mana(mana, GDM.monster_to_fight.name)

func _on_game_manager_publish_mana_bonus(mana: Dictionary) -> void:
	if GDM.game_manager.turn_manager.is_player_turn():
		log_manager.update_log_player_mana_bonus(mana, GDM.player.character.name)


func _on_combat_resolver_drain_mana(mana: Dictionary) -> void:
	if GDM.game_manager.turn_manager.is_player_turn():
		log_manager.update_log_player_mana_drain(mana, get_player_name(), get_monster_name())
	else:
		log_manager.update_log_enemy_mana_drain(mana, get_monster_name(), get_player_name())

func _on_game_manager_publish_used_ability(ability: FW_Ability) -> void:
	var text = get_player_name() + " has used: " + ability.name
	log_manager.add_text_with_image(text, ability.texture)

func _on_combat_resolver_monster_ability(ability: FW_Ability) -> void:
	var text = get_monster_name() + " has used: " + ability.name
	log_manager.add_text_with_image(text, ability.texture)

func _on_game_manager_publish_bonus_damage(ability: FW_Ability, bonus_damage: int) -> void:
	log_with_turn(
		get_player_name() + "'s " + ability.name + " does [color=orange]" + str(bonus_damage) + "[/color] bonus damage from [color=purple]%s[/color] stat!" % [FW_Ability.ABILITY_TYPES.keys()[ability.ability_type]],
		get_monster_name() + "'s " + ability.name + " does [color=orange]" + str(bonus_damage) + "[/color] bonus damage from [color=purple]%s[/color] stat!" % [FW_Ability.ABILITY_TYPES.keys()[ability.ability_type]]
	)

	# Legacy handlers removed; CombatLogBus centralizes these messages

func _on_player_buff_expire(buff: FW_Buff) -> void:
	var text = get_player_name() + "'s " + str(buff.name) + " has expired!"
	log_manager.add_text_with_image(text, buff.texture)

func _on_monster_buff_expire(buff: FW_Buff) -> void:
	var text = get_monster_name() + "'s " + str(buff.name) + " has expired!"
	log_manager.add_text_with_image(text, buff.texture)

func _on_bottom_ui_2_show_ingame_combat_log() -> void:
	show()

func _on_bottom_ui_2_hide_ingame_combat_log() -> void:
	hide()

func _on_publish_combat_log(message: String) -> void:
	log_manager.add_text(message)

func _on_publish_combat_log_with_icon(message: String, icon: Texture2D) -> void:
	var img = icon if icon else null
	if img:
		log_manager.add_text_with_image(message, img)
	else:
		log_manager.add_text(message)

func _on_do_player_gain_shields(amount: int, _ability_texture: Texture2D, target_name: String) -> void:
	var text = target_name + " gains [color=lightblue]" + str(amount) + "[/color] 🛡️ shields!"
	log_manager.add_text(text)

func _on_do_monster_gain_shields(amount: int, _ability_texture: Texture2D, target_name: String) -> void:
	var text = target_name + " gains [color=lightblue]" + str(amount) + "[/color] 🛡️ shields!"
	log_manager.add_text(text)
