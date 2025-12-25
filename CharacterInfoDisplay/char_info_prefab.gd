extends Control

@onready var gold_label: Label = %gold_label
@onready var level_text: Label = %level_text
@onready var xp_bar: TextureProgressBar = %xp_bar
@onready var xp_bar_values: Label = %xp_bar_values
@onready var difficulty_label: Label = %difficulty_label
@onready var continue_value: Label = %continue_value

@onready var char_image: TextureRect = %char_image
@onready var char_name: Label = %char_name
@onready var char_job: Label = %char_job
@onready var stats_panel: Panel = %stats_panel

@onready var ascension_level_label: Label = %ascension_level_label

@onready var char_info_button: Button = %char_info_button
@onready var stats_panel_button: Button = %stats_panel_button

func setup() -> void:
	gold_label.text = str(GDM.player.gold) + " GP"
	GDM.level_manager.add_xp(0)
	xp_bar.value = GDM.level_manager.get_progress_to_next_level() * 100
	xp_bar_values.text = str(GDM.player.xp)
	level_text.text = str(GDM.player.current_level)
	difficulty_label.text = str(FW_Player.DIFFICULTY.find_key(GDM.player.difficulty))
	difficulty_label.self_modulate = FW_GameDifficulty.DIFFICULTY_MAPPING[GDM.player.difficulty].color
	char_image.texture = GDM.player.character.image
	char_name.text = GDM.player.character.name
	# Tint the name by affinities if available, otherwise fall back to character.color or white
	if GDM.player.character.affinities and not GDM.player.character.affinities.is_empty():
		char_name.self_modulate = FW_Colors.get_color_for_affinities(GDM.player.character.affinities)
	elif GDM.player.character.color:
		char_name.self_modulate = GDM.player.character.color
	else:
		char_name.self_modulate = Color(1,1,1)
		ascension_level_label.show()
		ascension_level_label.text = "Ascension: " + str(GDM.player.current_ascension_level)
	var pj_name := ""
	var pj_color := Color.WHITE
	if GDM.player and GDM.player.job and GDM.player.job.get("name") != null and str(GDM.player.job.name).to_lower() != "unassigned":
		pj_name = str(GDM.player.job.name)
		pj_color = FW_Utils.normalize_color(GDM.player.job.job_color) if GDM.player.job.get("job_color") != null else Color.WHITE
	char_job.text = pj_name
	char_job.self_modulate = pj_color

	if GDM.player.continues == -1: # unlimited value from CASUAL
		continue_value.text = "Unlimited"
	else:
		continue_value.text = str(GDM.player.continues)

func _on_char_info_button_pressed() -> void:
	char_info_button.hide()
	stats_panel.show()

func _on_stats_panel_button_pressed() -> void:
	char_info_button.show()
	stats_panel.hide()
