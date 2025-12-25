extends Control

@onready var skill_name_label: Label = %skill_name_label
@onready var base_value: Label = %base_value
@onready var equipment_image: TextureRect = %equipment_image
@onready var equipment_value: Label = %equipment_value

@onready var total_value: Label = %total_value
@onready var job_value: Label = %job_value
@onready var skill_description: RichTextLabel = %skill_description

const SKILL_DESC = {
	"affinity_damage_bonus": "Bonus damage from matching tiles of the same color as your affinitiess",
	"hp": "Hit points, your life!",
	"shields": "Protective layer, that prevents damage in most cases",
	"critical_strike_chance": "Percentage chance to strike a critical hit",
	"critical_strike_multiplier": "Multiplier for when you do critical damage",
	"evasion_chance": "Percentage chance to completely avoid damage",
	"red_mana_bonus": "Bonus mana gained",
	"blue_mana_bonus": "Bonus mana gained",
	"green_mana_bonus": "Bonus mana gained",
	"orange_mana_bonus": "Bonus mana gained",
	"pink_mana_bonus": "Bonus mana gained",
	"red_mana_max": "Bonus max mana cap",
	"blue_mana_max": "Bonus max mana cap",
	"green_mana_max": "Bonus max mana cap",
	"orange_mana_max": "Bonus max mana cap",
	"pink_mana_max": "Bonus max mana cap",
	"bomb_tile_bonus": "Extra damage when matching bomb tiles!",
	"cooldown_reduction": "Lowers the cooldown on abilities",
	"tenacity": "Reduce damage from bombs used against you",
	"luck": "Increased item rarity and drop-rate",
	"shield_recovery": "Beginning of turn shields gained",
	"lifesteal": "Percentage of damage converted to hp",
	"damage_resistance": "Percentage of damage reduction",
	"extra_consumable_slots": "Bonus consumable slots available"
}

const equipment_image_texture = preload("res://Equipment/Images/harness_armor.png")
func setup(skill_name: String) -> void:
	equipment_image.texture = equipment_image_texture
	skill_name_label.text = skill_name.capitalize()
	skill_description.text = SKILL_DESC.get(skill_name.to_lower())
	if skill_name in GDM.player.stats.INT_STATS:
		base_value.text = str(int(GDM.player.stats.get_base_stat(skill_name)))
		equipment_value.text = str(int(GDM.player.stats.get_stat_equipment(skill_name)))
		job_value.text = str(int(GDM.player.stats.get_stat_job(skill_name)))
		total_value.text = str(int(GDM.player.stats.get_stat(skill_name)))
	else:
		#var Utils = load("res://Scripts/FW_Utils.gd")
		base_value.text = FW_Utils.to_percent(GDM.player.stats.get_base_stat(skill_name))
		equipment_value.text = FW_Utils.to_percent(GDM.player.stats.get_stat_equipment(skill_name))
		job_value.text = FW_Utils.to_percent(GDM.player.stats.get_stat_job(skill_name))
		total_value.text = FW_Utils.to_percent(GDM.player.stats.get_stat(skill_name))
