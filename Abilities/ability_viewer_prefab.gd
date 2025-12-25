extends Panel

@onready var ability_name: Label = %ability_name
@onready var ability_image: TextureRect = %ability_image
@onready var ability_desc: Label = %ability_desc
@onready var ability_effect: Label = %ability_effect

const MANA_LABELS = "ability_panel_mana_cost"

func setup(ability: FW_Ability) -> void:
	ability_name.text = ability.name
	ability_image.texture = ability.texture
	ability_desc.text = ability.description
	var damage_and_cooldown = {
		"cooldown": ability.initial_cooldown
	}
	ability_effect.text = FW_Utils.format_effects(damage_and_cooldown)
	mana_labels(ability)

func mana_labels(ability: FW_Ability, can_see: bool = true) -> void:
	# iterate through all the booster groups / mana costs and set them
	var ml = get_tree().get_nodes_in_group(MANA_LABELS)
	for p in ml:
		for mana_color in ability.cost.keys():
			if p.name == mana_color:
				p.text = str(ability.cost[mana_color])
				p.get_parent().visible = can_see
