extends RefCounted
class_name FW_SolitaireLayoutBinder

const LayoutBindings := preload("res://Solitaire/LayoutBindings.gd")

static func bind(layout_root: Node) -> Dictionary:
	var result := {
		"shader_bg": null,
		"background": null,
		"slots_root": null,
		"card_container": null,
		"stock_panel": null,
		"waste_panel": null,
		"stock_texture": null,
		"stock_count_label": null,
		"game_timer": null,
		"win_bg_panel": null,
		"win_label": null,
		"new_game_button": null,
		"undo_button": null,
		"auto_complete_button": null,
		"draw_mode_toggle": null,
		"view_stats_button": null,
		"layout_toggle_button": null,
		"stats_label": null,
		"stats_slide_in": null,
		"back_button": null,
		"layout_metrics": null,
		"foundation_slots": [],
		"tableau_slots": [],
		"warnings": []
	}
	if layout_root == null:
		result["warnings"].append("[LayoutBind] Layout root is null")
		return result
	if layout_root is LayoutBindings:
		var from_bindings := _from_bindings(layout_root as LayoutBindings, result)
		if _needs_fallback(from_bindings):
			result["warnings"].append("[LayoutBind] LayoutBindings incomplete; scanning scene tree for nodes")
			return _from_scene_scan(layout_root, result)
		return from_bindings
	return _from_scene_scan(layout_root, result)

static func _from_bindings(bindings: LayoutBindings, result: Dictionary) -> Dictionary:
	result["shader_bg"] = bindings.shader_bg
	result["background"] = bindings.background
	result["slots_root"] = bindings.slots_root
	result["card_container"] = bindings.card_container
	result["stock_panel"] = bindings.stock_panel
	result["waste_panel"] = bindings.waste_panel
	result["stock_texture"] = bindings.stock_texture
	result["stock_count_label"] = bindings.stock_count_label
	result["game_timer"] = bindings.game_timer
	result["win_bg_panel"] = bindings.win_bg_panel
	result["win_label"] = bindings.win_label
	result["new_game_button"] = bindings.new_game_button
	result["undo_button"] = bindings.undo_button
	result["auto_complete_button"] = bindings.auto_complete_button
	result["draw_mode_toggle"] = bindings.draw_mode_toggle
	result["view_stats_button"] = bindings.view_stats_button
	result["layout_toggle_button"] = bindings.layout_toggle_button
	result["stats_label"] = bindings.stats_label
	result["stats_slide_in"] = bindings.stats_slide_in
	result["back_button"] = bindings.back_button
	if bindings.has_method("get_layout_metrics"):
		result["layout_metrics"] = bindings.get_layout_metrics()
	result["foundation_slots"] = bindings.foundation_slots.duplicate()
	result["tableau_slots"] = bindings.tableau_slots.duplicate()
	return result

static func _needs_fallback(result: Dictionary) -> bool:
	if result.get("card_container") == null:
		return true
	if _has_missing_panels(result.get("foundation_slots"), 4):
		return true
	if _has_missing_panels(result.get("tableau_slots"), 7):
		return true
	return false

static func _has_missing_panels(value: Variant, expected: int) -> bool:
	if not (value is Array):
		return true
	var count := 0
	for element in value:
		if element is Panel:
			count += 1
	if count < expected:
		return true
	return false

static func _from_scene_scan(layout_root: Node, result: Dictionary) -> Dictionary:
	_assign_unique(result, "shader_bg", layout_root, "ShaderBG", &"ColorRect")
	_assign_unique(result, "background", layout_root, "background", &"TextureRect")
	_assign_unique(result, "slots_root", layout_root, "SlotsRoot", &"Control")
	_assign_unique(result, "card_container", layout_root, "CardContainer", &"Control")
	_assign_unique(result, "stock_panel", layout_root, "StockPanel", &"Panel")
	_assign_unique(result, "waste_panel", layout_root, "WastePanel", &"Panel")
	_assign_unique(result, "stock_texture", layout_root, "StockTexture", &"TextureRect")
	_assign_unique(result, "stock_count_label", layout_root, "StockCountLabel", &"Label")
	_assign_unique(result, "game_timer", layout_root, "GameTimer", &"Timer")
	_assign_unique(result, "win_bg_panel", layout_root, "WinBgPanel", &"Panel")
	_assign_unique(result, "win_label", layout_root, "WinLabel", &"Label")
	_assign_unique(result, "new_game_button", layout_root, "NewGameButton", &"Button")
	_assign_unique(result, "undo_button", layout_root, "UndoButton", &"Button")
	_assign_unique(result, "auto_complete_button", layout_root, "AutoCompleteButton", &"Button")
	_assign_unique(result, "draw_mode_toggle", layout_root, "DrawModeToggle", &"BaseButton")
	_assign_unique(result, "view_stats_button", layout_root, "ViewStatsButton", &"Button")
	_assign_unique(result, "layout_toggle_button", layout_root, "LayoutToggleButton", &"Button")
	_assign_unique(result, "stats_label", layout_root, "StatsLabel", &"Label")
	_assign_unique(result, "stats_slide_in", layout_root, "StatsSlideIn", &"CanvasLayer")
	_assign_unique(result, "back_button", layout_root, "back_button", &"BaseButton")
	if layout_root.has_method("get_layout_metrics"):
		result["layout_metrics"] = layout_root.call("get_layout_metrics")

	result["foundation_slots"] = _collect_panels(layout_root, [
		"FoundationSlot0",
		"FoundationSlot1",
		"FoundationSlot2",
		"FoundationSlot3"
	], result)

	result["tableau_slots"] = _collect_panels(layout_root, [
		"TableauSlot0",
		"TableauSlot1",
		"TableauSlot2",
		"TableauSlot3",
		"TableauSlot4",
		"TableauSlot5",
		"TableauSlot6"
	], result)

	return result

static func _assign_unique(result: Dictionary, key: String, layout_root: Node, unique_name: String, expected_class: StringName) -> void:
	var node := _find_unique(layout_root, unique_name)
	if node == null:
		result["warnings"].append("[LayoutBind] %s not found via unique name" % unique_name)
	elif expected_class != StringName() and not node.is_class(expected_class):
		result["warnings"].append("[LayoutBind] %s found but is not %s" % [unique_name, String(expected_class)])
	result[key] = node

static func _collect_panels(layout_root: Node, names: Array[String], result: Dictionary) -> Array[Panel]:
	var panels: Array[Panel] = []
	for name in names:
		var node := _find_unique(layout_root, name)
		if node and node is Panel:
			panels.append(node)
		elif node != null:
			result["warnings"].append("[LayoutBind] %s found but is not a Panel" % name)
		else:
			result["warnings"].append("[LayoutBind] %s not found via unique name" % name)
	return panels

static func _find_unique(layout_root: Node, unique_name: String) -> Node:
	if layout_root == null:
		return null
	var found := layout_root.find_child(unique_name, true, false)
	if found != null:
		return found
	if layout_root.name == unique_name:
		return layout_root
	return null
