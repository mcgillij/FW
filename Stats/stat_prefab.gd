extends Control

@onready var stat_image: TextureRect = %stat_image
@onready var stat_name_label: Label = %stat_name_label
@onready var base_value: Label = %base_value
@onready var equipment_image: TextureRect = %equipment_image
@onready var equipment_value: Label = %equipment_value
@onready var job_value: Label = %job_value
@onready var total_value: Label = %total_value
@onready var temp_value: Label = %temp_value
@onready var stat_description: RichTextLabel = %stat_description

const equipment_image_texture = preload("res://Equipment/Images/harness_armor.png")
func setup(stat: FW_Stat) -> void:
	equipment_image.texture = equipment_image_texture
	stat_image.texture = stat.stat_image
	stat_name_label.text = stat.stat_name
	stat_description.text = stat.description

	if stat.int_or_float == FW_Stat.STAT_TYPE.INT:
		base_value.text = str(int(GDM.player.stats.get_base_stat(stat.stat_name.to_lower())))
		equipment_value.text = str(int(GDM.player.stats.get_stat_equipment(stat.stat_name.to_lower())))
		job_value.text = str(int(GDM.player.stats.get_stat_job(stat.stat_name.to_lower())))
		temp_value.text = str(int(GDM.player.stats.get_stat_temporary(stat.stat_name.to_lower())))
		total_value.text = str(int(GDM.player.stats.get_stat(stat.stat_name.to_lower())))
	else:
		base_value.text = str(GDM.player.stats.get_stat_base(stat.stat_name.to_lower()))
		equipment_value.text = str(GDM.player.stats.get_stat_equipment(stat.stat_name.to_lower()))
		job_value.text = str(GDM.player.stats.get_stat_job(stat.stat_name.to_lower()))
		temp_value.text = str(GDM.player.stats.get_stat_temporary(stat.stat_name.to_lower()))
		total_value.text = str(GDM.player.stats.get_stat(stat.stat_name.to_lower()))
