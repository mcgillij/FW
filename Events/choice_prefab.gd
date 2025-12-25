extends Control

class_name FW_ChoicePrefab

@onready var choice_label: RichTextLabel = %choice_label
@onready var choice_button: Button = %choice_button

var button_choice := {}
var event: FW_EventResource

func setup(event_p: FW_EventResource, choice: Dictionary) -> void:
	button_choice = choice
	event = event_p
	var text = choice.get("text", choice.get("choice", "DEFAULT"))
	choice_label.bbcode_enabled = true
	choice_label.text = text
	var icon = choice.get("icon", "")
	if icon:
		choice_label.add_image(load(icon))  # Or handle icon differently

func _on_choice_button_pressed() -> void:
	choice_button.disabled = true
	var skill_check = button_choice.get("skill_check")
	if skill_check:
		# Ensure we emit a Resource for the skill check; some callers may mistakenly pass strings
		if skill_check is Resource:
			EventBus.choice_requires_skill_check.emit(self, skill_check)
		else:
			printerr("choice_prefab: skill_check is not a Resource: ", typeof(skill_check), skill_check)
			# Fallback to processing the event as a non-skill choice (treat as failed)
			EventBus.process_event_result.emit(event, button_choice, false)
	else:
		EventBus.process_event_result.emit(event, button_choice, true)
