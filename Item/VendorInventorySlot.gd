extends FW_InventorySlot
class_name FW_VendorInventorySlot

# Prevent dropping items into vendor slots
@warning_ignore("unused_parameter")
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Always return false to prevent dropping into vendor slots
	return false

@warning_ignore("unused_parameter")
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# Do nothing, as dropping is not allowed
	pass
