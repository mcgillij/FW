extends Node2D

class_name FW_JadestrikeGemsEffect

signal finished

@export var gem_texture: Texture2D
@export var particle_scene: PackedScene
@export var gem_color: Color = Color(0.0, 1.0, 0.0, 1.0)  # Bright green
@export var animation_duration: float = 2.0
@export var gem_scale: float = 1.5
@export var use_particles: bool = true

var _gems: Array = []
var _particles: Array = []

func start(params: Dictionary) -> void:
	var duration = params.get("duration", animation_duration)
	# Debug: log invocation so we can trace whether the scene effect is instantiated
	FW_Debug.debug_log(["JadestrikeGems.start called: params=%s" % str(params)])

	# Prefer manager-projected screen positions if available.
	# CombatVisualEffectsManager will project `grid_cells` into `nodes` (screen pixels)
	# for scene effects. If `nodes` is present, use it directly. Otherwise fall back
	# to `grid_cells` and project them locally.
	var nodes = params.get("nodes", [])
	var positions = []

	if nodes and typeof(nodes) == TYPE_ARRAY and nodes.size() > 0:
		# Already in screen pixels
		positions = nodes
		FW_Debug.debug_log(["JadestrikeGems: using manager-provided nodes (screen pixels) = %s" % str(positions)])
	else:
		# Fall back to canonical `grid_cells` (set by EffectResource when available)
		var gc = params.get("grid_cells", [])
		if gc.is_empty():
			finished.emit()
			queue_free()
			return
		# Convert grid cell coords to screen pixels
		for gp in gc:
			positions.append(grid_to_screen(gp))
		FW_Debug.debug_log(["JadestrikeGems: computed positions from grid_cells = %s" % str(positions)])
		var vp = get_viewport()
		if vp:
			FW_Debug.debug_log(["JadestrikeGems: viewport_size=%s" % str(vp.get_visible_rect().size)])

	# Load textures if not set
	if not gem_texture:
		gem_texture = load("res://Abilities/Images/FW_Jadestrike.png")

	if not particle_scene and use_particles:
		particle_scene = load("res://Scenes/destroy_particle.tscn")

	for screen_pos in positions:
		if not screen_pos.is_finite():
			continue  # Skip invalid positions to prevent crashes
		# Create main gem sprite
		var gem = Sprite2D.new()
		gem.texture = gem_texture
		gem.modulate = gem_color
		gem.scale = Vector2(gem_scale, gem_scale)

		gem.position = screen_pos

		add_child(gem)
		_gems.append(gem)

		# Create particle effect if available
		if particle_scene and use_particles:
			var particles = particle_scene.instantiate()
			if particles:
				particles.position = screen_pos
				add_child(particles)
				_particles.append(particles)

				# Start particle emission
				if particles is Node2D and particles.has_node("CPUParticles2D"):
					var cpu_particles = particles.get_node("CPUParticles2D")
					if cpu_particles:
						cpu_particles.emitting = true

		# Enhanced animation: grow then settle with rotation and glow
		# Start small and invisible
		gem.scale = Vector2(0.1, 0.1)
		gem.modulate.a = 0.0

		# Scale animation: grow to half size, then settle to normal size
		var scale_tween = get_tree().create_tween()
		scale_tween.tween_property(gem, "scale", Vector2(gem_scale * 0.5, gem_scale * 0.5), duration * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(gem, "scale", Vector2(gem_scale, gem_scale), duration * 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

		# Fade in animation
		var fade_tween = get_tree().create_tween()
		fade_tween.tween_property(gem, "modulate:a", 1.0, duration * 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		# Continuous rotation
		var rotation_tween = get_tree().create_tween()
		rotation_tween.tween_property(gem, "rotation", TAU * 2, duration).set_trans(Tween.TRANS_LINEAR)

		# Subtle pulsing glow effect
		var glow_tween = get_tree().create_tween()
		glow_tween.set_loops()
		glow_tween.tween_property(gem, "modulate", gem_color * 1.2, duration * 0.3).set_trans(Tween.TRANS_SINE)
		glow_tween.tween_property(gem, "modulate", gem_color, duration * 0.3).set_trans(Tween.TRANS_SINE)

		# Fade out at the end
		var fade_out_tween = get_tree().create_tween()
		fade_out_tween.tween_property(gem, "modulate:a", 0.0, duration * 0.3).set_delay(duration * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Wait for animation to complete (outside the loop)
	await get_tree().create_timer(duration).timeout

	# Clean up particles
	for particle in _particles:
		if particle and is_instance_valid(particle):
			particle.queue_free()

	finished.emit()
	queue_free()

func grid_to_screen(grid_pos: Vector2) -> Vector2:
	# Convert grid coordinates to screen/pixel coordinates
	if typeof(GDM) != TYPE_NIL and GDM and GDM.grid and GDM.grid.has_method("grid_to_pixel"):
		# Start with world pixel position for the grid cell
		var world_px: Vector2 = GDM.grid.grid_to_pixel(grid_pos.x, grid_pos.y)

		# If there's an active Camera2D in the viewport, use it to project world -> screen
		var vp = get_viewport()
		if vp:
			var viewport_size = vp.get_visible_rect().size
			var viewport_center = viewport_size / 2.0

			var cam: Camera2D = vp.get_camera_2d()
			if cam and is_instance_valid(cam):
				# Camera global position represents the world pixel at the center of the viewport
				var cam_pos = cam.global_position if cam.has_method("global_position") else cam.position
				var screen_px = (world_px - cam_pos) * cam.zoom + viewport_center
				if screen_px.is_finite():
					return screen_px
				else:
					push_warning("JadestrikeGems: computed screen_px is not finite, returning ZERO")
					return Vector2.ZERO

			# Fallback: use Grid's notion of camera center (middle cell) like other codepaths
			var camera_pixel_pos = GDM.grid.grid_to_pixel(float(GDM.grid.width/2-0.5), float(GDM.grid.height/2-0.5))
			var adjusted_pixel_pos = world_px - camera_pixel_pos + viewport_center
			if adjusted_pixel_pos.is_finite():
				return adjusted_pixel_pos
			else:
				push_warning("JadestrikeGems: adjusted_pixel_pos is not finite, returning ZERO")
				return Vector2.ZERO
	else:
		push_warning("JadestrikeGemsEffect: Unable to convert grid to screen position")
		return Vector2.ZERO

	# Defensive fallback
	return Vector2.ZERO
