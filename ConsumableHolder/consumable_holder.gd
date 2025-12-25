extends Node2D

var current_selected_consumable: FW_Consumable = null

@onready var consumable_holder: VBoxContainer = %ConsumableHolder
@onready var consumable_tooltip: Panel = %consumable_tooltip
@onready var consumable_name: Label = %consumable_name
@onready var consumable_description: Label = %consumable_description
@onready var consumable_image: TextureRect = %consumable_image

@onready var use_button: Button = %use_button
@onready var close_button: Button = %close_button

@export var prefab: PackedScene

func setup_consumables() -> void:
	# Clear existing consumables first
	for child in consumable_holder.get_children():
		child.queue_free()

	# Add current consumables from player slots
	for c in GDM.player.consumable_slots:
		if c:
			var p = prefab.instantiate()
			p.setup(c)
			consumable_holder.add_child(p)

func _ready() -> void:
	setup_consumables()
	EventBus.consumable_clicked.connect(show_tooltip)

	# Connect to turn manager to enable/disable consumables based on turn
	if GDM.game_manager and GDM.game_manager.turn_manager:
		GDM.game_manager.turn_manager.turn_started.connect(_on_turn_started)

	# Update consumables when player changes their slots
	EventBus.consumable_slots_changed.connect(_on_consumable_slots_changed)

	# Connect buttons (only if not already connected from scene)
	if not use_button.pressed.is_connected(_on_use_button_pressed):
		use_button.pressed.connect(_on_use_button_pressed)
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

func _on_turn_started(turn_state: int) -> void:
	# Enable/disable consumables based on turn state
	var is_player_turn = (turn_state == FW_TurnManager.TurnState.PLAYER_TURN)
	_set_consumables_enabled(is_player_turn)

func _set_consumables_enabled(enabled: bool) -> void:
	# Update cursor and interactivity for all consumable prefabs
	for prefab_instance in consumable_holder.get_children():
		if prefab_instance.has_method("set_usable"):
			prefab_instance.set_usable(enabled)

func _on_consumable_slots_changed() -> void:
	# Refresh the display when consumable slots change
	setup_consumables()

func show_tooltip(c: FW_Consumable) -> void:
	if not GDM.game_manager or not GDM.game_manager.popup_coordinator:
		push_warning("PopupCoordinator not available in GameManager")
		return

	if not _can_use_consumables():
		return  # Don't show tooltip if consumables can't be used

	# Store the selected consumable
	current_selected_consumable = c

	# Setup panel with consumable data
	consumable_name.text = c.name
	consumable_description.text = c.flavor_text + "\n" + _get_consumable_effect_text(c)
	consumable_image.texture = c.texture

	# Enable/disable use button based on turn state
	use_button.disabled = not _can_use_consumables()

	# Show via coordinator (handles toggle behavior automatically)
	GDM.game_manager.popup_coordinator.show_popup(
		consumable_tooltip,
		"consumable",
		{"consumable": c}
	)

func _get_consumable_effect_text(consumable: FW_Consumable) -> String:
	if consumable.effect_resource:
		var amount = consumable.effect_amount_override if consumable.effect_amount_override > 0 else consumable.effect_resource.amount
		match consumable.effect_resource.effect_type:
			"heal":
				return "Restores %d HP" % amount
			"shield":
				return "Grants %d shields" % amount
			"mana_gain":
				return "Restores mana"
			_:
				return "Unknown effect"
	return "No effect"

func _can_use_consumables() -> bool:
	# Check if it's player's turn and game is active
	if not GDM.game_manager or not GDM.game_manager.turn_manager:
		return false

	return (GDM.game_manager.turn_manager.is_player_turn() and
			GDM.game_manager.turn_manager.can_perform_action())

func _on_use_button_pressed() -> void:
	if current_selected_consumable and _can_use_consumables():
		_use_consumable(current_selected_consumable)
	# Close popup via coordinator
	if GDM.game_manager and GDM.game_manager.popup_coordinator:
		GDM.game_manager.popup_coordinator.close_current_popup()

func _use_consumable(consumable: FW_Consumable) -> void:
	if consumable.use_consumable():
		# Consumable was used successfully - the combat log message will be handled by the EffectResource
		# But we can add a specific "used consumable" message
		EventBus.publish_combat_log_with_icon.emit(
			"%s used %s!" % [GDM.player.character.name, consumable.name],
			consumable.texture
		)

		# Refresh the display to remove the consumed item
		setup_consumables()

		# Emit signal for other systems that might need to know
		EventBus.consumable_used.emit(consumable)

func _on_close_button_pressed() -> void:
	# Close popup via coordinator
	if GDM.game_manager and GDM.game_manager.popup_coordinator:
		GDM.game_manager.popup_coordinator.close_current_popup()
