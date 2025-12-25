extends Node

## Script to create a pulsating outline effect on a TextureButton using a shader.
## Attach this to a Node in your scene and set the target_button path.

# The TextureButton to apply the effect to.
@export var target_button: NodePath
# The duration of one full pulse cycle (in seconds).
@export var pulse_duration: float = 2.0
# The minimum thickness of the outline during the pulse.
@export var min_thickness: float = 1.0
# The maximum thickness of the outline during the pulse.
@export var max_thickness: float = 6.0
# The first color for the outline gradient.
@export var color1: Color = Color("ffff00") # Yellow
# The second color for the outline gradient.
@export var color2: Color = Color("ff00ff") # Magenta

var _button: TextureButton
var _tween: Tween


func _ready():
	# Wait for the node to be ready before trying to get it
	await owner.ready
	_button = get_node_or_null(target_button)
	if not _button:
		push_error("PulsatingOutline: Target button node not found at path: %s" % target_button)
		return

	if not _button.material is ShaderMaterial:
		push_error("PulsatingOutline: The target button must have a ShaderMaterial.")
		return

	start_pulsing_effect()


func start_pulsing_effect():
	if _tween:
		_tween.kill()

	var material = _button.material as ShaderMaterial

	# Ensure the shader has the parameters we need to tween
	if not material.get_shader_parameter("outline_thickness") or not material.get_shader_parameter("outline_color"):
		push_error("PulsatingOutline: The assigned shader material is missing 'outline_thickness' or 'outline_color' uniforms.")
		return

	# Set initial values
	material.set_shader_parameter("outline_thickness", min_thickness)
	material.set_shader_parameter("outline_color", color1)

	# Create a looping tween for a continuous effect
	_tween = create_tween().set_loops()
	_tween.set_trans(Tween.TRANS_SINE) # Use a sine wave for a smooth pulse

	# Chain the animations for a full pulse cycle
	_tween.tween_property(material, "shader_parameter/outline_thickness", max_thickness, pulse_duration / 2.0)
	_tween.tween_property(material, "shader_parameter/outline_color", color2, pulse_duration / 2.0).as_relative()
	_tween.tween_property(material, "shader_parameter/outline_thickness", min_thickness, pulse_duration / 2.0)
	_tween.tween_property(material, "shader_parameter/outline_color", color1, pulse_duration / 2.0).as_relative()
