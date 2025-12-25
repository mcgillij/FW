extends CanvasLayer

var tooltip_out: bool = false
var popup_coordinator: Node = null

@onready var environment_tooltip: Panel = %environment_tooltip
@onready var environment_name: Label = %environment_name
@onready var environment_description: Label = %environment_description
@onready var environment_image: TextureRect = %environment_image

func _ready() -> void:
	# Find the popup coordinator in the scene
	_find_popup_coordinator()

	# Only connect to EventBus if we don't have a popup coordinator
	if not popup_coordinator:
		EventBus.environment_inspect.connect(show_tooltip)

func _find_popup_coordinator() -> void:
	"""Find the LevelSelectPopupCoordinator in the scene tree."""
	var root = get_tree().root
	popup_coordinator = root.find_child("LevelSelectPopupCoordinator", true, false)

func show_tooltip(d: FW_EnvironmentalEffect) -> void:
	if popup_coordinator:
		# Use popup coordinator system
		_show_popup_with_data(d)
	else:
		# Fallback to legacy tooltip system
		_show_legacy_tooltip(d)

func _show_popup_with_data(effect: FW_EnvironmentalEffect) -> void:
	"""Show popup using the coordinator system."""
	# Setup the tooltip content
	environment_name.text = effect.name
	environment_description.text = effect.description + "\n" + FW_Utils.format_effects(effect.effects)
	environment_image.texture = effect.texture

	# Center the tooltip in the viewport and make it visible
	_center_tooltip()
	environment_tooltip.visible = true

	# Show through popup coordinator
	popup_coordinator.show_popup(self, "environment", {"data": effect})

func _show_legacy_tooltip(d: FW_EnvironmentalEffect) -> void:
	"""Legacy tooltip system for backward compatibility."""
	if !tooltip_out:
		tooltip_out = true
		environment_name.text = d.name
		environment_description.text = d.description + "\n" + FW_Utils.format_effects(d.effects)
		environment_image.texture = d.texture
		%environment_tooltip.position = Vector2(100, 20)
	else:
		tooltip_out = false
		%environment_tooltip.position = Vector2(-525, -43)
	self.show()

func _center_tooltip() -> void:
	"""Center the environment tooltip in the viewport."""
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = environment_tooltip.size

	# Calculate centered position
	var centered_pos = (viewport_size - tooltip_size) / 2.0

	# Ensure position is not negative
	centered_pos.x = max(0, centered_pos.x)
	centered_pos.y = max(0, centered_pos.y)

	environment_tooltip.position = centered_pos

func _on_button_pressed() -> void:
	if popup_coordinator:
		# Use popup coordinator to close
		popup_coordinator.close_current_popup()
	else:
		# Legacy close
		tooltip_out = false
		environment_tooltip.position = Vector2(-525, -43)
		self.hide()
