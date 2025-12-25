extends "res://Scripts/base_menu_panel.gd"

@onready var ascension_label: Label = %ascension_label
@onready var back_button: TextureButton = %back_button
@onready var ascension_rich_text: RichTextLabel = %ascension_rich_text

var _unlock_message: String = ""
var _default_rich_text: String = ""

func _ready() -> void:
	var victory_text = "Congratulations " + GDM.player.character.name + ", you have ascended, the world changes around you."
	ascension_label.text = victory_text
	_default_rich_text = ascension_rich_text.text
	if _unlock_message != "":
		ascension_rich_text.text = _unlock_message
	else:
		ascension_rich_text.text = _default_rich_text

func _on_back_button_pressed() -> void:
	back_button.disabled = true
	# Upload player data and refresh cache if network is enabled
	var _net := get_node("/root/NetworkUtils")
	if _net.should_use_network():
		FW_PlayerDataManager.upload_player_data(GDM.player)
		FW_PvPCache.refresh_for_new_game()
	_archive_run_and_exit()

func _archive_run_and_exit() -> void:
	"""Archive the run and exit to main menu"""
	# actual gameover write stats to disk, and clear save then back to the title for now
	FW_RunArchiver.archive_run("Ascended", "res://CreditsBG/CreditsAdventureMode_non_final_ending.tscn")

func set_act_unlock_message(message: String) -> void:
	_unlock_message = message
	if ascension_rich_text:
		ascension_rich_text.text = message

func clear_act_unlock_message() -> void:
	_unlock_message = ""
	if ascension_rich_text:
		ascension_rich_text.text = _default_rich_text
