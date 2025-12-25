extends Panel

class_name FW_BuffViewerPrefab

@onready var buff_name_label: Label = %buff_name
@onready var buff_image: TextureRect = %buff_image
@onready var buff_desc: Label = %buff_desc
@onready var duration_value: Label = %duration_value
@onready var effect_strength_value: Label = %effect_strength_value
@onready var stat_target_value: Label = %stat_target_value
@onready var buff_type_value: Label = %buff_type_value
@onready var category_value: RichTextLabel = %category_value

func setup(buff: FW_Buff, template_vars: Dictionary = {}) -> void:
	if !buff_name_label:
		buff_name_label = %buff_name
	if !buff_image:
		buff_image = %buff_image
	if !buff_desc:
		buff_desc = %buff_desc
	if !duration_value:
		duration_value = %duration_value
	if !effect_strength_value:
		effect_strength_value = %effect_strength_value
	if !stat_target_value:
		stat_target_value = %stat_target_value
	if !buff_type_value:
		buff_type_value = %buff_type_value
	if !category_value:
		category_value = %category_value

	buff_name_label.text = buff.name
	buff_image.texture = buff.texture

	# Format the description from log_message if available
	var description = ""
	if buff.log_message and buff.log_message.strip_edges() != "":
		description = buff.get_formatted_log_message(template_vars)

	if description == "":
		# Fallback description
		var effect_desc = ""
		if buff.type == FW_Buff.buff_type.discrete:
			effect_desc = "Applies effect once when activated"
		elif buff.type == FW_Buff.buff_type.scaling:
			effect_desc = "Applies effect each turn"

		var target_desc = ""
		if buff.stat_target and buff.stat_target != "":
			target_desc = " to " + buff.stat_target.capitalize()

		description = effect_desc + target_desc

	buff_desc.text = description

	duration_value.text = str(buff.duration_left) + " / " + str(buff.duration) + " turns"

	# Format effect strength based on stat target
	var strength_text = ""
	if buff.effect_strength >= 1.0:
		strength_text = str(int(buff.effect_strength))
	else:
		strength_text = str(int(buff.effect_strength * 100)) + "%"
	effect_strength_value.text = strength_text

	# Show stat target if available
	if buff.stat_target and buff.stat_target != "":
		stat_target_value.text = buff.stat_target.capitalize()
	else:
		stat_target_value.text = "N/A"

	# Show buff type
	if buff.type == FW_Buff.buff_type.discrete:
		buff_type_value.text = "One-time"
	elif buff.type == FW_Buff.buff_type.scaling:
		buff_type_value.text = "Per Turn"

	# Show category with color coding
	if buff.category == FW_Buff.buff_category.beneficial:
		category_value.text = "[color=green]Beneficial[/color]"
	else:
		category_value.text = "[color=red]Harmful[/color]"
