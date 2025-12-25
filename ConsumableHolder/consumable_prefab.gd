extends TextureButton

var data: FW_Consumable
var is_usable: bool = false

# Reference to the particle effect that should be a child node in the scene
@onready var use_particles: CPUParticles2D = %UseParticles

# Store the current hover tween to prevent overlapping animations
var hover_tween: Tween = null

func setup(d: FW_Consumable) -> void:
	data = d

func _ready() -> void:
	texture_normal = data.texture
	_update_visual_state()

	# Connect to consumable used signal to play effect
	EventBus.consumable_used.connect(_on_consumable_used)

	# Connect mouse hover signals for juicy effects
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_consumable_used(used_consumable: FW_Consumable) -> void:
	# Check if this is the consumable that was used
	if used_consumable == data:
		play_use_effect()

func play_use_effect() -> void:
	FW_Debug.debug_log(["Playing use effect for consumable: %s" % data.name])
	# Create effects on the parent so they persist after this node is destroyed
	create_persistent_effects()
	_play_use_sound()

func create_persistent_effects() -> void:
	# Get the parent container to attach persistent effects
	var parent_container = get_parent()
	if not parent_container:
		FW_Debug.debug_log(["No parent container found!"])
		return
	# Create persistent particle effect
	if use_particles:
		create_persistent_particles(parent_container)

func create_persistent_particles(parent_container: Node) -> void:
	# Clone the particle system to the parent
	var persistent_particles = use_particles.duplicate()
	parent_container.add_child(persistent_particles)

	# Position it correctly relative to parent
	persistent_particles.global_position = use_particles.global_position

	FW_Debug.debug_log(["Created persistent particle effect"])

	# Start the effect
	persistent_particles.restart()
	persistent_particles.emitting = true

	# Clean up after particle lifetime
	var cleanup_timer = Timer.new()
	parent_container.add_child(cleanup_timer)
	cleanup_timer.wait_time = persistent_particles.lifetime + 1.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(persistent_particles):
			persistent_particles.queue_free()
		cleanup_timer.queue_free()
	)
	cleanup_timer.start()

func _play_use_sound() -> void:
	pass # TODO: FW_Consumable sound (one each, or one for all?)

# Mouse hover effects for extra juice
func _on_mouse_entered() -> void:
	if not is_usable:
		return

	# Kill any existing tween to prevent overlapping animations
	if hover_tween and hover_tween.is_running():
		hover_tween.kill()

	# Store original values
	var original_scale = scale

	# Pop effect - scale up and rotate slightly to the right (positive rotation)
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_ease(Tween.EASE_OUT)
	hover_tween.set_trans(Tween.TRANS_BACK)

	# Scale up with overshoot
	hover_tween.tween_property(self, "scale", original_scale * 1.15, 0.2)

	# Rotate slightly to the right (10 degrees)
	hover_tween.tween_property(self, "rotation", deg_to_rad(8), 0.2)

	# Much more dramatic glow effect - bright golden glow
	hover_tween.tween_property(self, "self_modulate", Color(2.0, 1.8, 0.5, 1.0), 0.15)

func _on_mouse_exited() -> void:
	if not is_usable:
		return

	# Kill any existing tween to prevent overlapping animations
	if hover_tween and hover_tween.is_running():
		hover_tween.kill()

	# Smooth return to original state
	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.set_ease(Tween.EASE_IN_OUT)
	hover_tween.set_trans(Tween.TRANS_QUART)

	# Return to normal scale and rotation
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	hover_tween.tween_property(self, "rotation", 0.0, 0.15)
	hover_tween.tween_property(self, "self_modulate", Color.WHITE, 0.1)

func set_usable(usable: bool) -> void:
	is_usable = usable
	_update_visual_state()

func _update_visual_state() -> void:
	# Update cursor and visual feedback based on usability
	if is_usable:
		modulate = Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		modulate = Color(0.6, 0.6, 0.6, 1.0)  # Grayed out
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _on_pressed() -> void:
	if is_usable:
		FW_Debug.debug_log(["Pressed consumable: %s" % data.name])
		EventBus.consumable_clicked.emit(data)
	else:
		# Maybe show a "Not your turn" message
		EventBus.publish_combat_log.emit("Consumables can only be used during your turn!")
