extends Node

class_name FW_CombatLogManager

const LOG_FILE_PATH := "user://save/combat_log.txt"

func append_log_to_file(text: String) -> void:
	if !ConfigManager.combat_log_enabled:
		return

	# Ensure the file exists
	if not FileAccess.file_exists(LOG_FILE_PATH):
		var create_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
		if create_file:
			create_file.close()

	# Now open for read/write and append
	var file := FileAccess.open(LOG_FILE_PATH, FileAccess.READ_WRITE)
	if file:
		file.seek_end() # Move to end for appending
		file.store_line(text)
		file.close()

# Reference to the RichTextLabel
var rich_text_label: RichTextLabel
var mana_colors: Dictionary = {
	"green": "[color=#50fa7b]",
	"red": "[color=#ff5555]",
	"blue": "[color=#6272a4]",
	"orange": "[color=#ffb86c]",
	"pink": "[color=#ff79c6]"
}

var mana_to_stat: Dictionary = {
	"green": "Reflex",
	"red": "Bark",
	"blue": "Alertness",
	"orange": "Vigor",
	"pink": "Enthusiasm"
}

func append_log(text: String):
	rich_text_label.append_text(text + "\n")
	append_log_to_file(text)

# Initialize the class with the RichTextLabel
func _init(rich_text_label_ref: RichTextLabel):
	rich_text_label = rich_text_label_ref

# Add text to the combat log
func add_text(text: String, color: Color = Color(1, 1, 1)):
	var bbcode_text = "[color=%s]%s[/color]\n" % [color.to_html(), text]
	rich_text_label.append_text(bbcode_text)
	append_log_to_file(bbcode_text)

# Add an image to the combat log
func add_image(image_resource: Texture):
	rich_text_label.add_image(image_resource, 20, 20)

# Add text with an image to the combat log
func add_text_with_image(text: String, image_resource: Texture, color: Color = Color(1, 1, 1)):
	add_image(image_resource)
	var bbcode_text = "[color=%s]%s[/color]\n" % [color.to_html(), text]
	rich_text_label.append_text(bbcode_text)
	append_log_to_file(bbcode_text)

func log_damage(damage: int, reason: String, character_name: String):
	var text = "[b]%s[/b] has done: %d %s" % [character_name, damage, reason]
	append_log(text)

func update_log_player_mana(mana: Dictionary, player_name: String):
	append_log(format_mana_text(mana, player_name))

func update_log_enemy_mana(mana: Dictionary, monster_name: String):
	append_log(format_mana_text(mana, monster_name))

func update_log_player_mana_bonus(mana: Dictionary, player_name: String):
	append_log(format_mana_text_bonus(mana, player_name))

func update_log_enemy_mana_drain(mana: Dictionary, drained_by: String, drained_from: String) -> void:
	append_log(format_mana_drain_text(mana, drained_by, drained_from))

func update_log_player_mana_drain(mana: Dictionary, drained_by: String, drained_from: String) -> void:
	append_log(format_mana_drain_text(mana, drained_by, drained_from))

func format_mana_text(mana: Dictionary, label: String, action: String = "gained") -> String:
	var formatted_text = "[b]%s[/b] %s " % [label, action]
	for mana_type in mana_colors.keys():
		var amount = 0
		if typeof(mana) == TYPE_DICTIONARY:
			amount = mana.get(mana_type, 0)
		if amount > 0:
			formatted_text += mana_colors[mana_type] + mana_type.capitalize() + ": " + str(amount) + "[/color] "
	return formatted_text.strip_edges()

func format_mana_drain_text(mana: Dictionary, drained_by: String, drained_from: String) -> String:
	var formatted_text = "[b]" + drained_by + "[/b] drained: "
	for mana_type in mana_colors.keys():
		var amount = 0
		if typeof(mana) == TYPE_DICTIONARY:
			amount = mana.get(mana_type, 0)
		if amount > 0:
			formatted_text += mana_colors[mana_type] + mana_type.capitalize() + ": " + str(amount) + "[/color] "
	var from = " from [b]" + drained_from + "[/b]"
	return formatted_text + from.strip_edges()

func format_mana_text_bonus(mana: Dictionary, label: String) -> String:
	var formatted_text = "[b]" + label + "[/b] gets: "

	for mana_type in mana_colors.keys():
		var amount = 0
		if typeof(mana) == TYPE_DICTIONARY:
			amount = mana.get(mana_type, 0)
		if amount > 0:
			formatted_text += mana_colors[mana_type] + str(amount) + "[/color] bonus from %s\n\t" % [mana_to_stat[mana_type]]

	return formatted_text.strip_edges()

# Clear the combat log
func clear_log():
	rich_text_label.clear()

# Record template-related warnings to a debug file for later inspection
func record_template_warning(msg: String) -> void:
	var debug_path := "user://save/template_warnings.txt"
	# Ensure directory/file exists
	if not FileAccess.file_exists(debug_path):
		var createf := FileAccess.open(debug_path, FileAccess.WRITE)
		if createf:
			createf.close()
	var df := FileAccess.open(debug_path, FileAccess.READ_WRITE)
	if df:
		df.seek_end()
		df.store_line(msg)
		df.close()
