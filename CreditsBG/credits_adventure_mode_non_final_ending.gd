extends CanvasLayer

const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"
const SIDE_BACKGROUND := "background"

const IMAGE_PATHS = [
	"res://Characters/Images/atiya.png",
	"res://Characters/Images/bentley.png",
	"res://Characters/Images/bonk.png",
	"res://Characters/Images/boomer.png",
	"res://Characters/Images/echo.png",
	"res://Characters/Images/rosie.png",
	"res://Characters/Images/tilly.png"
]

@export var image_paths: PackedStringArray = PackedStringArray()

@export var scroll_duration: float = 45.0
@export var pause_at_end: float = 4.0
@export var section_spacing: float = 48.0
@export var auto_restart: bool = true
@export var sections: Array[Dictionary] = [
	{
		"header": "Adventure Mode Characters",
		"entries": [
			"Atiya",
			"Bentley",
			"Bonk",
			"Boomer",
			"Echo",
			"Rosie",
			"Tilly"
		],
		"accent_color": Color(0.95, 0.83, 0.46)
	},
	{
		"header": "Adventure Mode Programming",
		"entries": [
			"Dev: mcgillij",
		],
		"accent_color": Color(0.973, 0.973, 0.949, 1.0)
	},
	{
		"header": "Adventure Mode Music",
		"entries": [
			"Music: hydrogene.itch.io",
			"Music: DavidKBD"
		],
		"accent_color": Color(0.314, 0.98, 0.482, 1.0)
	},
	{
		"header": "Chief Throw the Ball Champion",
		"entries": [
			"Atiya",
		],
		"accent_color": Color(0.384, 0.447, 0.643, 1.0)
	},
	{
		"header": "Lead Howler",
		"entries": [
			"Bentley",
		],
		"accent_color": Color(0.95, 0.83, 0.46)
	},
	{
		"header": "Pieces",
		"entries": [
			"Atiya's Blue Spikey Ball",
			"Atiya's favorite bone",
			"Atiya's purple star pillow",
			"Atiya's shield harness",
			"Atiya"
		],
		"accent_color": Color(0.545, 0.914, 0.992, 1.0)
	},
	{
		"header": "Atiya's Dog Pals",
		"entries": [
			"Boomer",
			"Bentley",
			"Tilly"
		],
		"accent_color": Color(1.0, 0.333, 0.333, 1.0)
	},
	{
		"header": "Atiya's Cat Pal",
		"entries": [
			"Bonk",
		],
		"accent_color": Color(0.95, 0.83, 0.46)
	},
	{
		"header": "Open Source",
		"entries": [
			"Godot",
			"Gimp",
			"Arch Linux"
		],
		"accent_color": Color(0.741, 0.576, 0.976, 1.0)
	},
	{
		"header": "Special Thanks",
		"entries": [
			"You for playing the game!"
		],
		"center": true
	}
]
@export var image_sequence: Array[Dictionary] = []
@export_range(0.25, 2.0, 0.05) var header_scale: float = 1.25
@export_range(0.05, 2.5, 0.05) var fade_duration: float = 0.5
@export var debug_image_sizing: bool = true
@export var max_image_size: Vector2 = Vector2(256, 256)

var _scroll_tween: Tween
var _image_tween: Tween
var _current_image_step: int = -1
var _image_targets: Dictionary = {}
var _texture_cache: Dictionary = {}
var _image_initial_offsets: Dictionary = {}

@onready var _scroll_container: ScrollContainer = %Scroll
@onready var _content: VBoxContainer = %Content
@onready var _background_rect: TextureRect = %Background
@onready var _left_rect: TextureRect = %LeftImage
@onready var _right_rect: TextureRect = %RightImage
@onready var _cycle_timer: Timer = %ImageCycleTimer


