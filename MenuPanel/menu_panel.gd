extends Control

signal inventory_pressed
signal equipment_pressed
signal combined_stats_pressed
signal quests_pressed
signal skilltree_pressed
signal bestiary_pressed
signal tutorial_pressed
signal mastery_pressed

# New signals for notification clearing
signal equipment_screen_opened
signal inventory_screen_opened

@onready var game_menu_button: Button = %game_menu_button
@onready var menu_panel: Panel = %menu_panel
@onready var skilltree_button: TextureButton = %skilltree_button
@onready var combined_stats_button: TextureButton = %combined_stats_button
@onready var quests_button: TextureButton = %quests_button
@onready var equipment_button: TextureButton = %equipment_button
@onready var inventory_button: TextureButton = %inventory_button

var quests_tween: Tween = null
var skilltree_tween: Tween = null
var combined_stats_tween: Tween = null
var equipment_tween: Tween = null
var inventory_tween: Tween = null


func _ready() -> void:
	update_button_alerts()

	# Check for existing notifications from NotificationManager when this scene loads
	_check_existing_notifications()

	# Listen for quest events
	EventBus.quest_added.connect(_on_quest_event)
	EventBus.quest_goal_completed.connect(_on_quest_event)
	EventBus.quest_completed.connect(_on_quest_event)

	# Listen for equipment/consumable events
	EventBus.equipment_added.connect(_on_equipment_added)
	EventBus.consumable_added.connect(_on_consumable_added)
	EventBus.inventory_item_added.connect(_on_inventory_item_added)

	# Connect menu button signals to emit custom signals and clear notifications
	%inventory_button.pressed.connect(func():
		emit_signal("inventory_pressed")
		_stop_pulse("inventory")
		emit_signal("inventory_screen_opened")
	)
	%equipment_button.pressed.connect(func():
		emit_signal("equipment_pressed")
		_stop_pulse("equipment")
		emit_signal("equipment_screen_opened")
	)
	%combined_stats_button.pressed.connect(func(): emit_signal("combined_stats_pressed"))
	%quests_button.pressed.connect(func():
		emit_signal("quests_pressed")
		_stop_pulse("quests")
	)
	%skilltree_button.pressed.connect(func(): emit_signal("skilltree_pressed"))
	%bestiary_button.pressed.connect(func(): emit_signal("bestiary_pressed"))
	%tutorial_button.pressed.connect(func(): emit_signal("tutorial_pressed"))
	%mastery_button.pressed.connect(func(): emit_signal("mastery_pressed"))

func _on_quest_event(_quest, _goal = null) -> void:
	# Always show menu and pulse quest button
	menu_panel.show()
	game_menu_button.hide()
	_start_pulse(quests_button, "quests")

func _on_equipment_added(_equipment) -> void:
	# Show menu and pulse equipment button when new equipment is added
	menu_panel.show()
	game_menu_button.hide()
	_start_pulse(equipment_button, "equipment")

func _on_consumable_added(_consumable) -> void:
	# Show menu and pulse inventory button when new consumables are added
	menu_panel.show()
	game_menu_button.hide()
	_start_pulse(inventory_button, "inventory")

func _on_inventory_item_added(_item) -> void:
	# Show menu and pulse inventory button when new items are added
	menu_panel.show()
	game_menu_button.hide()
	_start_pulse(inventory_button, "inventory")

# Check for existing notifications when MenuPanel loads (for cross-scene notifications)
func _check_existing_notifications() -> void:
	if not GDM.notification_manager:
		return

	var NotificationManagerScript = load("res://Scripts/FW_NotificationManager.gd")

	# Check each notification type and trigger appropriate visual feedback
	if GDM.notification_manager.is_notification_active(NotificationManagerScript.NOTIFICATION_TYPE.QUESTS):
		menu_panel.show()
		game_menu_button.hide()
		_start_pulse(quests_button, "quests")

	if GDM.notification_manager.is_notification_active(NotificationManagerScript.NOTIFICATION_TYPE.EQUIPMENT):
		menu_panel.show()
		game_menu_button.hide()
		_start_pulse(equipment_button, "equipment")

	if GDM.notification_manager.is_notification_active(NotificationManagerScript.NOTIFICATION_TYPE.INVENTORY) or GDM.notification_manager.is_notification_active(NotificationManagerScript.NOTIFICATION_TYPE.CONSUMABLES):
		menu_panel.show()
		game_menu_button.hide()
		_start_pulse(inventory_button, "inventory")

