extends Panel

class_name FW_AbilityDisplayPrefab

@onready var ability_container: VBoxContainer = %ability_container

func make_ability_stats(ability_array: Array[FW_Ability]) -> void:
	if !ability_container:
		ability_container = %ability_container
	for ability in ability_array:
		for ability_stat in GDM.tracker.ability_log.keys():
			if ability.name == ability_stat:
				var hbox = HBoxContainer.new()
				var t_rect = TextureRect.new()
				var ability_label = Label.new()
				ability_label.text = str(GDM.tracker.ability_log[ability_stat])
				t_rect.texture = ability.texture
				t_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				t_rect.stretch_mode = TextureRect.STRETCH_SCALE
				t_rect.custom_minimum_size = Vector2(32, 32)
				hbox.add_child(t_rect)
				hbox.add_child(ability_label)
				ability_container.add_child(hbox)
