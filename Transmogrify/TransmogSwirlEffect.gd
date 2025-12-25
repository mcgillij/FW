extends Control
class_name FW_TransmogSwirlEffect

signal effect_finished

const FULLSCREEN_SHADER_PATH := "res://Shaders/transmog_fullscreen_flash.gdshader"

@export var orbit_radius := 220.0
@export var orbit_duration := 1.6
@export var orbit_rotations := 1.5
@export var merge_duration := 0.45
@export var icon_size := Vector2(96, 96)
@export var merge_scale := 1.25
@export var overlay_intensity := 0.85
@export var overlay_flash_scale := 1.6
@export var burst_particle_count := 42
@export var burst_radius := 260.0
@export var burst_duration := 0.55

var icons: Array[TextureRect] = []
var center: Vector2

var overlay_rect: ColorRect
var overlay_active := false
var _overlay_progress := 0.0
var _overlay_flash := 0.0
var _overlay_time := 0.0

var particle_texture: Texture2D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	center = get_viewport_rect().size * 0.5
	resized.connect(_on_resized)
	_ensure_overlay()
	_init_particle_resources()
	rng.randomize()
	set_process(false)

func play_effect(textures: Array[Texture2D]) -> void:
	_clear_icons()
	if textures.is_empty():
		_finish()
		return
	await get_tree().process_frame
	center = get_viewport_rect().size * 0.5
	for i in range(textures.size()):
		var icon := _create_icon(textures[i])
		var angle := float(i) / float(textures.size()) * TAU
		icons.append(icon)
		_set_icon_position(icon, angle)
	_start_orbit()

func _create_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.size = icon_size
	icon.pivot_offset = icon_size * 0.5
	icon.scale = Vector2.ONE
	add_child(icon)
	return icon

func _set_icon_position(icon: TextureRect, angle: float) -> void:
	var offset := Vector2.from_angle(angle) * orbit_radius
	icon.position = center + offset - icon.pivot_offset

func _start_orbit() -> void:
	if icons.is_empty():
		_finish()
		return
	var count := icons.size()
	overlay_active = true
	set_process(true)
	_overlay_time = 0.0
	_set_overlay_progress(0.0)
	_set_overlay_flash(0.0)
	if overlay_rect:
		overlay_rect.visible = true
		overlay_rect.modulate = Color(1, 1, 1, 1)
	var orbit := create_tween()
	orbit.set_parallel(true)
	for i in range(count):
		var icon := icons[i]
		var start_angle := float(i) / float(count) * TAU
		var end_angle := start_angle - orbit_rotations * TAU
		var tweener := orbit.tween_method(Callable(self, "_apply_angle").bind(icon), start_angle, end_angle, orbit_duration)
		tweener.set_trans(Tween.TRANS_SINE)
		tweener.set_ease(Tween.EASE_IN_OUT)
	var overlay_tween := create_tween()
	overlay_tween.tween_method(Callable(self, "_set_overlay_progress"), _overlay_progress, 0.95, orbit_duration)
	overlay_tween.set_trans(Tween.TRANS_SINE)
	overlay_tween.set_ease(Tween.EASE_OUT)
	orbit.finished.connect(_on_orbit_finished)

func _apply_angle(angle: float, icon: TextureRect) -> void:
	_set_icon_position(icon, angle)
	icon.rotation = angle

func _on_orbit_finished() -> void:
	_merge_icons()

func _merge_icons() -> void:
	if icons.is_empty():
		_finish()
		return
	var merge := create_tween()
	merge.set_parallel(true)
	for icon in icons:
		var tweener := merge.tween_property(icon, "position", center - icon.pivot_offset, merge_duration)
		tweener.set_trans(Tween.TRANS_BACK)
		tweener.set_ease(Tween.EASE_IN)
		var scale_tweener := merge.tween_property(icon, "scale", Vector2(merge_scale, merge_scale), merge_duration)
		scale_tweener.set_trans(Tween.TRANS_BACK)
		scale_tweener.set_ease(Tween.EASE_IN)
	var overlay_tween := create_tween()
	overlay_tween.tween_method(Callable(self, "_set_overlay_progress"), _overlay_progress, 1.25, merge_duration)
	overlay_tween.set_trans(Tween.TRANS_BACK)
	overlay_tween.set_ease(Tween.EASE_IN)
	merge.finished.connect(_on_merge_complete)

