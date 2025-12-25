extends Node2D

@export var stats_view_prefab: PackedScene
@export var ability_view_prefab: PackedScene
@export var buff_view_prefab: PackedScene

const ABILITY_VIEW_LOCATION := Vector2(-50, 250)
const STAT_PANEL_LOCATION := Vector2(-50, 250)

# Constants for buff ownership types
const OWNER_TYPE_PLAYER := "player"
const OWNER_TYPE_MONSTER := "monster"
const DEFAULT_PLAYER_NAME := "Player"
const DEFAULT_MONSTER_NAME := "Monster"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.monster_clicked.connect(show_monster_stats_panel)
	EventBus.player_clicked.connect(show_player_stats_panel)
	EventBus.monster_ability_clicked.connect(show_ability_panel)
	EventBus.player_ability_clicked.connect(show_ability_panel)
	EventBus.player_buff_clicked.connect(show_buff_panel)
	EventBus.monster_buff_clicked.connect(show_buff_panel)

func show_ability_panel(ability: FW_Ability) -> void:
	if not _is_popup_coordinator_available():
		return

	# Create and setup panel
	var panel = ability_view_prefab.instantiate()
	add_child(panel)
	if panel.has_method("setup"):
		panel.setup(ability)

	# Show via coordinator (handles toggle behavior and centering automatically)
	GDM.game_manager.popup_coordinator.show_popup(panel, "ability", {"ability": ability})

func show_monster_stats_panel() -> void:
	if not _is_popup_coordinator_available():
		return

	# Create and setup panel
	var panel = stats_view_prefab.instantiate()
	add_child(panel)
	if panel.has_method("setup"):
		panel.setup(GDM.monster_to_fight)

	# Show via coordinator (handles toggle behavior and centering automatically)
	GDM.game_manager.popup_coordinator.show_popup(panel, "monster_stats")

func show_player_stats_panel() -> void:
	if not _is_popup_coordinator_available():
		return

	# Create and setup panel
	var panel = stats_view_prefab.instantiate()
	add_child(panel)
	if panel.has_method("setup"):
		panel.setup(GDM.player.character)

	# Show via coordinator (handles toggle behavior and centering automatically)
	GDM.game_manager.popup_coordinator.show_popup(panel, "player_stats")

func show_buff_panel(buff: FW_Buff) -> void:
	if not _is_popup_coordinator_available():
		return

	# Create and setup panel
	var panel = buff_view_prefab.instantiate()
	add_child(panel)

	# Setup with template variables to fill in {target} placeholder
	var template_vars = _create_buff_template_vars(buff)
	if panel.has_method("setup"):
		panel.setup(buff, template_vars)

	# Show via coordinator (handles toggle behavior and centering automatically)
	GDM.game_manager.popup_coordinator.show_popup(panel, "buff", {"buff": buff})

func _is_popup_coordinator_available() -> bool:
	"""Check if popup coordinator is available with proper error handling"""
	if not GDM.game_manager or not GDM.game_manager.popup_coordinator:
		push_warning("PopupCoordinator not available in GameManager")
		return false
	return true

func _create_buff_template_vars(buff: FW_Buff) -> Dictionary:
	"""Create template variables for buff descriptions based on buff ownership"""
	var target_name = DEFAULT_PLAYER_NAME

	if buff.owner_type == OWNER_TYPE_MONSTER:
		target_name = GDM.monster_to_fight.name if GDM.monster_to_fight else DEFAULT_MONSTER_NAME
	else:  # OWNER_TYPE_PLAYER
		if GDM.player and GDM.player.character and GDM.player.character.name:
			target_name = GDM.player.character.name

	return {"target": target_name}
