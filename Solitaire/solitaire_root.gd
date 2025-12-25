extends CanvasLayer

@export var portrait_scene: PackedScene
@export var landscape_scene: PackedScene
@export var core_scene: PackedScene

enum LayoutPreset { PORTRAIT, LANDSCAPE }

var _current_layout: Node
var _active_preset: LayoutPreset = LayoutPreset.PORTRAIT
var _layout_manager: Node
var _core: Node

func _ready() -> void:
	_layout_manager = get_tree().root.get_node_or_null("LayoutManager")
	if core_scene != null and _core == null:
		_core = core_scene.instantiate()
		if _core != null:
			add_child(_core)
	if _layout_manager != null and _layout_manager.has_method("get_active_preset"):
		var manager_preset := int(_layout_manager.get_active_preset())
		_active_preset = _to_local_preset(manager_preset)
		if _layout_manager.has_signal("layout_changed"):
			var callable := Callable(self, "_on_manager_layout_changed")
			var layout_signal = _layout_manager.layout_changed
			if not layout_signal.is_connected(callable):
				layout_signal.connect(callable)
	_apply_layout(_active_preset)

func _apply_layout(preset: LayoutPreset) -> void:
	var scene := _scene_for_preset(preset)
	if scene == null:
		push_warning("No scene configured for preset %s" % [preset])
		return
	_active_preset = preset
	_swap_layout(scene)


func toggle_layout() -> void:
	if _layout_manager != null and _layout_manager.has_method("toggle_layout"):
		_layout_manager.toggle_layout()
		return
	var next_preset: LayoutPreset = LayoutPreset.LANDSCAPE if _active_preset == LayoutPreset.PORTRAIT else LayoutPreset.PORTRAIT
	_apply_layout(next_preset)

func _scene_for_preset(preset: LayoutPreset) -> PackedScene:
	match preset:
		LayoutPreset.PORTRAIT:
			return portrait_scene
		LayoutPreset.LANDSCAPE:
			return landscape_scene if landscape_scene != null else portrait_scene
		_:
			return null

func _swap_layout(scene: PackedScene) -> void:
	if scene == null:
		return
	var previous_layout := _current_layout
	var instance := scene.instantiate()
	if instance == null:
		push_warning("Failed to instantiate layout scene")
		return
	_current_layout = instance
	add_child(_current_layout)
	_bind_core_to_layout(_current_layout, previous_layout == null)
	if previous_layout != null and is_instance_valid(previous_layout):
		remove_child(previous_layout)
		previous_layout.queue_free()

func _bind_core_to_layout(layout_instance: Node, reset_game: bool) -> void:
	if _core == null:
		return
	if not _core.has_method("bind_layout"):
		return
	_core.bind_layout(layout_instance, reset_game, int(_active_preset))

func _on_manager_layout_changed(preset) -> void:
	_apply_layout(_to_local_preset(int(preset)))

func _to_local_preset(value: int) -> LayoutPreset:
	var values := LayoutPreset.values()
	if values.is_empty():
		return LayoutPreset.PORTRAIT
	var index := clampi(value, 0, values.size() - 1)
	return values[index] as LayoutPreset
