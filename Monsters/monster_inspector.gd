extends CanvasLayer

signal back_pressed

@onready var monster_container: Control = %monster_container
@export var monster_prefab: PackedScene

var tooltip_out: bool = false
var popup_coordinator: Node = null

func _ready() -> void:
	# Find the popup coordinator in the scene
	_find_popup_coordinator()

	# Only connect to EventBus if we don't have a popup coordinator
	if not popup_coordinator:
		EventBus.show_monster.connect(show_monster_info)
		EventBus.show_player_combatant.connect(show_player_combatant_info)

func _find_popup_coordinator() -> void:
	"""Find the LevelSelectPopupCoordinator in the scene tree."""
	var root = get_tree().root
	popup_coordinator = root.find_child("LevelSelectPopupCoordinator", true, false)

func show_monster_info(monster: FW_Monster_Resource) -> void:
	if popup_coordinator:
		# Use popup coordinator system
		_show_popup_with_data(monster, "monster")
	else:
		# Fallback to legacy tooltip system
		_show_legacy_tooltip(monster)

func show_player_combatant_info(combatant: FW_Combatant) -> void:
	if popup_coordinator:
		# Use popup coordinator system
		_show_popup_with_data(combatant, "player_combatant")
	else:
		# Fallback to legacy tooltip system
		_show_legacy_tooltip(combatant, true)

func _show_popup_with_data(data, popup_type: String) -> void:
	"""Show popup using the coordinator system."""
	# Clear and setup the container
	for c in monster_container.get_children():
		c.queue_free()

	var mob = monster_prefab.instantiate()
	monster_container.add_child(mob)

	if data is FW_Monster_Resource:
		mob.setup_monster_display(data)
	else:  # Combatant
		mob.setup_combatant_display(data, true)

	# Resize container to fit the actual monster display content
	monster_container.custom_minimum_size = Vector2(630, 270)
	monster_container.size = Vector2(630, 270)

	# Center the container in the viewport and make it visible (after sizing)
	_center_container()
	monster_container.visible = true

	# Center the monster display within the container
	if mob:
		var container_size = monster_container.size
		var mob_size = Vector2(630, 270)  # Match the Panel size in the prefab
		mob.position = (container_size - mob_size) / 2.0	# Show through popup coordinator
	popup_coordinator.show_popup(self, popup_type, {"data": data})

func _show_legacy_tooltip(data, is_player: bool = false) -> void:
	"""Legacy tooltip system for backward compatibility."""
	# clear the container if anythings in there first
	if tooltip_out == true:
		monster_container.hide()
		tooltip_out = false
	else:
		for c in monster_container.get_children():
			c.queue_free()
		var mob = monster_prefab.instantiate()
		monster_container.add_child(mob)
		if is_player:
			mob.setup_combatant_display(data, true)  # New unified method for players
		else:
			mob.setup_monster_display(data)  # Legacy method for backwards compatibility
		monster_container.position = Vector2(50, 200)
		monster_container.show()
		tooltip_out = true

func _center_container() -> void:
	"""Center the monster container in the viewport."""
	var viewport_size = get_viewport().get_visible_rect().size
	var container_size = monster_container.size

	# Calculate centered position
	var centered_pos = (viewport_size - container_size) / 2.0

	# Ensure position is not negative
	centered_pos.x = max(0, centered_pos.x)
	centered_pos.y = max(0, centered_pos.y)

	monster_container.position = centered_pos
