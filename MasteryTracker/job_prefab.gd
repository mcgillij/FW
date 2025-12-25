extends Control

signal job_selected(job: FW_Job, requirements: Dictionary, completed: bool, display_name: String, accent_color: Color)

@onready var job_name: Label = %job_name
@onready var ability_image_1: TextureRect = %ability_image1
@onready var ability_image_2: TextureRect = %ability_image2
@onready var ability_image_3: TextureRect = %ability_image3
@onready var ability_image_4: TextureRect = %ability_image4
@onready var ability_image_5: TextureRect = %ability_image5
@onready var completed_label: Label = %completed_label
@onready var job_background: Control = %JobBackground

var _job: FW_Job = null
var _resource_path: String = ""
var _requirements: Dictionary = {}
var _completed: bool = false
var _display_name: String = ""
var _ability_slots: Array[TextureRect] = []
var _ability_icon_cache: Dictionary = {}
var _is_selected := false
var _is_hovered := false
const FALLBACK_ACCENT := Color(0.32, 0.55, 0.85, 1.0)
var _background_style: StyleBoxFlat
var _accent_base: Color = FALLBACK_ACCENT

const MIN_LUMINANCE := 0.42
const BASE_BG_COLOR := Color(0.12, 0.12, 0.15, 1.0)
const BORDER_BASE_COLOR := Color(0.22, 0.26, 0.33, 1.0)

func _ready() -> void:
	_background_style = StyleBoxFlat.new()
	_background_style.bg_color = BASE_BG_COLOR
	_background_style.corner_radius_top_left = 6
	_background_style.corner_radius_top_right = 6
	_background_style.corner_radius_bottom_right = 6
	_background_style.corner_radius_bottom_left = 6
	_background_style.border_width_left = 1
	_background_style.border_width_right = 1
	_background_style.border_width_top = 1
	_background_style.border_width_bottom = 1
	_background_style.border_color = BORDER_BASE_COLOR
	_background_style.set_content_margin(SIDE_LEFT, 8)
	_background_style.set_content_margin(SIDE_RIGHT, 8)
	_background_style.set_content_margin(SIDE_TOP, 4)
	_background_style.set_content_margin(SIDE_BOTTOM, 4)
	if job_background:
		job_background.add_theme_stylebox_override("panel", _background_style)
	else:
		push_warning("JobBackground node missing on JobPrefab; background styling disabled")
	_ability_slots = [ability_image_1, ability_image_2, ability_image_3, ability_image_4, ability_image_5]
	set_selected(false)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func setup(job: FW_Job, resource_path: String, requirements: Dictionary, completed: bool, ability_icons: Dictionary) -> void:
	_job = job
	_resource_path = resource_path
	_requirements = requirements.duplicate(true)
	_completed = completed
	_ability_icon_cache = ability_icons
	_display_name = _resolve_display_name()
	job_name.text = _display_name
	_accent_base = _resolve_job_color()
	if _job != null:
		_job.job_color = _accent_base
	_apply_job_accent()
	if completed:
		completed_label.text = "✔"
		completed_label.tooltip_text = "Completed"
		completed_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4, 1.0))
		completed_label.visible = true
	else:
		completed_label.text = ""
		completed_label.tooltip_text = ""
		completed_label.visible = false
		completed_label.remove_theme_color_override("font_color")
	#if _job and _job.description:
	#	tooltip_text = _job.description
	_populate_requirement_icons()
	set_selected(false)
	_apply_visual_state()

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_visual_state()

func get_job() -> FW_Job:
	return _job

func get_requirements() -> Dictionary:
	return _requirements.duplicate(true)

func is_completed() -> bool:
	return _completed

func get_display_name() -> String:
	return _display_name

func get_accent_color() -> Color:
	return _accent_base if _accent_base != null else FALLBACK_ACCENT

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("job_selected", _job, _requirements.duplicate(true), _completed, _display_name, get_accent_color())

func _resolve_display_name() -> String:
	if _job and _job.name:
		return _job.name
	if _resource_path != "":
		return _resource_path.get_file().get_basename()
	return "Unknown Job"

func _populate_requirement_icons() -> void:
	for slot in _ability_slots:
		slot.visible = false
		slot.texture = null
		slot.tooltip_text = ""
		slot.modulate = Color(1, 1, 1, 1)

	var slot_index := 0
	var ability_keys := _requirements.keys()
	ability_keys.sort()
	for ability_key in ability_keys:
		var count: int = int(_requirements[ability_key])
		var texture: Texture2D = _resolve_icon_for_ability(ability_key)
		for _i in range(count):
			if slot_index >= _ability_slots.size():
				break
			var slot: TextureRect = _ability_slots[slot_index]
			if texture:
				slot.texture = texture
				slot.tooltip_text = "%s x%d" % [ability_key, count]
			else:
				slot.tooltip_text = ability_key
			slot.modulate = Color(1, 1, 1, 1)
			slot.visible = true
			slot_index += 1

func _resolve_icon_for_ability(ability_key: String) -> Texture2D:
	return _ability_icon_cache.get(ability_key, null)

func _collect_requirement_types() -> Array:
	var types: Array = []
	for ability_key in _requirements.keys():
		var count: int = int(_requirements[ability_key])
		if count < 1:
			count = 1
		var ability_name := str(ability_key)
		for _i in range(count):
			types.append(ability_name)
	return types

func _resolve_job_color() -> Color:
	var ability_types := _collect_requirement_types()
	var recognized: Array = []
	for ability_type in ability_types:
		var lower := str(ability_type).to_lower()
		if FW_Ability.TYPE_COLORS.has(lower):
			recognized.append(lower)
	var base_color := FALLBACK_ACCENT
	if recognized.size() > 0:
		base_color = FW_Utils.blend_type_colors(recognized)
	elif _job != null and _job.job_color != null:
		base_color = FW_Utils.normalize_color(_job.job_color)
	return _ensure_accessible_color(base_color)

func _apply_job_accent() -> void:
	if _accent_base == null:
		_accent_base = FALLBACK_ACCENT
	var accent := _accent_base
	if accent == null:
		accent = FALLBACK_ACCENT
	job_name.add_theme_color_override("font_color", accent)
	job_name.add_theme_constant_override("outline_size", 2)
	job_name.add_theme_color_override("font_outline_color", accent.darkened(0.35))

func _apply_visual_state() -> void:
	if _background_style == null:
		return
	var bg_color := BASE_BG_COLOR
	if _is_selected:
		bg_color = BASE_BG_COLOR.lerp(Color(1, 1, 1, 1), 0.18)
	elif _is_hovered:
		bg_color = BASE_BG_COLOR.lerp(Color(1, 1, 1, 1), 0.1)
	_background_style.bg_color = bg_color
	var border_color := BORDER_BASE_COLOR
	if _is_selected:
		border_color = BORDER_BASE_COLOR.lerp(Color(1, 1, 1, 1), 0.15)
	elif _is_hovered:
		border_color = BORDER_BASE_COLOR.lerp(Color(1, 1, 1, 1), 0.08)
	_background_style.border_color = border_color

func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_visual_state()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_visual_state()

func _ensure_accessible_color(color_value: Color) -> Color:
	var base := Color(color_value.r, color_value.g, color_value.b, 1.0)
	var luminance := base.r * 0.2126 + base.g * 0.7152 + base.b * 0.0722
	if luminance < MIN_LUMINANCE:
		var boost := clampf((MIN_LUMINANCE - luminance) * 1.6, 0.0, 0.8)
		base = base.lerp(Color(1, 1, 1, 1), boost)
	return base