func _ready() -> void:
	if image_paths.is_empty():
		image_paths = PackedStringArray(IMAGE_PATHS)
	_initialize_image_targets()
	_configure_scroll_container()
	_sanitize_image_sequence()
	populate_sections()
	await get_tree().process_frame
	if not _scroll_container.resized.is_connected(_on_scroll_resized):
		_scroll_container.resized.connect(_on_scroll_resized)
	start_scroll()
	if image_sequence.is_empty():
		_cycle_timer.stop()
	else:
		if not _cycle_timer.timeout.is_connected(_on_image_cycle_timeout):
			_cycle_timer.timeout.connect(_on_image_cycle_timeout)
		_cycle_timer.stop()
		_current_image_step = -1
		_advance_image_sequence()


func populate_sections() -> void:
	for child in _content.get_children():
		child.queue_free()
	await get_tree().process_frame
	for section in sections:
		_add_section(section)
		_add_section_spacing()
	call_deferred("start_scroll")


func start_scroll() -> void:
	if not is_instance_valid(_scroll_container):
		return
	if is_instance_valid(_scroll_tween):
		_scroll_tween.kill()
	_scroll_container.scroll_vertical = 0
	# Wait a frame so layout and sizes update correctly before querying scroll bar / sizes
	await get_tree().process_frame
	# Prefer using the scroll bar's max_value (reliable) if available, otherwise fall back
	# to computing target from content size. The scroll bar's max_value handles margins
	# and internal layout differences better and prevents the last line from being cut off.
	var v_bar: ScrollBar = _scroll_container.get_v_scroll_bar()
	var target_scroll: float = 0.0
	if v_bar != null:
		target_scroll = v_bar.max_value
	else:
		var content_height := _content.get_combined_minimum_size().y
		var viewport_height := _scroll_container.size.y
		if content_height <= viewport_height:
			return
		target_scroll = content_height - viewport_height
	_scroll_tween = create_tween()
	_scroll_tween.set_trans(Tween.TRANS_SINE)
	_scroll_tween.set_ease(Tween.EASE_IN_OUT)
	_scroll_tween.tween_property(_scroll_container, "scroll_vertical", target_scroll, scroll_duration)
	_scroll_tween.finished.connect(_on_scroll_finished)


func _on_scroll_finished() -> void:
	if pause_at_end <= 0.0 and not auto_restart:
		_on_back_button_pressed()
		return
	if pause_at_end > 0.0:
		await get_tree().create_timer(pause_at_end).timeout
	if auto_restart:
		start_scroll()
	else:
		_on_back_button_pressed()


func _on_scroll_resized() -> void:
	call_deferred("start_scroll")


func _initialize_image_targets() -> void:
	_image_targets = {
		SIDE_BACKGROUND: _background_rect,
		SIDE_LEFT: _left_rect,
		SIDE_RIGHT: _right_rect
	}
	for side_key in _image_targets.keys():
		var rect: TextureRect = _image_targets[side_key]
		rect.visible = true
		rect.modulate = Color(rect.modulate.r, rect.modulate.g, rect.modulate.b, 0.0)
		# Ensure the rect uses its size to constrain the texture
		rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Reset size/offsets so we can control them dynamically
		rect.size = Vector2.ZERO
		rect.offset_left = rect.offset_left
		rect.offset_right = rect.offset_right
		rect.offset_top = rect.offset_top
		rect.offset_bottom = rect.offset_bottom
		rect.texture = null
		# store initial offsets so we can restore them when image is cleared
		_image_initial_offsets[side_key] = {
			"left": rect.offset_left,
			"right": rect.offset_right,
			"top": rect.offset_top,
			"bottom": rect.offset_bottom
		}
		if side_key == SIDE_BACKGROUND:
			rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.size = Vector2.ZERO
			rect.custom_minimum_size = Vector2.ZERO
			rect.z_index = -2
		else:
			rect.z_index = 2


