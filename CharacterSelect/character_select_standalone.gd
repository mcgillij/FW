extends "res://Scripts/base_menu_panel.gd"

@onready var char_view_holder: VBoxContainer = %char_view_holder
@onready var character_holder: GridContainer = %character_holder
@onready var forward_button: TextureButton = %forward_button
@onready var ascension_button: TextureButton = %ascension_button

@onready var choose_ascension_level_button: OptionButton = %choose_ascension_level_button

@export var char_view_prefab: PackedScene
@export var parallax_bg: PackedScene

var chars: Array[FW_Character]
var ascensions_unlocked = false

func _ready() -> void:
	SoundManager.wire_up_all_buttons()
	choose_ascension_level_button.hide()
	choose_ascension_level_button.clear()
	var ascension_signal := choose_ascension_level_button.item_selected
	var ascension_callable := Callable(self, "_on_ascension_level_selected")
	if not ascension_signal.is_connected(ascension_callable):
		ascension_signal.connect(ascension_callable)
	var bg = parallax_bg.instantiate()
	add_child(bg)
	var unlocked_characters = UnlockManager.get_unlocked_characters()
	for p in UnlockManager.achievement_to_character.values():
		var char_res = load(p)
		chars.append(char_res)
		var rect := TextureButton.new()
		rect.texture_normal = char_res.texture
		rect.ignore_texture_size = true
		rect.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(128, 128)
		var ascension_level := UnlockManager.get_ascension_level(char_res.name)
		if ascension_level > 0:
			ascensions_unlocked = true
			var ascension_label = Label.new()
			ascension_label.text = str(ascension_level)
			ascension_label.add_theme_font_override("font", load("res://fonts/clean.tres"))
			ascension_label.add_theme_font_size_override("font_size", 20)
			ascension_label.add_theme_constant_override("outline_size", 1)
			ascension_label.add_theme_color_override("font_outline_color", Color.BLACK)
			ascension_label.size = ascension_label.get_minimum_size()
			ascension_label.anchor_left = 1.0
			ascension_label.anchor_top = 1.0
			ascension_label.anchor_right = 1.0
			ascension_label.anchor_bottom = 1.0
			ascension_label.offset_left = -ascension_label.size.x - 10
			ascension_label.offset_top = -ascension_label.size.y - 5
			ascension_label.offset_right = 0.0
			ascension_label.offset_bottom = 0.0
			ascension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ascension_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			rect.add_child(ascension_label)

		# Dim if not unlocked
		if p in unlocked_characters:
			rect.modulate = Color(1, 1, 1, 1) # normal
			rect.pressed.connect(_on_char_button_clicked.bind(char_res))
			rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			rect.set_meta("unlocked", true)
			rect.set_meta("char_res", char_res)
		else:
			rect.self_modulate = Color(0.5, 0.5, 0.5, 1) # dimmed
			var locked_container = Control.new()
			locked_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			locked_container.anchor_left = 0.0
			locked_container.anchor_top = 0.0
			locked_container.anchor_right = 1.0
			locked_container.anchor_bottom = 1.0
			locked_container.offset_left = 0.0
			locked_container.offset_top = 0.0
			locked_container.offset_right = 0.0
			locked_container.offset_bottom = 0.0
			# Set pivot to center for correct rotation
			locked_container.pivot_offset = Vector2(rect.custom_minimum_size.x / 2, rect.custom_minimum_size.y / 2)
			locked_container.rotation_degrees = 45

			var locked_label = Label.new()
			locked_label.text = "Locked"
			locked_label.self_modulate = Color.ORANGE_RED
			locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			locked_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			locked_label.add_theme_font_size_override("font_size", 24)
			locked_label.add_theme_constant_override("outline_size", 2)
			locked_label.anchor_left = 0.0
			locked_label.anchor_top = 0.0
			locked_label.anchor_right = 1.0
			locked_label.anchor_bottom = 1.0
			locked_label.offset_left = 0.0
			locked_label.offset_top = 0.0
			locked_label.offset_right = 0.0
			locked_label.offset_bottom = 0.0
			locked_container.add_child(locked_label)
			rect.add_child(locked_container)
			rect.set_meta("unlocked", false)
			rect.set_meta("char_res", char_res)
		character_holder.add_child(rect)

	# After populating the character buttons, auto-select the first unlocked
	# character so the view shows immediately. Defer to ensure the buttons are
	# fully in-tree.
	if character_holder.get_child_count() > 0:
		call_deferred("_select_first_character")

	if ascensions_unlocked:
		ascension_button.show()
	self.slide_in()


func _select_first_character() -> void:
	if not is_inside_tree():
		return
	# Find the first unlocked button and simulate a click by calling the
	# existing handler with its associated character resource.
	for btn in character_holder.get_children():
		if typeof(btn) == TYPE_OBJECT and btn.has_meta("unlocked") and btn.get_meta("unlocked"):
			var char_res = btn.get_meta("char_res")
			if char_res:
				_on_char_button_clicked(char_res)
				return

func _on_char_button_clicked(char_res: FW_Character) -> void:
	SoundManager._all_button_sound()
	for c in char_view_holder.get_children():
		c.queue_free()
	var char_view = char_view_prefab.instantiate()
	char_view_holder.add_child(char_view)
	char_view.setup(char_res)

	# For roguelike new game: always reset abilities completely for fresh start
	GDM.player.character = char_res
	GDM.player.reset_abilities_for_new_character()
	_update_ascension_selector_for_character(char_res)

	forward_button.show()

func _on_back_button_pressed() -> void:
	GDM.player.character = null
	# If we're going back and there's no actual savegame file, make sure we don't show the old save
	if not FileAccess.file_exists(GDM.save_path_vs):
		# Reset the player to a fresh state since save was deleted
		GDM.player = FW_Player.new()
	ScreenRotator.change_scene("res://DifficultySelect/DifficultySelect.tscn")

func _on_forward_button_pressed() -> void:
	GDM.vs_save()
	ScreenRotator.change_scene("res://WorldMap/world_map.tscn")

func _on_ascension_button_pressed() -> void:
	$ascension_screen.slide_in()

func _on_ascension_screen_back_button() -> void:
	$ascension_screen.slide_out()

func _update_ascension_selector_for_character(char_res: FW_Character) -> void:
	var max_ascension_level := UnlockManager.get_ascension_level(char_res.name)
	choose_ascension_level_button.clear()
	if max_ascension_level <= 0:
		choose_ascension_level_button.hide()
		GDM.player.current_ascension_level = 0
		GDM.player.ascension_level_manually_selected = false
		return
	for ascension_level in range(max_ascension_level + 1):
		var label := "Ascension %d" % ascension_level
		choose_ascension_level_button.add_item(label, ascension_level)
	if not GDM.player.ascension_level_manually_selected:
		GDM.player.current_ascension_level = max_ascension_level
	else:
		GDM.player.current_ascension_level = clampi(GDM.player.current_ascension_level, 0, max_ascension_level)
	var target_level := GDM.player.current_ascension_level
	choose_ascension_level_button.select(target_level)
	choose_ascension_level_button.show()

func _on_ascension_level_selected(index: int) -> void:
	var selected_level := choose_ascension_level_button.get_item_id(index)
	if selected_level == -1:
		return
	GDM.player.current_ascension_level = selected_level
	GDM.player.ascension_level_manually_selected = true
