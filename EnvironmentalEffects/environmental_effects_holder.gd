extends Node2D

@onready var environment_tooltip: Panel = %environment_tooltip
@onready var environment_name: Label = %environment_name
@onready var environment_description: Label = %environment_description
@onready var environment_image: TextureRect = %environment_image

@export var prefab: PackedScene

func setup_environments() -> void:
	for e in GDM.current_info.environmental_effects:
		var env = prefab.instantiate()
		env.setup(e)
		%environment_holder.add_child(env)

func _ready() -> void:
	setup_environments()
	EventBus.environment_clicked.connect(show_tooltip)

func show_tooltip(d: FW_EnvironmentalEffect) -> void:
	# Check if popup coordinator is available
	if not GDM.game_manager or not GDM.game_manager.popup_coordinator:
		push_warning("PopupCoordinator not available in GameManager")
		return

	# Setup the tooltip panel with the environmental effect data
	environment_name.text = d.name
	environment_description.text = d.description + "\n" + FW_Utils.format_effects(d.effects)
	environment_image.texture = d.texture

	# Show via coordinator (handles toggle behavior automatically)
	GDM.game_manager.popup_coordinator.show_popup(
		environment_tooltip,
		"environmental_effect",
		{"effect": d}
	)