func update_button_alerts() -> void:
	# Skilltree button logic
	var skilltree_is_yellow = false
	if GDM.player.levelup:
		skilltree_button.modulate = Color.YELLOW
		skilltree_is_yellow = true
		_start_pulse(skilltree_button, "skilltree")
	else:
		skilltree_button.modulate = Color.WHITE
		_stop_pulse("skilltree")

	# Combined stats button logic
	var unlocked_abilities_count = GDM.player.unlocked_abilities.filter(func(a): return a != null).size()
	var has_free_slot: bool = get_used_slots() < min(5, unlocked_abilities_count)
	var combined_stats_is_yellow = false
	if has_free_slot:
		combined_stats_button.modulate = Color.YELLOW
		combined_stats_is_yellow = true
		_start_pulse(combined_stats_button, "combined_stats")
	else:
		combined_stats_button.modulate = Color.WHITE
		_stop_pulse("combined_stats")

	# Show menu_panel if either button is yellow
	if skilltree_is_yellow or combined_stats_is_yellow:
		menu_panel.show()
		game_menu_button.hide()

# Pulse helpers
func _start_pulse(button: TextureButton, which: String) -> void:
	var pulse_color1 = Color(1, 1, 0, 1) # normal yellow
	var pulse_color2 = Color(1, 1, 0.5, 1) # lighter yellow
	var tween: Tween = null
	if which == "skilltree":
		if skilltree_tween and skilltree_tween.is_running():
			return
		skilltree_tween = create_tween()
		tween = skilltree_tween
	elif which == "combined_stats":
		if combined_stats_tween and combined_stats_tween.is_running():
			return
		combined_stats_tween = create_tween()
		tween = combined_stats_tween
	elif which == "quests":
		if quests_tween and quests_tween.is_running():
			return
		quests_tween = create_tween()
		tween = quests_tween
	elif which == "equipment":
		if equipment_tween and equipment_tween.is_running():
			return
		equipment_tween = create_tween()
		tween = equipment_tween
	elif which == "inventory":
		if inventory_tween and inventory_tween.is_running():
			return
		inventory_tween = create_tween()
		tween = inventory_tween
	else:
		return
	tween.set_loops()
	tween.tween_property(button, "modulate", pulse_color2, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(button, "modulate", pulse_color1, 0.5).set_trans(Tween.TRANS_SINE)

func _stop_pulse(which: String) -> void:
	if which == "skilltree" and skilltree_tween:
		skilltree_tween.kill()
		skilltree_tween = null
		skilltree_button.modulate = Color.WHITE
	elif which == "combined_stats" and combined_stats_tween:
		combined_stats_tween.kill()
		combined_stats_tween = null
		combined_stats_button.modulate = Color.WHITE
	elif which == "quests" and quests_tween:
		quests_tween.kill()
		quests_tween = null
		quests_button.modulate = Color.WHITE
	elif which == "equipment" and equipment_tween:
		equipment_tween.kill()
		equipment_tween = null
		equipment_button.modulate = Color.WHITE
	elif which == "inventory" and inventory_tween:
		inventory_tween.kill()
		inventory_tween = null
		inventory_button.modulate = Color.WHITE

func get_used_slots() -> int:
	var total = 0
	for i in GDM.player.abilities:
		if i:
			total += 1
	return total

func _on_game_menu_button_pressed() -> void:
	menu_panel.show()
	game_menu_button.hide()

func _on_hide_button_pressed() -> void:
	menu_panel.hide()
	game_menu_button.show()