func _configure_scroll_container() -> void:
	if _scroll_container == null:
		return
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var v_bar: ScrollBar = _scroll_container.get_v_scroll_bar()
	if v_bar != null:
		v_bar.visible = false
		v_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v_bar.modulate = Color(1, 1, 1, 0)
	var h_bar: ScrollBar = _scroll_container.get_h_scroll_bar()
	if h_bar != null:
		h_bar.visible = false
		h_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h_bar.modulate = Color(1, 1, 1, 0)


func _sanitize_image_sequence() -> void:
	if image_paths.size() > 0:
		image_sequence = _build_sequence_from_paths(image_paths)
	else:
		var usable_steps: Array[Dictionary] = []
		for step in image_sequence:
			if not (step is Dictionary):
				continue
			if _step_has_visual_payload(step):
				usable_steps.append(step)
		image_sequence = usable_steps


func _step_has_visual_payload(step: Dictionary) -> bool:
	if step.has("layers") and step["layers"] is Array:
		for layer_data in step["layers"]:
			if _layer_has_visual_payload(layer_data):
				return true
		return false
	return _layer_has_visual_payload(step)


func _layer_has_visual_payload(layer_data: Variant) -> bool:
	if not (layer_data is Dictionary):
		return false
	if layer_data.has("texture") and layer_data["texture"] is Texture2D:
		return true
	if layer_data.has("path"):
		var path := String(layer_data["path"]).strip_edges()
		return path != ""
	return false


func _build_sequence_from_paths(paths: PackedStringArray) -> Array[Dictionary]:
	var sequence: Array[Dictionary] = []
	var use_left := true
	for raw_path in paths:
		var path := String(raw_path).strip_edges()
		if path == "":
			continue
		var step: Dictionary = {
			"side": SIDE_LEFT if use_left else SIDE_RIGHT,
			"path": path,
			"fade_in": fade_duration,
			"fade_out": fade_duration,
			"duration": _default_image_duration()
		}
		sequence.append(step)
		use_left = !use_left
	return sequence


func _default_image_duration() -> float:
	if _cycle_timer != null and _cycle_timer.wait_time > 0.0:
		return _cycle_timer.wait_time
	return 6.0


func _advance_image_sequence() -> void:
	if image_sequence.is_empty():
		return
	_current_image_step = (_current_image_step + 1) % image_sequence.size()
	_show_image(image_sequence[_current_image_step])


func _on_image_cycle_timeout() -> void:
	_advance_image_sequence()


