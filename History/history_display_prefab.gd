extends Control

@onready var character_image: TextureRect = %character_image
@onready var character_name_label: Label = %character_name_label
@onready var char_level_label: Label = %char_level_label
@onready var gold_amount_label: Label = %gold_amount_label
@onready var floors_cleared_label: Label = %floors_cleared_label
@onready var monsters_defeated_label: Label = %monsters_defeated_label
@onready var xp_label: Label = %xp_label
@onready var difficulty_label: Label = %difficulty_label
@onready var job_name: Label = %job_name
@onready var date_value: Label = %date_value
@onready var game_version_value: Label = %game_version_value
@onready var cause_of_death_value: Label = %cause_of_death_value
@onready var ascension_level_value: Label = %ascension_level_value

func _gui_input(event):
	if (
		(event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT) or
		event is InputEventScreenDrag
	):
		var scroll = find_parent_scrollcontainer()
		if scroll:
			scroll.scroll_vertical -= event.relative.y

func find_parent_scrollcontainer():
	var node = get_parent()
	while node:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null

func setup(run_stats: Dictionary) -> void:
	# Prefer loading the actual Character resource saved at archive-time; this
	# lets us access affinities, name, and image without relying on stored
	# duplicates. Fall back to archived fields for older runs that predate
	# storing the resource path.
	var char_res_path: String = String(run_stats.get("character_resource_path", ""))
	var char_res: FW_Character = null
	if typeof(char_res_path) == TYPE_STRING and char_res_path.strip_edges() != "":
		var loaded := ResourceLoader.load(char_res_path)
		if loaded and loaded is FW_Character:
			char_res = loaded

	if char_res != null:
		character_image.texture = char_res.image
		character_name_label.text = char_res.name
		if char_res.affinities and not char_res.affinities.is_empty():
			character_name_label.self_modulate = FW_Colors.get_color_for_affinities(char_res.affinities)
		elif char_res.color:
			character_name_label.self_modulate = char_res.color
		else:
			character_name_label.self_modulate = Color(1,1,1)
	else:
		character_image.texture = load(run_stats.character_image_path)
		character_name_label.text = run_stats.character_name
		# Colorize the name by the saved affinities if present
		if run_stats.has("affinities") and run_stats.affinities != null and run_stats.affinities.size() > 0:
			character_name_label.self_modulate = FW_Colors.get_color_for_affinities(run_stats.affinities)
		else:
			# fall back to job color or default label color
			character_name_label.self_modulate = Color(1,1,1)
	job_name.text = "" if !run_stats.job_name else run_stats.job_name
	var color_to_use = FW_Utils.normalize_color(run_stats.job_color)
	job_name.self_modulate = color_to_use
	char_level_label.text = str(int(run_stats.level_reached))
	xp_label.text = str(int(run_stats.xp))
	gold_amount_label.text = str(int(run_stats.gold))
	gold_amount_label.self_modulate = Color.YELLOW
	floors_cleared_label.text = str(int(run_stats.floors_cleared))
	monsters_defeated_label.text = str(int(run_stats.monsters_encountered))
	difficulty_label.text = FW_GameDifficulty.DIFFICULTY_MAPPING[int(run_stats.difficulty)].name
	difficulty_label.self_modulate = FW_GameDifficulty.DIFFICULTY_MAPPING[int(run_stats.difficulty)].color
	var date_only = run_stats.datetime.substr(0, 10) # "YYYY-MM-DD"
	date_value.text = date_only
	game_version_value.text = run_stats.game_version
	cause_of_death_value.text = run_stats.cause_of_death
	ascension_level_value.text = str(int(run_stats.get("ascension_level", 0)))