func _on_merge_complete() -> void:
	_trigger_particle_burst()
	var flash := create_tween()
	flash.tween_method(Callable(self, "_set_overlay_flash"), _overlay_flash, overlay_flash_scale, 0.18)
	flash.set_trans(Tween.TRANS_QUAD)
	flash.set_ease(Tween.EASE_OUT)
	flash.tween_method(Callable(self, "_set_overlay_flash"), overlay_flash_scale, 0.0, 0.32)
	flash.set_trans(Tween.TRANS_QUAD)
	flash.set_ease(Tween.EASE_IN)
	await flash.finished
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_method(Callable(self, "_set_overlay_progress"), _overlay_progress, 0.0, 0.22)
	if overlay_rect:
		fade.tween_property(overlay_rect, "modulate:a", 0.0, 0.22)
	await fade.finished
	_finish()

func _finish() -> void:
	overlay_active = false
	set_process(false)
	if overlay_rect:
		overlay_rect.visible = false
	emit_signal("effect_finished")
	queue_free()

func _clear_icons() -> void:
	for icon in icons:
		if is_instance_valid(icon):
			icon.queue_free()
	icons.clear()

func _on_resized() -> void:
	center = size * 0.5

func _ensure_overlay() -> void:
	if overlay_rect:
		return
	var shader_resource := load(FULLSCREEN_SHADER_PATH)
	var shader_material: ShaderMaterial = null
	if shader_resource:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader_resource
		shader_material.set_shader_parameter("u_progress", 0.0)
		shader_material.set_shader_parameter("u_flash", 0.0)
		shader_material.set_shader_parameter("u_intensity", overlay_intensity)
		shader_material.set_shader_parameter("u_base_color", Color(0.06, 0.02, 0.11, 0.22))
		shader_material.set_shader_parameter("u_highlight_color", Color(0.9, 0.85, 1.0, 0.95))
	overlay_rect = ColorRect.new()
	overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_rect.color = Color(0, 0, 0, 0)
	overlay_rect.z_index = 1200
	if shader_material:
		overlay_rect.material = shader_material
	overlay_rect.visible = false
	add_child(overlay_rect)
	overlay_rect.move_to_front()

func _init_particle_resources() -> void:
	particle_texture = _create_particle_texture()

func _set_overlay_progress(value: float) -> void:
	_overlay_progress = value
	_update_overlay_uniforms()

func _set_overlay_flash(value: float) -> void:
	_overlay_flash = value
	_update_overlay_uniforms()

func _update_overlay_uniforms() -> void:
	if overlay_rect and overlay_rect.material:
		var mat: ShaderMaterial = overlay_rect.material
		mat.set_shader_parameter("u_progress", _overlay_progress)
		mat.set_shader_parameter("u_flash", _overlay_flash)

func _process(delta: float) -> void:
	if not overlay_active or not overlay_rect or not overlay_rect.material:
		return
	_overlay_time += delta
	var mat: ShaderMaterial = overlay_rect.material
	mat.set_shader_parameter("u_time", _overlay_time)

func _trigger_particle_burst() -> void:
	if not particle_texture:
		particle_texture = _create_particle_texture()
	for i in range(burst_particle_count):
		var shard := TextureRect.new()
		shard.texture = particle_texture
		shard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shard.stretch_mode = TextureRect.STRETCH_SCALE
		shard.size = Vector2(28, 28)
		shard.pivot_offset = shard.size * 0.5
		shard.scale = Vector2(rng.randf_range(0.5, 1.2), rng.randf_range(0.5, 1.2))
		shard.modulate = Color(1, 1, 1, 0.0)
		shard.position = center - shard.pivot_offset
		shard.z_index = 1300
		add_child(shard)
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(burst_radius * 0.35, burst_radius)
		var target := center + Vector2.from_angle(angle) * distance - shard.pivot_offset
		var shard_tween := create_tween()
		shard_tween.set_parallel(true)
		var move := shard_tween.tween_property(shard, "position", target, burst_duration)
		move.set_trans(Tween.TRANS_SINE)
		move.set_ease(Tween.EASE_OUT)
		var fade := shard_tween.tween_property(shard, "modulate", Color(1, 1, 1, 0.0), burst_duration)
		fade.set_trans(Tween.TRANS_QUAD)
		fade.set_ease(Tween.EASE_IN)
		fade.from(Color(1, 1, 1, 1))
		var shrink := shard_tween.tween_property(shard, "scale", Vector2.ZERO, burst_duration)
		shrink.set_trans(Tween.TRANS_QUAD)
		shrink.set_ease(Tween.EASE_IN)
		shard_tween.finished.connect(shard.queue_free)

func _create_particle_texture() -> Texture2D:
	var tex_size := 64
	var image := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var half := tex_size * 0.5
	var center_point := Vector2(half, half)
	var radius := half - 1.0
	for y in range(tex_size):
		for x in range(tex_size):
			var pos := Vector2(float(x), float(y))
			var dist := pos.distance_to(center_point)
			var norm: float = clamp(1.0 - dist / radius, 0.0, 1.0)
			var alpha := pow(norm, 1.5)
			var color := Color(0.95, 0.92, 0.6, alpha)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