func _show_image(step: Dictionary) -> void:
	if is_instance_valid(_image_tween):
		_image_tween.kill()
	var layers: Array = []
	if step.has("layers") and step["layers"] is Array:
		layers = step["layers"]
	else:
		layers = [step]
	var handled_sides: Array[StringName] = []
	_image_tween = create_tween()
	_image_tween.set_parallel(true)
	for layer_data in layers:
		if not (layer_data is Dictionary):
			continue
		var side := String(layer_data.get("side", SIDE_BACKGROUND)).to_lower()
		if not _image_targets.has(side):
			continue
		handled_sides.append(side)
		var rect: TextureRect = _image_targets[side]
		var texture: Texture2D = _resolve_texture(layer_data)
		var fade_in := float(layer_data.get("fade_in", fade_duration))
		var fade_out := float(layer_data.get("fade_out", fade_duration))
		if texture != null:
			var tex_size = texture.get_size()
			var scale_x = max_image_size.x / tex_size.x if tex_size.x > 0 else 1.0
			var scale_y = max_image_size.y / tex_size.y if tex_size.y > 0 else 1.0
			var image_scale = min(1.0, scale_x, scale_y)
			var new_size = tex_size * image_scale
			var final_size: Vector2 = new_size
			# ensure the rect won't expand to the texture and respects our size
			if side == SIDE_BACKGROUND:
				rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
				rect.stretch_mode = TextureRect.STRETCH_SCALE
			else:
				rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if side != SIDE_BACKGROUND:
				rect.scale = Vector2.ONE
				# compute final clamped size and consistently use it for offsets
				final_size = Vector2(min(new_size.x, max_image_size.x), min(new_size.y, max_image_size.y))
				# Use offsets to determine the Rect size so the Control layout isn't fighting our size
				if side == SIDE_LEFT:
					var left_offset := 64
					rect.offset_left = left_offset
					rect.offset_right = left_offset + int(final_size.x)
					rect.offset_top = -int(final_size.y / 2)
					rect.offset_bottom = int(final_size.y / 2)
				elif side == SIDE_RIGHT:
					var right_offset := -64
					rect.offset_right = right_offset
					rect.offset_left = right_offset - int(final_size.x)
					rect.offset_top = -int(final_size.y / 2)
					rect.offset_bottom = int(final_size.y / 2)
			# set texture after offsets/sizing to avoid the texture changing the rect
			if rect.texture != texture:
				rect.texture = texture
			# Debug logging
			if debug_image_sizing:
				if side != SIDE_BACKGROUND:
					print("Credits: side=", side, "tex_size=", tex_size, "new_size=", new_size, "final_size=", final_size, "rect.size=", rect.size, "offsets=", rect.offset_left, rect.offset_right, rect.offset_top, rect.offset_bottom)
				else:
					print("Credits: side=", side, "tex_size=", tex_size, "new_size=", new_size, "rect.size=", rect.size)
			_image_tween.tween_property(rect, "modulate:a", 1.0, max(fade_in, 0.05))
			# Defer a size check to the next frame to enforce offsets against any layout changes
			if side != SIDE_BACKGROUND:
				call_deferred("_enforce_rect_size", rect, final_size, side)
		else:
			# restore initial offsets/size when clearing images
			if _image_initial_offsets.has(side):
				var init: Dictionary = _image_initial_offsets[side]
				rect.offset_left = init["left"]
				rect.offset_right = init["right"]
				rect.offset_top = init["top"]
				rect.offset_bottom = init["bottom"]
			rect.size = Vector2.ZERO
			rect.custom_minimum_size = Vector2.ZERO
			rect.texture = null
			_image_tween.tween_property(rect, "modulate:a", 0.0, max(fade_out, 0.05))
	for side_key in _image_targets.keys():
		if side_key in handled_sides:
			continue
		var rect: TextureRect = _image_targets[side_key]
		_image_tween.tween_property(rect, "modulate:a", 0.0, max(fade_duration, 0.05))
	var duration := float(step.get("duration", _default_image_duration()))
	if duration > 0.0:
		_cycle_timer.stop()
		_cycle_timer.wait_time = duration
		_cycle_timer.start()


func _resolve_texture(layer_data: Dictionary) -> Texture2D:
	if layer_data.has("texture") and layer_data["texture"] is Texture2D:
		return layer_data["texture"]
	if layer_data.has("path"):
		var resource_path := String(layer_data["path"]).strip_edges()
		if resource_path == "":
			return null
		return _load_texture(resource_path)
	return null


func _load_texture(resource_path: String) -> Texture2D:
	if _texture_cache.has(resource_path):
		return _texture_cache[resource_path]
	var texture: Texture2D = ResourceLoader.load(resource_path)
	if texture != null:
		_texture_cache[resource_path] = texture
		return texture
	push_warning("Credits: Unable to load texture at %s" % resource_path)
	return null


func _add_section(section: Dictionary) -> void:
	var header_text := String(section.get("header", "")).strip_edges()
	if header_text != "":
		var header_label := _create_label(true, section)
		header_label.append_text(_format_header(header_text, section))
		_content.add_child(header_label)
	var entries: Array = section.get("entries", [])
	if entries is Array:
		for entry in entries:
			var entry_text := String(entry).strip_edges()
			if entry_text == "":
				continue
			var entry_label := _create_label(false, section)
			entry_label.append_text(_format_entry(entry_text, section))
			_content.add_child(entry_label)


