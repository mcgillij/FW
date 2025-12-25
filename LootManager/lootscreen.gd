extends "res://Scripts/base_menu_panel.gd"

signal back_button

@export var loot_item_panel: PackedScene
@onready var loot_container: HBoxContainer = %loot_container
@onready var event_text: RichTextLabel = %event_text

# Constants for buff preview display
const BUFF_VIEWER_SCENE_PATH := "res://Buffs/FW_BuffViewerPrefab.tscn"
const BUFF_PREVIEW_SCALE_FACTOR := 0.8
const DEFAULT_PLAYER_NAME := "Player"

# Cache the buff viewer scene to avoid repeated loading
var _buff_viewer_scene: PackedScene

func _ready() -> void:
	# Preload the buff viewer scene for performance
	_buff_viewer_scene = load(BUFF_VIEWER_SCENE_PATH)
	if not _buff_viewer_scene:
		push_error("Failed to load buff viewer scene: %s" % BUFF_VIEWER_SCENE_PATH)

	# Clear panels when visibility changes to avoid stale UI between shows
	visibility_changed.connect(_on_visibility_changed)

func setup() -> void:
	_clear_loot_children()
	var lm = FW_LootManager.new()
	var loot = lm.sweet_loot()
	lm.grant_loot_to_player([loot])
	lm.create_loot_panels([loot], loot_item_panel, loot_container)

func show_text(text: String) -> void:
	event_text.text = text

func show_buff_previews() -> void:
	"""Show previews of buffs that will be applied at combat start"""
	# Clear any existing loot panels first
	_clear_loot_children()

	var pending_buffs = _get_pending_combat_buffs()
	_display_buff_panels(pending_buffs)

func show_buffs(buff_list: Array) -> void:
	"""Display a provided list of buffs in the loot container"""
	_clear_loot_children()
	event_text.text = ""
	if OS.is_debug_build():
		FW_Debug.debug_log(["LootScreen.show_buffs: buff_list_count=", buff_list.size() if typeof(buff_list) == TYPE_ARRAY else 0])
	_display_buff_panels(buff_list)

func _get_pending_combat_buffs() -> Array:
	"""Get the list of pending combat buffs, with safety checks"""
	if not GDM.has_meta("pending_combat_buffs"):
		return []

	var pending_buffs = GDM.get_meta("pending_combat_buffs")
	return pending_buffs if pending_buffs is Array else []

func _create_buff_preview_panel(buff: FW_Buff) -> void:
	"""Create and display a buff preview panel in the loot container"""
	if not _buff_viewer_scene:
		push_warning("BuffViewerPrefab scene not loaded")
		return

	var panel = _buff_viewer_scene.instantiate()
	if not panel:
		push_warning("Failed to instantiate buff viewer panel")
		return

	loot_container.add_child(panel)

	# Setup the buff viewer with template variables for proper {target} replacement
	var template_vars = _create_buff_template_vars(buff)
	if panel.has_method("setup"):
		panel.setup(buff, template_vars)

	# Scale down the buff panel for the loot container
	_apply_buff_preview_scaling(panel)

func _create_buff_template_vars(_buff: FW_Buff) -> Dictionary:
	"""Create template variables for buff descriptions based on buff ownership"""
	# For event failure buffs, the target is always the player
	var target_name = DEFAULT_PLAYER_NAME
	if GDM.player and GDM.player.character and GDM.player.character.name:
		target_name = GDM.player.character.name

	return {"target": target_name}

func _apply_buff_preview_scaling(panel: Control) -> void:
	"""Apply consistent scaling to buff preview panels"""
	panel.scale = Vector2(BUFF_PREVIEW_SCALE_FACTOR, BUFF_PREVIEW_SCALE_FACTOR)
	# Adjust size to account for scaling
	var original_size = panel.size
	panel.custom_minimum_size = original_size * BUFF_PREVIEW_SCALE_FACTOR

func _on_back_button_pressed() -> void:
	# Ensure the UI is cleaned up before emitting the back signal so callers
	# never see stale preview panels.
	_clear_loot_children()
	emit_signal("back_button")


func show_single_loot(item: FW_Item) -> void:
	"""Display a single item on the loot screen"""
	show_loot_collection([item], "")


func show_loot_collection(items: Array, description: String = "", buff_list: Array = []) -> void:
	"""Display multiple loot items (and optional buffs) in the loot container"""
	_clear_loot_children()
	var trimmed := description.strip_edges()
	if event_text:
		event_text.text = trimmed
	_display_loot_items(items)
	_display_buff_panels(buff_list)


func _clear_loot_children() -> void:
	# Use free to remove immediately, avoiding potential stale UI issues
	for child in loot_container.get_children():
		child.free()


func _display_loot_items(items: Array) -> void:
	if items.is_empty():
		return
	if loot_item_panel == null:
		push_warning("LootScreen missing loot_item_panel scene; cannot render loot panels")
		return
	var lm := FW_LootManager.new()
	lm.create_loot_panels(items, loot_item_panel, loot_container)


func _display_buff_panels(buff_list: Array) -> void:
	if buff_list.is_empty():
		return
	for buff in buff_list:
		if buff is FW_Buff:
			_create_buff_preview_panel(buff)


func _on_visibility_changed() -> void:
	# Called when the control's visibility changes. When hidden, clear
	# transient children so they don't persist into the next show.
	if not visible:
		_clear_loot_children()
	else:
		# Also clear when becoming visible to ensure clean state
		_clear_loot_children()
