extends CanvasLayer

@onready var legend_button: Button = %legend_button

@onready var scrub_button: Button = %scrub_button
@onready var grunt_button: Button = %grunt_button
@onready var elite_button: Button = %elite_button
@onready var boss_button: Button = %boss_button
@onready var player_button: Button = %player_button
@onready var event_button: Button = %event_button
@onready var blacksmith_button: Button = %blacksmith_button

@onready var close_button: Button = %close_button

@export var legend_button_panel: Panel
@export var tooltip_panel: Panel

@onready var title_label: Label = %title_label
@onready var desc_label: RichTextLabel = %desc_label

var popup_coordinator: FW_LevelSelectPopupCoordinator = null

func _ready() -> void:
	popup_coordinator = get_tree().root.find_child("LevelSelectPopupCoordinator", true, false)
	if popup_coordinator:
		popup_coordinator.popup_closed.connect(_on_popup_closed)

func _on_popup_closed(popup_type: String) -> void:
	if popup_type == "legend":
		tooltip_panel.hide()
		legend_button_panel.hide()
		legend_button.show()

func _on_legend_button_pressed() -> void:
	legend_button.hide()
	if popup_coordinator:
		popup_coordinator.show_popup(self, "legend")
	legend_button_panel.show()

func _on_grunt_button_pressed() -> void:
	tooltip_panel.hide()
	title_label.text = "Grunt"
	desc_label.text = "The tough guy, this guys much keener than his counterparts!"
	tooltip_panel.show()

func _on_elite_button_pressed() -> void:
	tooltip_panel.hide()
	title_label.text = "Elite"
	desc_label.text = "These mini-boss monsters, are very powerful and very smart!"
	tooltip_panel.show()

func _on_boss_button_pressed() -> void:
	tooltip_panel.hide()
	title_label.text = "Boss"
	desc_label.text = "'The Boss', these guys are serious biznes, also the leaders of the monsters."
	tooltip_panel.show()

func _on_player_button_pressed() -> void:
	tooltip_panel.hide()
	title_label.text = "Fallen Players"
	desc_label.text = "These are the fallen players, using their custom builds."
	tooltip_panel.show()

func _on_event_button_pressed() -> void:
	tooltip_panel.hide()
	title_label.text = "Events"
	desc_label.text = "Random events, sometimes treasure, sometimes traps, sometimes skills challenges."
	tooltip_panel.show()

func _on_blacksmith_button_pressed() -> void:
	tooltip_panel.hide()
	title_label.text = "Blacksmith"
	desc_label.text = "Buy or Sell gear, at the friendly blacksmith!"
	tooltip_panel.show()

func _on_close_button_pressed() -> void:
	if popup_coordinator:
		popup_coordinator.close_current_popup()
	else:
		tooltip_panel.hide()
		legend_button_panel.hide()
		legend_button.show()
