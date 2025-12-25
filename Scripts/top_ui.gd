extends Panel

signal screen_shake

@export var goal_prefab: PackedScene

@onready var score_label: Label = %score_label
@onready var combo_label: Label = %combo_label
@onready var level_text: Label = %level_text
@onready var counter_label: Label = %counter_label
@onready var score_bar: TextureProgressBar = %score_bar
@onready var goal_container: HBoxContainer = %goal_container


var current_count: int = 0
var current_combo: int = 0

var default_font_size := 12
var font_size_multiplier := 1.1
var start_color := Color(1, 1, 0) # Yellow
var end_color := Color(1, 0, 0)   # Red
var max_combo_val := 15.0 # used for the steps the color gets darker in the transitions
var shake_intensity := 5.0
var shake_duration := 0.5
var combo_label_starting_position: Vector2

func _ready() -> void:
	combo_label_starting_position = combo_label.position

func make_goal(new_max: int, new_texture: Texture2D, new_value: String) -> void:
	var current = goal_prefab.instantiate()
	if !goal_container:
		goal_container = %goal_container
	goal_container.add_child(current)
	current.set_goal_values(new_max, new_texture, new_value)

func _on_grid_check_goal(value: String) -> void:
	for i in goal_container.get_child_count():
		goal_container.get_child(i).update_goal_values(value)

# seems like a good candidate to refactor all these into a single function that just
# passes the values down since they are all the same
func _on_ice_holder_break_ice(value: String, _location: Vector2) -> void:
	for i in goal_container.get_child_count():
		goal_container.get_child(i).update_goal_values(value)

func _on_concrete_holder_remove_concrete(value: String, _location: Vector2) -> void:
	for i in goal_container.get_child_count():
		goal_container.get_child(i).update_goal_values(value)

func _on_slime_holder_remove_slime(value: String, _location: Vector2) -> void:
	for i in goal_container.get_child_count():
		goal_container.get_child(i).update_goal_values(value)

func _on_lock_holder_remove_lock(value, _location) -> void:
	for i in goal_container.get_child_count():
		goal_container.get_child(i).update_goal_values(value)

func _on_heavy_concrete_holder_remove_heavy_concrete(value: String, _location: Vector2) -> void:
	for i in goal_container.get_child_count():
		goal_container.get_child(i).update_goal_values(value)

func _on_pink_slime_holder_remove_pink_slime(value: String, _location: Vector2) -> void:
	for i in goal_container.get_child_count():
		goal_container.get_child(i).update_goal_values(value)

func _on_game_manager_set_counter_info(current_counter: int) -> void:
	if !counter_label:
		counter_label = %counter_label
	counter_label.text = str(current_counter)

func _on_game_manager_set_score_info(new_max: int, new_current: int) -> void:
	if !score_bar:
		score_bar = %score_bar
	if !score_label:
		score_label = %score_label
	score_bar.max_value = new_max
	score_bar.value = new_current
	score_label.text = str(new_current)

func _on_game_manager_create_goal(new_max: int, new_texture: Texture2D, new_value: String) -> void:
	make_goal(new_max, new_texture, new_value)

func _on_game_manager_update_score_goal(current_score: int) -> void:
	for i in goal_container.get_child_count():
		goal_container.get_child(i).update_goal_values("points", current_score)

#func _on_game_manager_update_combo(combo: int) -> void:
	#if !combo_label:
		#combo_label = %combo_label
	#if combo <= 1:
		#combo_label.text = ""
	#else:
		#combo_label.text = "x" + str(combo)

func _on_game_manager_update_combo(combo: int) -> void:
	if !combo_label:
		combo_label = %combo_label
	# Reset combo display when the combo is too low
	if combo <= 1:
		combo_label.text = ""
		combo_label.add_theme_font_size_override("font_size", default_font_size)
		combo_label.add_theme_color_override("font_color", Color(1, 1, 1)) # Default white
		combo_label.global_position = combo_label_starting_position
		return
	# Update combo text
	combo_label.text = "x" + str(combo)
	# Tween setup
	var tween = get_tree().create_tween()
	var font_size = int(default_font_size * (font_size_multiplier * combo))
	# Scale animation
	tween.tween_property(
		combo_label,
		"theme_override_font_sizes/font_size",
		font_size,
		0.1 # length
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# Shake animation
	for i in range(int(shake_duration / 0.05)): # Create a sequence of random offsets
		var random_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		tween.tween_callback(
			Callable(_set_label_position.bind(Vector2(241, 40) + random_offset))
		).set_delay(i * 0.05)
	tween.tween_callback(Callable(_set_label_position.bind(combo_label_starting_position)))

	# Pop scale animation
	tween.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_label, "scale", Vector2(1, 1), 0.08).set_delay(0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Outline effect for high combos
	if combo >= int(max_combo_val * 0.7):
		combo_label.add_theme_color_override("font_outline_color", Color(1, 1, 0))
		combo_label.add_theme_constant_override("outline_size", 2)
	else:
		combo_label.add_theme_constant_override("outline_size", 0)

	# Interpolate color
	var t = clamp(float(combo) / max_combo_val, 0.0, 1.0)
	var interpolated_color = Color(
		lerp(start_color.r, end_color.r, t),
		lerp(start_color.g, end_color.g, t),
		lerp(start_color.b, end_color.b, t)
	)
	combo_label.add_theme_color_override("font_color", interpolated_color)

	# Emit screen shake signal if combo is high enough
	if combo > GDM.screenshake_num:
		emit_signal("screen_shake")

# Helper function for setting label position during shake
func _set_label_position(pos: Vector2) -> void:
	combo_label.global_position = pos

func _on_game_manager_set_level(level: int) -> void:
	if !level_text:
		level_text = %level_text
	level_text.text = str(level)
