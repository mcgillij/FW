extends Node2D

var shader_values = FW_Utils.ShaderValues.new()
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    $CPUParticles2D.finished.connect(queue_free)
    $CPUParticles2D.emitting = true

func _process(delta: float) -> void:
    shader_values.muck_with_shader_values(delta, $CPUParticles2D)
