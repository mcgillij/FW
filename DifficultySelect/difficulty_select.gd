extends CanvasLayer

@onready var difficulty_container: VBoxContainer = %difficulty_container
@onready var save_slot_container: VBoxContainer = %save_slot_container
@onready var history_button: Button = %history_button

@export var save_slot_prefab: PackedScene
@export var difficulty_prefab: PackedScene
@export var parallax_bg: PackedScene
@export var start_new_run: PackedScene

@onready var game_seed_value: Label = %game_seed_value

var existing_save: bool = false
var selected_difficulty: FW_Player.DIFFICULTY
var save_deleted_this_session: bool = false  # Track if save was deleted in this session

func _ready() -> void:
	SoundManager.wire_up_all_buttons()
	clear_save_slot()
	var bg = parallax_bg.instantiate()
	add_child(bg)
	# Check if save exists AND we haven't deleted it in this session
	# Also verify the loaded player is in a valid state (has character data)
	if savegame_exists() and not save_deleted_this_session:
		existing_save = true
		GDM.load_player() # Only load if a save exists
		GDM.load_worldstate()
		# Double check that the loaded player actually has valid data
		if GDM.player and GDM.player.character:
			var current_save = save_slot_prefab.instantiate()
			save_slot_container.add_child(current_save)
			current_save.setup(GDM.player)
			var start = start_new_run.instantiate()
			difficulty_container.add_child(start)
			start.start_new_run.connect(_on_start_new_run)
		else:
			# Player exists but no character - treat as new game
			existing_save = false
			save_deleted_this_session = true  # Mark as if deleted to prevent reload
			var current_save = save_slot_prefab.instantiate()
			save_slot_container.add_child(current_save)
			current_save.setup(GDM.player)
			setup_difficulties()
	else:
		existing_save = false
		var current_save = save_slot_prefab.instantiate()
		save_slot_container.add_child(current_save)
		current_save.setup(GDM.player)
		setup_difficulties()
	game_seed_value.text = "World Seed: " + str(GDM.current_run_seed)

func clear_save_slot() -> void:
	for c in save_slot_container.get_children():
		c.queue_free()

func savegame_exists() -> bool:
	return FileAccess.file_exists(GDM.save_path_vs)

func setup_difficulties() -> void:
	# setup difficulty selectors
	for i in FW_Player.DIFFICULTY.values():
		var d = difficulty_prefab.instantiate()
		difficulty_container.add_child(d)
		d.setup(i)
		d.difficulty_selected.connect(_on_difficulty_selected) # Connect the signal here

func _on_start_new_run() -> void:
	# Remove old UI
	SoundManager._all_button_sound()
	for c in difficulty_container.get_children():
		c.queue_free()
	clear_save_slot()
	setup_difficulties()

func _on_difficulty_selected(difficulty: FW_Player.DIFFICULTY) -> void:
	SoundManager._all_button_sound()
	selected_difficulty = difficulty
	if existing_save:
		$confirmation_screen_standalone.slide_in()
	else:
		_start_new_game_with_difficulty()

func _on_back_button_pressed() -> void:
	ScreenRotator.change_scene("res://Scenes/game_menu2.tscn")

func _on_confirmation_screen_standalone_confirm_button_pressed() -> void:
	clear_save_slot()
	GDM.delete_vs_save_data()
	save_deleted_this_session = true  # Mark that save was deleted in this session

	# Refresh PvP cache for new game (same as game over)
	var _net := get_node("/root/NetworkUtils")
	if _net.should_use_network():
		FW_PvPCache.refresh_for_new_game()

	_start_new_game_with_difficulty()

func _start_new_game_with_difficulty() -> void:
	# Create a new player with the selected difficulty
	GDM.player = FW_Player.new([], 0, 1, 0, null, [], selected_difficulty)
	GDM.player.continues = FW_GameDifficulty.DIFFICULTY_MAPPING[selected_difficulty].continues
	GDM.player.setup()
	GDM.setup_worldstate()
	GDM.vs_save()
	ScreenRotator.change_scene("res://CharacterSelect/character_select_standalone.tscn")

func _on_history_button_pressed() -> void:
	$HistoryView.setup()
	$HistoryView.slide_in()
