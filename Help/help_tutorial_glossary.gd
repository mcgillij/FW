extends "res://Scripts/base_menu_panel.gd"

signal back_button

@onready var glossary_list: ItemList = %glossary_list
@onready var container: VBoxContainer = %container

@onready var section_image: TextureRect = %section_image

const HELP_REGISTRY := preload("res://Help/help_registry.gd")

var _cache: Dictionary = {}

func _ready() -> void:
	#slide_in()
	glossary_list.connect("item_selected", Callable(self, "_on_item_selected"))

	# Automatically select the first entry when the help page opens so some
	# content is visible immediately. Defer selection to ensure the ItemList
	# has completed its internal setup and is in-tree.
	if glossary_list.get_item_count() > 0:
		call_deferred("_select_first_entry")

func _on_item_selected(index: int) -> void:
	_show_entry(index)


func _show_entry(index: int) -> void:
	var entry_name: String = glossary_list.get_item_text(index)

	# Set the section image to the item's icon
	var icon = glossary_list.get_item_icon(index)
	if icon:
		section_image.texture = icon
	# Hide all existing children (we keep them in the container to preserve state)
	for child in container.get_children():
		child.visible = false

	# If cached, simply show
	if _cache.has(entry_name):
		_cache[entry_name].visible = true
		# ensure container keeps a stable minimum size when showing cached child
		# defer sizing to ensure the node and its children are fully in-tree
		call_deferred("_update_container_min_size_for_child", _cache[entry_name])
		return

	# Lookup registry
	var entry: Dictionary = HELP_REGISTRY.get_entry(entry_name)
	if not entry or not entry.has("scene"):
		push_warning("No help scene registered for: %s" % entry_name)
		_show_fallback(entry_name)
		return

	var path: String = entry["scene"]
	var ps := load(path)
	if not ps:
		push_error("Failed to load help scene: %s" % path)
		_show_fallback(entry_name)
		return

	var inst: Node = ps.instantiate()
	container.add_child(inst)
	_cache[entry_name] = inst

	# Defer sizing until the child has entered the scene tree and its sizes are updated
	call_deferred("_update_container_min_size_for_child", inst)


func _show_fallback(entry_name: String) -> void:
	var lbl := Label.new()
	lbl.text = "Content not available for: %s" % entry_name
	container.add_child(lbl)
	_cache[entry_name] = lbl


func clear_cache() -> void:
	# Frees cached instances and clears cache
	for key in _cache.keys():
		var node = _cache[key]
		if node and node.is_inside_tree():
			node.queue_free()
	_cache.clear()
	# Reset any container minimum size constraints so layout can shrink if needed
	container.custom_minimum_size = Vector2.ZERO


func clear_container_keep_cache() -> void:
	# Hide all children but keep them cached for fast re-show
	for child in container.get_children():
		child.visible = false


func _update_container_min_size_for_child(child: Node) -> void:
	# Defensive sizing: find a Control to measure and use its minimum size
	if not child:
		return
	if not child.is_inside_tree():
		# Not yet in scene tree; nothing to measure
		return

	# Find the first Control descendant (including the node itself)
	var target: Control = _find_first_control(child)
	if not target:
		# Nothing to measure
		return

	# Use the Control's custom_minimum_size when available (project uses this commonly)
	var min_size := Vector2.ZERO
	min_size = target.custom_minimum_size

	# Take the maximum of current container min size and child's min size to avoid shrinking
	var current_min := Vector2.ZERO
	# Use the container's custom_minimum_size as the current baseline
	current_min = container.custom_minimum_size
	# compute new min and apply to container's custom_minimum_size
	var new_min = Vector2(max(current_min.x, min_size.x), max(current_min.y, min_size.y))
	# Prefer method if available, otherwise set the property
	# Apply the computed minimum; set the property directly
	container.custom_minimum_size = new_min


func _find_first_control(node: Node) -> Control:
	if not node:
		return null
	if node is Control:
		return node
	for ch in node.get_children():
		var res: Control = _find_first_control(ch)
		if res:
			return res
	return null


func _on_back_button_pressed() -> void:
	emit_signal("back_button")


func _select_first_entry() -> void:
	# Guard: ensure the list still has items and the node is inside the scene
	if not is_inside_tree():
		return
	if glossary_list.get_item_count() == 0:
		return
	# Select the first item and display its content. We call _show_entry
	# directly to avoid depending on whether selecting programmatically
	# emits the "item_selected" signal on this platform/version.
	glossary_list.select(0)
	_show_entry(0)
