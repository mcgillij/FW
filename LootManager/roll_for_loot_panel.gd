extends Control

@onready var luck_value: Label = %luck_value
@onready var check_result_label: Label = %check_result_label
@onready var target_number_label: Label = %target_number_label
@onready var result_value: Label = %result_value
@onready var roll_button: TextureButton = %roll_button

var target_number: int
var luck_bonus: int

const success_string := "Success!"
const failure_string := "Fail!"
var final_angle = 45


var pulse_duration: float = 1.5
# The minimum thickness of the outline during the pulse.
var min_thickness: float = 4.0
# The maximum thickness of the outline during the pulse.
var max_thickness: float = 20.0
# The first color for the outline gradient.
var color1: Color = Color("ffff00") # Yellow
# The second color for the outline gradient.
var color2: Color = Color("ff00ff") # Magenta

func _ready() -> void:
	EventBus.dice_roll_result.connect(_on_dice_roll_results)

func setup(monster: FW_Monster_Resource) -> void:
	roll_button.material.set_shader_parameter("allow_out_of_bounds", false)
	var _tween = create_tween().set_loops()
	_tween.set_trans(Tween.TRANS_SINE) # Use a sine wave for a smooth pulse

	# Chain the animations for a full pulse cycle
	_tween.tween_property(roll_button.material, "shader_parameter/outline_thickness", max_thickness, pulse_duration / 2.0)
	_tween.tween_property(roll_button.material, "shader_parameter/outline_color", color2, pulse_duration / 2.0)
	_tween.tween_property(roll_button.material, "shader_parameter/outline_thickness", min_thickness, pulse_duration / 2.0)
	_tween.tween_property(roll_button.material, "shader_parameter/outline_color", color1, pulse_duration / 2.0)

	var monster_diff = FW_Utils.translate_monster_type_to_diff(monster)
	target_number = FW_Utils.get_difficulty(monster_diff)
	luck_bonus = int(GDM.player.stats.get_stat("luck"))
	#roll_button.self_modulate = Color.YELLOW
	luck_value.text = str(luck_bonus)
	target_number_label.text = str(target_number)

func show_roll_result(success: bool) -> void:
	check_result_label.modulate = Color(1, 1, 1, 0) # Start invisible
	check_result_label.scale = Vector2(0.5, 0.5)    # Start small
	check_result_label.rotation_degrees = randf_range(-30, 30) # Random angle

	if success:
		check_result_label.text = self.success_string
		check_result_label.self_modulate = Color.GREEN
		final_angle = randf_range(10, 45)
		SoundManager._play_random_positive_sound()
	else:
		check_result_label.text = self.failure_string
		check_result_label.self_modulate = Color.RED
		final_angle = randf_range(-45, -10)
		SoundManager._play_random_negative_sound()

	check_result_label.show()
	var tween = create_tween()
	tween.tween_property(check_result_label, "modulate", Color(1, 1, 1, 1), 0.25).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(check_result_label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(check_result_label, "rotation_degrees", final_angle, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(check_result_label, "scale", Vector2(1, 1), 0.1)
	# Optional: fade out after a delay
	tween.tween_interval(1.0)
	tween.tween_property(check_result_label, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_callback(func():
		if success:
			EventBus.roll_won.emit()
		else:
			EventBus.roll_lost.emit()
	)

func _on_dice_roll_results(result: int) -> void:
	result_value.text = " + " + str(result) + " = " +  str(result + luck_bonus)
	show_roll_result(result + luck_bonus > target_number)

func _on_roll_button_pressed() -> void:
	roll_button.disabled = true
	EventBus.show_dice.emit()
	EventBus.trigger_roll.emit("loot")
