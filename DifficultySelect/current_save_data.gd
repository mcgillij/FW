extends Control

@onready var character_image: TextureRect = %character_image
@onready var character_name_label: Label = %character_name_label
@onready var char_level_label: Label = %char_level_label
@onready var gold_amount_label: Label = %gold_amount_label
@onready var floors_cleared_label: Label = %floors_cleared_label
@onready var monsters_defeated_label: Label = %monsters_defeated_label
@onready var xp_label: Label = %xp_label
@onready var no_data_panel: Panel = %no_data_panel
@onready var difficulty_label: Label = %difficulty_label
@onready var continues_value: Label = %continues_value
@onready var job_name: Label = %job_name
@onready var ascension_level_label: Label = %ascension_level_label
@onready var ascension_level_value: Label = %ascension_level_value

func setup(player: FW_Player) -> void:
	SoundManager.wire_up_all_buttons()
	if player and player.character:
		character_image.texture = player.character.image
		character_name_label.text = player.character.name
		# Tint the name by affinities if available, otherwise fall back to character.color
		if player.character.affinities and not player.character.affinities.is_empty():
			character_name_label.self_modulate = FW_Colors.get_color_for_affinities(player.character.affinities)
		elif player.character.color:
			character_name_label.self_modulate = player.character.color
		else:
			character_name_label.self_modulate = Color(1,1,1)
		# Hide placeholder 'Unassigned' names
		if player and player.job and player.job.get("name") != null and str(player.job.name).to_lower() != "unassigned":
			job_name.text = player.job.name
			var jc := Color.WHITE
			if player and player.job and player.job.job_color:
				jc = FW_Utils.normalize_color(player.job.job_color)
			job_name.set("theme_override_colors/font_color", jc)
		else:
			job_name.text = ""
		char_level_label.text = str(player.current_level)
		xp_label.text = str(player.xp)
		gold_amount_label.text = str(player.gold)
		gold_amount_label.self_modulate = Color.YELLOW
		floors_cleared_label.text = str(GDM.world_state.count_total_completed_levels())
		monsters_defeated_label.text = str(player.monster_kills.size())
		difficulty_label.text = FW_GameDifficulty.DIFFICULTY_MAPPING[player.difficulty].name
		difficulty_label.self_modulate = FW_GameDifficulty.DIFFICULTY_MAPPING[player.difficulty].color
		var ascension_level := player.current_ascension_level
		if ascension_level > 0:
			ascension_level_label.visible = true
			ascension_level_value.visible = true
			ascension_level_value.text = str(ascension_level)
			ascension_level_value.visible = true
		if player.continues == -1: # unlimited from casual
			continues_value.text = "Unlimited"
		else:
			continues_value.text = str(player.continues)
	else:
		no_data_panel.show()


func _on_continue_button_pressed() -> void:
	ScreenRotator.change_scene("res://WorldMap/world_map.tscn")
