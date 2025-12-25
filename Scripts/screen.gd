extends TextureRect

"""transparent gray screen that shows up over the background when someone presses a booster button"""

func _ready() -> void:
	# Refactor these to generic colors, unless I do unique effects for each
	EventBus.do_booster_screen_effect.connect(do_effect)
	modulate = Color(1,1,1,0)

	# Register this TextureRect with the CombatVisualEffectsManager
	if GDM.game_manager.vfx_manager:
		GDM.game_manager.vfx_manager.register_fullscreen_overlay(self)


func fade_in() -> void:
	GDM.game_manager.vfx_manager.overlay_fade_in(Color(1,1,1,1), 0.3)

func fade_out() -> void:
	GDM.game_manager.vfx_manager.overlay_fade_out(0.3)

func do_effect(type: FW_Ability.ABILITY_TYPES) -> void:
	var color: Color
	match type:
		FW_Ability.ABILITY_TYPES.Bark:
			color = FW_Colors.bark
		FW_Ability.ABILITY_TYPES.Reflex:
			color = FW_Colors.reflex
		FW_Ability.ABILITY_TYPES.Alertness:
			color = FW_Colors.alertness
		FW_Ability.ABILITY_TYPES.Vigor:
			color = FW_Colors.vigor
		FW_Ability.ABILITY_TYPES.Enthusiasm:
			color = FW_Colors.enthusiasm
	effect_fade_in(color)
	# Delay the fade out until after fade in completes
	await get_tree().create_timer(0.7).timeout
	effect_fade_out(color)

func effect_fade_in(color: Color) -> void:
	GDM.game_manager.vfx_manager.overlay_fade_in(color, 0.7)

func effect_fade_out(_color: Color) -> void:
	GDM.game_manager.vfx_manager.overlay_fade_out(0.7)

func _on_game_manager_screen_fade_in() -> void:
	fade_in()

func _on_game_manager_screen_fade_out() -> void:
	fade_out()
