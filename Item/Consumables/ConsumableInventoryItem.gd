extends FW_InventoryItem

class_name FW_ConsumableInventoryItem

# Override _gui_input to handle right-click usage of consumables
# func _gui_input(event: InputEvent) -> void:
# 	if event is InputEventMouseButton and event.pressed:
# 		if event.button_index == MOUSE_BUTTON_RIGHT:
# 			_use_consumable()

func _use_consumable() -> void:
	var consumable = data as FW_Consumable
	if consumable and consumable.can_use():
		if consumable.use_consumable():
			# Successfully used - remove from inventory
			_consume_item()

func _consume_item() -> void:
	# Use player's method to properly remove from both inventory and slots
	if GDM.player and GDM.player.consume_item(data):
		# Remove the UI element
		queue_free()
