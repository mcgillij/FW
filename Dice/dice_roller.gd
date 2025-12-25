extends Control

class_name FW_DiceRoller

signal dice_roll_results

@onready var dice_button: TextureButton = %dice_button
@onready var die_1: Label = %die1
@onready var die_2: Label = %die2
@onready var result_label: Label = %result_label
@onready var merge_particles: CPUParticles2D = %merge_particles

var rolling := false

var ORIGINAL_X1:float
var ORIGINAL_Y1:float
var ORIGINAL_X2:float
var ORIGINAL_Y2:float

func _ready():
	ORIGINAL_X1 = die_1.position.x
	ORIGINAL_Y1 = die_1.position.y
	ORIGINAL_X2 = die_2.position.x
	ORIGINAL_Y2 = die_2.position.y
	die_1.text = ""
	die_2.text = ""
	# Outline settings
	die_1.add_theme_constant_override("outline_size", 4)
	die_2.add_theme_constant_override("outline_size", 4)
	die_1.add_theme_color_override("font_outline_color", Color.BLACK) # yellowish outline
	die_2.add_theme_color_override("font_outline_color", Color.BLACK)
	# Optional: set font color to white for contrast
	die_1.add_theme_color_override("font_color", Color.WHITE)
	die_2.add_theme_color_override("font_color", Color.WHITE)
	if dice_button:
		dice_button.pressed.connect(roll_dice)

func setup(dice_color: Color = Color.RED) -> void:
	if !dice_button:
		dice_button = %dice_button
	if dice_button:
		dice_button.modulate = dice_color

func roll_dice():
	# reset dice positions and visibility
	die_1.position = Vector2(ORIGINAL_X1, ORIGINAL_Y1)
	die_2.position = Vector2(ORIGINAL_X2, ORIGINAL_Y2)
	die_1.visible = true
	die_2.visible = true
	die_1.scale = Vector2(1, 1)
	die_2.scale = Vector2(1, 1)
	result_label.visible = false

	if rolling:
		return
	rolling = true

	await animate_dice_roll()
	rolling = false

func animate_dice_roll() -> void:
	var roll_time := 1.0
	var interval := 0.05
	var elapsed := 0.0
	SoundManager._play_random_dice_sound()
	while elapsed < roll_time:
		die_1.text = str(randi_range(0, 9) * 10).pad_zeros(2)
		die_2.text = str(randi_range(0, 9))
		# Shake effect
		die_1.position += Vector2(randf_range(-2,2), randf_range(-2,2))
		die_2.position += Vector2(randf_range(-2,2), randf_range(-2,2))
		await get_tree().create_timer(interval).timeout
		elapsed += interval
	# Reset position
	die_1.position = Vector2(ORIGINAL_X1, ORIGINAL_Y1)
	die_2.position = Vector2(ORIGINAL_X2, ORIGINAL_Y2)
	# Final result
	var tens = randi_range(0, 9) * 10
	var ones = randi_range(0, 9)
	die_1.text = str(tens).pad_zeros(2)
	die_2.text = str(ones)
	var result = tens + ones
	if tens == 0 and ones == 0:
		result = 100
	# Optionally emit a signal or call a callback here
	animate_result_flash()
	animate_result_merge(result)
	emit_signal("dice_roll_results", result)

func animate_result_flash():
	var tween = create_tween()
	tween.tween_property(die_1, "scale", Vector2(1.5, 1.5), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(die_1, "scale", Vector2(1, 1), 0.1)
	tween.tween_property(die_2, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(die_2, "scale", Vector2(1, 1), 0.1)

func animate_result_merge(result: int):
	result_label.text = ""
	result_label.visible = true
	result_label.modulate = Color(1, 1, 1, 0) # Start invisible

	var tween = create_tween()
	# Animate dice labels moving to result_label position and shrinking
	tween.tween_property(die_1, "position", result_label.position, 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(die_2, "position", result_label.position, 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(die_1, "scale", Vector2(0.5, 0.5), 0.3)
	tween.parallel().tween_property(die_2, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_callback(Callable(self, "_on_merge_complete").bind(result))

func _on_merge_complete(result: int):
	die_1.visible = false
	die_2.visible = false
	result_label.text = str(result)
	merge_particles.emitting = false # Reset in case it's still playing
	merge_particles.emitting = true
	SoundManager._play_random_sound()
	var tween = create_tween()
	tween.tween_property(result_label, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_property(result_label, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(result_label, "scale", Vector2(1, 1), 0.15)
