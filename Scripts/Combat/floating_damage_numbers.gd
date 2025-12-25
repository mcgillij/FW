extends CPUParticles2D

class_name FW_FloatingDamageNumbers

@onready var dmg_label: Label = %damage_numbers

# Track which combatant owns this floating damage numbers instance
var owner_is_player: bool = false
var signals_connected: bool = false

func set_combatant_owner(is_player: bool) -> void:
	owner_is_player = is_player
	_connect_owner_specific_signals()

func _connect_owner_specific_signals() -> void:
	if signals_connected:
		return

	# Remove healing signal connections - healing will be handled by instantiate-per-event pattern
	signals_connected = true

func _ready() -> void:
	finished.connect(queue_free)
	EventBus.publish_crit.connect(_crit)
	EventBus.gain_xp.connect(_xp)

func _emit_damage_numbers(damage: int, bypass: bool = false, shields = false) -> void:
	if !dmg_label:
		dmg_label = %damage_numbers
	if bypass:
		dmg_label.modulate = Color.WEB_PURPLE
	elif shields:
		dmg_label.modulate = Color.LIGHT_BLUE
	else:
		dmg_label.modulate = Color.YELLOW
	dmg_label.text = str(damage)
	# Wait for SubViewport to render before emitting
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	emitting = true

func show_evade(is_player_evading:bool) -> void:
	if is_player_evading:
		position.x = 300
		position.y = 50
	else:
		position.x = 170
		position.y = 50

	if !dmg_label:
		dmg_label = %damage_numbers
	dmg_label.modulate = Color.DODGER_BLUE
	dmg_label.text = "EVADE!"
	# Wait for SubViewport to render before emitting
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	emitting = true

func _crit() -> void:
	if !dmg_label:
		dmg_label = %damage_numbers
	dmg_label.modulate = Color.RED
	dmg_label.text = "CRITICAL!"
	# Wait for SubViewport to render before emitting
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	emitting = true

func _heal(heal_amount: int) -> void:
	# Set position based on whether this is for player or monster (similar to show_evade)
	if owner_is_player:
		position.x = 300
		position.y = 50
	else:
		position.x = 170
		position.y = 50

	if !dmg_label:
		dmg_label = %damage_numbers
	dmg_label.modulate = Color.LIGHT_GREEN
	dmg_label.text = str(heal_amount)
	# Wait for SubViewport to render before emitting
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	emitting = true

func _gain_gold(gold_amount: int) -> void:
	if !dmg_label:
		dmg_label = %damage_numbers
	dmg_label.modulate = Color.YELLOW
	dmg_label.text = str(gold_amount)
	# Wait for SubViewport to render before emitting
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	emitting = true

func _xp(xp: int) -> void:
	position.x = 250
	position.y = 150
	if !dmg_label:
		dmg_label = %damage_numbers
	dmg_label.modulate = Color.DARK_ORANGE
	dmg_label.text = str(xp) + " xp"
	# Wait for SubViewport to render before emitting
	if is_inside_tree():
		await get_tree().process_frame
		await get_tree().process_frame
	emitting = true

func _minus_continue() -> void:
	if !dmg_label:
		dmg_label = %damage_numbers
	dmg_label.modulate = Color.PALE_VIOLET_RED
	dmg_label.text = "-1"
	if !is_inside_tree():
		await ready
	# Ensure the SubViewport exists and is ready
	var subviewport = get_node("SubViewport")
	if subviewport:
		# Force the SubViewport to render the updated content
		subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
	emitting = true
