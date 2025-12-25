extends Resource

class_name FW_BuffManager

# Holds the active buffs and debuffs
var active_buffs = {}

func add_buff(buff: FW_Buff) -> FW_Buff:
	var b = buff.duplicate()
	# Set owner_type on the buff
	if has_meta("owner_type"):
		b.owner_type = get_meta("owner_type")
	else:
		b.owner_type = "player"

	# Ensure caster_type is set (default to owner if not specified)
	if b.caster_type == "":
		b.caster_type = b.owner_type

	b.activate()
	b.duration_left = b.duration
	var unique_id = b.get_instance_id()
	active_buffs[unique_id] = b
	# Emit correct signal based on owner (deferred to ensure UI is ready)
	if b.owner_type == "monster":
		call_deferred("_emit_monster_add_buff", b)
	else:
		call_deferred("_emit_player_add_buff", b)
	return b

func add_combat_only_buff(buff: FW_Buff) -> FW_Buff:
	"""Add a buff that should only last for the current combat"""
	var b = buff.duplicate()
	# Set owner_type on the buff
	if has_meta("owner_type"):
		b.owner_type = get_meta("owner_type")
	else:
		b.owner_type = "player"

	# Ensure caster_type is set
	if b.caster_type == "":
		b.caster_type = "environment"  # Default for event-based effects

	# Set duration to a high number but mark it for combat cleanup
	b.duration_left = 99
	b.set_meta("combat_only", true)
	
	b.activate()
	var unique_id = b.get_instance_id()
	active_buffs[unique_id] = b
	
	# Emit correct signal based on owner (deferred to ensure UI is ready)
	if b.owner_type == "monster":
		call_deferred("_emit_monster_add_buff", b)
	else:
		call_deferred("_emit_player_add_buff", b)
	return b

func clear_combat_only_buffs() -> void:
	"""Remove all buffs marked as combat-only"""
	var to_remove = []
	for key in active_buffs.keys():
		if active_buffs.has(key):
			var buff = active_buffs[key]
			if buff.has_meta("combat_only") and buff.get_meta("combat_only"):
				to_remove.append(key)
	
	for key in to_remove:
		if active_buffs.has(key):
			var buff = active_buffs[key]
			# Don't call on_expire() for combat-only buffs, just remove them
			active_buffs.erase(key)
			# Still emit the remove signal for UI updates
			if has_meta("owner_type") and get_meta("owner_type") == "monster":
				EventBus.monster_remove_buff.emit(buff)
			else:
				EventBus.player_remove_buff.emit(buff)
	
	# Update buff bar
	if has_meta("owner_type") and get_meta("owner_type") == "monster":
		EventBus.monster_update_buff_bar.emit()
	else:
		EventBus.player_update_buff_bar.emit()

func clear_buffs() -> void:
	active_buffs.clear()

func remove_buff(buff: FW_Buff) -> void:
	var unique_id = buff.get_instance_id()
	if active_buffs.has(unique_id):
		active_buffs.erase(unique_id)
		# Emit correct signal based on owner
		if has_meta("owner_type") and get_meta("owner_type") == "monster":
			EventBus.monster_remove_buff.emit(buff)
		else:
			EventBus.player_remove_buff.emit(buff)

func process_turn() -> void:
	"""Process all buffs once at the end of their owner's turn"""
	var to_remove = []
	# Iterate through the dictionary keys so we can safely mark items for removal
	for key in active_buffs.keys():
		if active_buffs.has(key):
			var buff = active_buffs[key]
			buff.apply_per_turn_effects()
			if buff.duration_left <= 0:
				to_remove.append(key)
	# Now, iterate over keys for actual removal
	for key in to_remove:
		if active_buffs.has(key):
			remove_buff(active_buffs[key])  # Removes only the specific expired instance
	# Emit correct signal based on owner
	if has_meta("owner_type") and get_meta("owner_type") == "monster":
		EventBus.monster_update_buff_bar.emit()
	else:
		EventBus.player_update_buff_bar.emit()

func notify_damage_taken(amount: int, owner_type: String) -> void:
	for buff in active_buffs.values():
		if buff.owner_type == owner_type:
			buff.on_damage_taken(amount)

func notify_evasion(owner_type: String) -> void:
	for buff in active_buffs.values():
		if buff.owner_type == owner_type:
			buff.on_evasion()

# Deferred signal emission helpers to ensure UI is ready
func _emit_player_add_buff(buff: FW_Buff) -> void:
	EventBus.player_add_buff.emit(buff)

func _emit_monster_add_buff(buff: FW_Buff) -> void:
	EventBus.monster_add_buff.emit(buff)
