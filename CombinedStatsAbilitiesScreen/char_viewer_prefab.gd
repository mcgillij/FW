extends Panel

@onready var character_description: Label = %character_description
@onready var character_name: Label = %character_name
@onready var affinity_label: Label = %affinity_label
@onready var character_effects: Label = %character_effects
@onready var character_image: TextureRect = %character_image

@onready var red_affinity: MarginContainer = %red_affinity
@onready var blue_affinity: MarginContainer = %blue_affinity
@onready var green_affinity: MarginContainer = %green_affinity
@onready var orange_affinity: MarginContainer = %orange_affinity
@onready var pink_affinity: MarginContainer = %pink_affinity

@onready var ascension_level_label: Label = %ascension_level_label
@onready var ascension_level_value: Label = %ascension_level_value


func setup(char_res: FW_Character) -> void:
	show_hide_affinities(char_res)

	# Apply name color based on affinities. If there are no affinities,
	# fall back to the character's explicit color (if set), otherwise white.
	if char_res.affinities and not char_res.affinities.is_empty():
		character_name.self_modulate = FW_Colors.get_color_for_affinities(char_res.affinities)
	elif char_res.color:
		character_name.self_modulate = char_res.color
	else:
		character_name.self_modulate = Color(1,1,1)
	character_name.text = char_res.name
	character_image.texture = char_res.texture
	character_description.text = char_res.description
	var effects_text:= ""
	for e in char_res.effects.keys():
		if char_res.effects[e] is float:
			effects_text += e.capitalize() +": " + FW_Utils.to_percent(char_res.effects[e]) + "\n"
		else:
			effects_text += e.capitalize() +": " + str(char_res.effects[e]) + "\n"
	character_effects.text = effects_text
	var ascension_level := UnlockManager.get_ascension_level(char_res.name)
	if ascension_level > 0:
		ascension_level_label.visible = true
		ascension_level_value.text = str(ascension_level)
		ascension_level_value.visible = true

func show_hide_affinities(character: FW_Character) -> void:
	affinity_label.visible = true
	if !red_affinity:
		red_affinity = %red_affinity
	if !blue_affinity:
		blue_affinity = %blue_affinity
	if !green_affinity:
		green_affinity = %green_affinity
	if !orange_affinity:
		orange_affinity = %orange_affinity
	if !pink_affinity:
		pink_affinity = %pink_affinity

	var aff_list = [%red_affinity, %blue_affinity, %green_affinity, %orange_affinity, %pink_affinity]
	# turn them off first
	for a in aff_list:
		a.set_visible(false)
	#turn the right ones on
	for aff in character.affinities:
		match aff:
			FW_Ability.ABILITY_TYPES.Bark:
				red_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Alertness:
				blue_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Reflex:
				green_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Vigor:
				orange_affinity.set_visible(true)
			FW_Ability.ABILITY_TYPES.Enthusiasm:
				pink_affinity.set_visible(true)
