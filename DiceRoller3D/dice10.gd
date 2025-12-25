extends RigidBody3D

signal roll_finished(value: int, die_type: dtype, roll_for: String)

enum dtype { D10, D100 }

@export var die_type:dtype
@onready var nodes = $Faces.get_children()

const ROLL_STRENGHT = 10
var start_pos: Vector3
var roll_for: String
@export var spin_multiplier: float = 0.125
@export var torque_impulse_scale: float = 0.4
const POWER_SCALE := 0.25

func _ready():
	sleeping = true
	freeze = true
	start_pos = global_position
	EventBus.trigger_roll.connect(trigger_roll)

#func _input(event):
	#if event.is_action_pressed("ui_accept"):
		#if sleeping:
			#_roll()

func trigger_roll(roll_for_p: String):
	roll_for = roll_for_p
	if sleeping:
		SoundManager._play_random_dice_sound()
		_roll()

func _roll():
	sleeping = false
	freeze = false

	global_position = start_pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	linear_velocity.y = randf_range(1.0, 2.0)

	# Random rotation
	transform.basis = Basis(Vector3.RIGHT, randf_range(0,2*PI)) * transform.basis
	transform.basis = Basis(Vector3.UP, randf_range(0,2*PI)) * transform.basis
	transform.basis = Basis(Vector3.FORWARD, randf_range(0,2*PI)) * transform.basis

	# Random throw impulse
	# Add a small upward component to the throw so it arcs nicely.
	var throw_vector = Vector3(randf_range(-1,1), randf_range(0.05,0.25), randf_range(-1,1)).normalized()
	# Increase angular velocity for more visible spin and add a small
	# torque impulse for chaotic tumbling.
	angular_velocity = throw_vector * (ROLL_STRENGHT * POWER_SCALE) / 2 * spin_multiplier
	apply_central_force(throw_vector * (ROLL_STRENGHT * POWER_SCALE))
	# Random torque to encourage spinning on all axes
	var torque_vec = Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)).normalized() * (ROLL_STRENGHT * POWER_SCALE * torque_impulse_scale * spin_multiplier)
	apply_torque_impulse(torque_vec)

func _on_sleeping_state_changed():
	if sleeping:
		var result = null
		# Find the topmost face marker
		for node in nodes:
			if result == null or result.global_transform.origin.y < node.global_transform.origin.y:
				result = node

		if result:
			# Create a decal to highlight the top face
			var decal = Decal.new()
			add_child(decal)

			# Position the decal slightly above the result face and orient it to project downwards
			decal.global_position = result.global_position + (Vector3.UP * 0.2)
			decal.look_at(result.global_position, Vector3.RIGHT)  # Specify up vector to avoid colinearity
			decal.size = Vector3(0.7, 0.7, 0.5)  # Adjust size as needed

			# Create a radial gradient texture for the decal's albedo
			var radial_gradient = GradientTexture2D.new()
			var gradient = Gradient.new()
			gradient.set_color(0, Color.WHITE)
			gradient.set_color(1, Color(1, 1, 1, 0))  # Fade to transparent
			radial_gradient.gradient = gradient
			radial_gradient.width = 64
			radial_gradient.height = 64
			radial_gradient.fill = GradientTexture2D.FILL_RADIAL
			decal.texture_albedo = radial_gradient

			# Set the decal's color and make it unshaded
			decal.modulate = Color(1, 1, 0, 0)  # Yellow, initially transparent

			# Use a tween to make the decal blink and then disappear
			var tween = create_tween().set_loops(3)
			tween.tween_property(decal, "modulate:a", 0.8, 0.25)
			tween.tween_property(decal, "modulate:a", 0.0, 0.25)

			# When the tween is finished, remove the decal from the scene
			tween.finished.connect(decal.queue_free)
			emit_signal("roll_finished", int(result.name.replace("D", "")), die_type, roll_for)
