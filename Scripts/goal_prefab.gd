extends TextureRect

var current_number: int = 0
var max_value: int
var goal_value: String = ""
var goal_texture: Texture2D

@onready var goal_label: Label = %goal_label
@onready var goal_image: TextureRect = %goal_image

func set_goal_values(new_max: int, new_texture: Texture2D, new_value: String) -> void:
    if !goal_image:
        goal_image = %goal_image
    if !goal_label:
        goal_label =  %goal_label
    goal_image.texture = new_texture
    max_value = new_max
    goal_value = new_value
    goal_label.text = str(current_number) + "/" + str(max_value)

func update_goal_values(goal_type: String, amount: int = 1) -> void:
    if goal_type == goal_value and goal_type != "points":
        current_number += amount
    elif goal_type == goal_value and goal_type == "points":
        current_number = amount

    if current_number >= max_value:
        goal_label.text = str(max_value) + "/" + str(max_value)
        if goal_label.self_modulate != Color.GREEN:
            goal_label.self_modulate = Color.GREEN
    else:
        goal_label.text = str(current_number) + "/" + str(max_value)
        if goal_label.self_modulate != Color.WHITE:
            goal_label.self_modulate = Color.WHITE
        if goal_type == goal_value:
            var tween = create_tween()
            tween.tween_property(goal_label, "self_modulate", Color.DEEP_SKY_BLUE, 0.5)
            tween.tween_property(goal_label, "self_modulate", Color.WHITE, 0.5).set_delay(0.5)
