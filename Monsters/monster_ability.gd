extends TextureButton

@onready var blue: Label = %blue
@onready var red: Label = %red
@onready var green: Label = %green
@onready var orange: Label = %orange
@onready var pink: Label = %pink
@onready var blue_panel: Panel = %blue_panel
@onready var red_panel: Panel = %red_panel
@onready var green_panel: Panel = %green_panel
@onready var orange_panel: Panel = %orange_panel
@onready var pink_panel: Panel = %pink_panel
@onready var cooldown: Label = %cooldown
@onready var mana_array: Array = [%blue, %red, %green, %orange, %pink]
@onready var mana_panel_array: Array = [%blue_panel, %red_panel, %green_panel, %orange_panel, %pink_panel]
var ability_res: FW_Ability

func setup(ability: FW_Ability) -> void:
	if !blue:
		blue = %blue
	if !red:
		red = %red
	if !green:
		green = %green
	if !orange:
		orange = %orange
	if !pink:
		pink = %pink
	if mana_array == []:
		mana_array = [%blue, %red, %green, %orange, %pink]
	if mana_panel_array == []:
		mana_panel_array = [%blue_panel, %red_panel, %green_panel, %orange_panel, %pink_panel]
	if !cooldown:
		cooldown = %cooldown
	ability_res = ability
	texture_normal = ability.texture
	texture_disabled = ability.disabled_texture
	cooldown.visible = false
	for i in mana_array.size():
		for mana_color in ability.cost.keys():
			if mana_array[i].name == mana_color:
				mana_array[i].text = str(ability.cost[mana_color])
				mana_panel_array[i].visible = true
	update_cooldown(ability)

func update_cooldown(ability: FW_Ability) -> void:
	var cd = null
	if GDM.game_manager and GDM.game_manager.monster_cooldown_manager:
		cd = GDM.game_manager.monster_cooldown_manager.abilities.get(['monster', ability.name], null)
	if cd != null:
		disabled = true
		cooldown.visible = true
		cooldown.text = str(cd)
	else:
		disabled = false
		cooldown.visible = false
		cooldown.text = ""

func _on_pressed() -> void:
	EventBus.monster_ability_clicked.emit(ability_res)
