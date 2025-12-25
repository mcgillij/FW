extends RefCounted

class_name FW_NotificationManager

# Tracks which menu buttons should be highlighted/pulsing
var _active_notifications: Dictionary = {}

# Notification types
enum NOTIFICATION_TYPE {
	QUESTS,
	EQUIPMENT,
	INVENTORY,
	CONSUMABLES,
	SKILLTREE,
	COMBINED_STATS
}

func initialize():
	# Connect to EventBus signals - call this from GDM after EventBus is ready
	# Use call_deferred to ensure EventBus is fully ready
	call_deferred("_connect_signals")

func _connect_signals():
	if not EventBus:
		push_warning("EventBus not available for NotificationManager")
		return

	EventBus.quest_added.connect(_on_quest_event)
	EventBus.quest_goal_completed.connect(_on_quest_event)
	EventBus.quest_completed.connect(_on_quest_event)
	EventBus.equipment_added.connect(_on_equipment_added)
	EventBus.consumable_added.connect(_on_consumable_added)
	EventBus.inventory_item_added.connect(_on_inventory_item_added)

# Quest events - maintain existing behavior
func _on_quest_event(_quest, _goal = null) -> void:
	set_notification_active(NOTIFICATION_TYPE.QUESTS, true)

# Equipment events - new functionality
func _on_equipment_added(_equipment: FW_Equipment) -> void:
	set_notification_active(NOTIFICATION_TYPE.EQUIPMENT, true)
	# Also trigger inventory notification since equipment goes to inventory
	set_notification_active(NOTIFICATION_TYPE.INVENTORY, true)

# Consumable events - new functionality
func _on_consumable_added(_consumable) -> void:
	set_notification_active(NOTIFICATION_TYPE.CONSUMABLES, true)
	# Also trigger inventory notification since consumables go to inventory
	set_notification_active(NOTIFICATION_TYPE.INVENTORY, true)

# General inventory events
func _on_inventory_item_added(_item: FW_Item) -> void:
	set_notification_active(NOTIFICATION_TYPE.INVENTORY, true)

# Set notification state
func set_notification_active(type: NOTIFICATION_TYPE, active: bool) -> void:
	_active_notifications[type] = active

# Check if notification is active
func is_notification_active(type: NOTIFICATION_TYPE) -> bool:
	return _active_notifications.get(type, false)

# Clear specific notification (called when user views the respective screen)
func clear_notification(type: NOTIFICATION_TYPE) -> void:
	_active_notifications[type] = false

# Check if any notifications are active (for showing menu panel)
func has_active_notifications() -> bool:
	for active in _active_notifications.values():
		if active:
			return true
	return false

# Get all active notification types
func get_active_notifications() -> Array[NOTIFICATION_TYPE]:
	var active_types: Array[NOTIFICATION_TYPE] = []
	for type in _active_notifications.keys():
		if _active_notifications[type]:
			active_types.append(type)
	return active_types
