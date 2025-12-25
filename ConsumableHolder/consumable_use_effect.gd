extends CPUParticles2D

# Simple but visible consumable use effect

func _ready() -> void:
	FW_Debug.debug_log(["Particle effect ready"])
	# Set up initial properties
	setup_particles()

func setup_particles() -> void:
	# Make sure the particles are very visible
	amount = 50
	lifetime = 2.0
	one_shot = true
	explosiveness = 1.0
	randomness = 0.3

	# Emission shape
	emission_shape = EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 20.0

	# Large, bright golden particles
	scale_amount_min = .5
	scale_amount_max = 1.0
	color = Color(1.0, 0.8, 0.1, 1.0)  # Bright golden

	# Upward burst with good spread
	direction = Vector2(0, -1)
	spread = 60.0
	initial_velocity_min = 100.0
	initial_velocity_max = 150.0

	# Physics for natural movement
	gravity = Vector2(0, 200)
	angular_velocity_min = -360.0
	angular_velocity_max = 360.0

	# Make sure emitting is off initially
	emitting = false

func play_effect() -> void:
	FW_Debug.debug_log(["Playing particle effect!"])

	# Make sure we're visible and setup
	visible = true
	show()

	# Re-setup particles to be extra sure
	setup_particles()

	# Start emitting
	FW_Debug.debug_log(["Setting emitting to true"])
	emitting = true

	# Add a bright flash effect
	add_flash_effect()

	# Add an immediate visible feedback
	add_immediate_visual()

func add_immediate_visual() -> void:
	# Create an immediate visual cue that's definitely visible
	var immediate_flash = ColorRect.new()
	get_parent().add_child(immediate_flash)

	# Position it over the button
	immediate_flash.size = Vector2(60, 60)
	immediate_flash.position = Vector2(-30, -30)
	immediate_flash.color = Color.YELLOW
	immediate_flash.z_index = 100  # Make sure it's on top

	FW_Debug.debug_log(["Added immediate visual flash"])

	# Quick flash animation
	var flash_tween = create_tween()
	flash_tween.tween_property(immediate_flash, "modulate:a", 0.0, 0.4)
	flash_tween.tween_callback(immediate_flash.queue_free)

func add_flash_effect() -> void:
	# Create a bright flash using a ColorRect
	var flash = ColorRect.new()
	add_child(flash)

	# Make it cover a large area around the button
	flash.size = Vector2(120, 120)
	flash.position = Vector2(-60, -60)  # Center it
	flash.color = Color(1.0, 0.8, 0.1, 0.8)  # Bright golden with transparency
	flash.z_index = 50

	FW_Debug.debug_log(["Added flash effect"])

	# Animate the flash
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.5)
	flash_tween.tween_callback(flash.queue_free)