func _add_section_spacing() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, section_spacing)
	_content.add_child(spacer)


func _create_label(is_header: bool, section: Dictionary) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.scroll_active = false
	var centered := bool(section.get("center", is_header))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	if section.has("text_color"):
		label.add_theme_color_override("default_color", section["text_color"])
	if is_header:
		label.add_theme_font_size_override("normal_font_size", int(roundi(28.0 * header_scale)))
		var accent: Color = section.get("accent_color", Color(0.9, 0.85, 0.55))
		label.add_theme_color_override("default_color", accent)
	else:
		label.add_theme_font_size_override("normal_font_size", 22)
	return label


func _format_header(text: String, section: Dictionary) -> String:
	if bool(section.get("wave", true)):
		return "[center][wave amp=20 freq=4]" + text + "[/wave][/center]"
	return "[center]" + text + "[/center]"


func _format_entry(text: String, section: Dictionary) -> String:
	if bool(section.get("bullet", false)):
		return "• " + text
	return text


func _on_back_button_pressed() -> void:
	ScreenRotator.change_scene("res://Scenes/game_menu2.tscn")


func _enforce_rect_size(rect: TextureRect, expected_size: Vector2, side: String) -> void:
	# Wait one frame so Control layout can run
	await get_tree().process_frame
	if not is_instance_valid(rect):
		return
	var actual := rect.size
	# gather family layout info
	var parent := rect.get_parent()
	var parent_size: Vector2 = Vector2.ZERO
	if parent != null:
		parent_size = parent.size
	if actual == expected_size:
		if debug_image_sizing:
			print("Credits: enforce check OK: side=", side, "actual=sizeOK=", actual)
		return
	# Layout has adjusted the rect size; reapply offsets that produce our expected size
	if side == SIDE_LEFT:
		rect.offset_left = 64
		rect.offset_right = 64 + int(expected_size.x)
		rect.offset_top = -int(expected_size.y / 2)
		rect.offset_bottom = int(expected_size.y / 2)
	elif side == SIDE_RIGHT:
		rect.offset_right = -64
		rect.offset_left = -64 - int(expected_size.x)
		rect.offset_top = -int(expected_size.y / 2)
		rect.offset_bottom = int(expected_size.y / 2)
	# Force the rect size and minimum sizes to match expected
	rect.custom_minimum_size = expected_size
	rect.size = expected_size
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# After reapplying, log full context for debugging
	if debug_image_sizing:
		print("Credits: enforced rect size for side=", side, "expected=", expected_size, "actual=", rect.size, "parent_size=", parent_size, "anchors=", rect.anchor_left, rect.anchor_right, rect.anchor_top, rect.anchor_bottom, "size_flags=", rect.size_flags_horizontal, rect.size_flags_vertical, "custom_minimum_size=", rect.custom_minimum_size)
	# If layout still overrides and rect.size does not match, compute a scale fallback.
	await get_tree().process_frame
	if not is_instance_valid(rect):
		return
	if rect.size != expected_size:
		var fallback_scale: Vector2 = Vector2(expected_size.x / rect.size.x if rect.size.x > 0 else 1.0, expected_size.y / rect.size.y if rect.size.y > 0 else 1.0)
		# Use the smaller scale to preserve aspect ratio
		var uniform_scale: float = min(fallback_scale.x, fallback_scale.y)
		rect.scale = Vector2(uniform_scale, uniform_scale)
		if debug_image_sizing:
			print("Credits: fallback scaling applied for side=", side, "uniform_scale=", uniform_scale, "post_scale_size=", rect.size * rect.scale)
	# In case the Control layout still overrides our changes, log it for debug
	if debug_image_sizing:
		print("Credits: enforced rect size for side=", side, "expected=", expected_size, "actual=", rect.size)
