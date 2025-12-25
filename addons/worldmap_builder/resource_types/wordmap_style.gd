@tool
class_name FW_WorldmapStyle
extends Resource

## Tint icons by this color, white to draw unchanged.
@export var icon_modulate := Color.WHITE
## Tint icon borders by this color, white to draw unchanged.
@export var icon_border_modulate := Color.WHITE
## Tint connection lines by this color, white to draw unchanged.
@export var connection_modulate := Color.WHITE

## Texture drawn over every icon, for each [member FW_WorldmapNodeData.size_tier].
@export var icon_borders : Array[Texture2D]
## Automatically scale border to match node size. If false, uses size_tier to pick from icon_borders array.
@export var auto_scale_border := true
## Base border texture to scale when auto_scale_border is true. Uses first border in icon_borders if not set.
@export var base_border_texture : Texture2D
## Texture drawn over straight connections. If none, draws solid lines.
@export var straight_tex : Texture2D
## The UV region of [member straight_tex], in pixels.
@export var straight_tex_region := Rect2()
## Repeats the texture. Make sure it's configured to repeat.
@export var straight_tex_repeat := false

## If a line is drawn between nodes with different styles, the one with higher priority will be used._add_cell_to_selection
@export var priority := 0


func draw_node(canvas : CanvasItem, data : FW_WorldmapNodeData, pos : Vector2):
	if data == null || data.texture == null:
		return

	# Draw the main node texture
	var node_size := data.texture.get_size()
	canvas.draw_texture(data.texture, pos - node_size * 0.5)

	# Draw the border
	if auto_scale_border:
		# Use dynamic scaling approach
		var border_texture := base_border_texture if base_border_texture != null else (icon_borders[0] if icon_borders.size() > 0 else null)
		if border_texture != null:
			var border_size := border_texture.get_size()
			var scale_factor := maxf(node_size.x / border_size.x, node_size.y / border_size.y)

			# Create a scaled version using draw_texture_rect
			var scaled_border_size := border_size * scale_factor
			var border_rect := Rect2(pos - scaled_border_size * 0.5, scaled_border_size)
			canvas.draw_texture_rect(border_texture, border_rect, false, icon_border_modulate)
	else:
		# Use traditional size_tier approach
		if icon_borders.size() > 0:
			var used_border := icon_borders[mini(data.size_tier, icon_borders.size() - 1)]
			canvas.draw_texture(used_border, pos - used_border.get_size() * 0.5, icon_border_modulate)


func draw_connection(canvas_parent: Node, other: FW_WorldmapStyle, pos1: Vector2, pos2: Vector2):
	if other.priority > priority:
		other.draw_connection(canvas_parent, other, pos2, pos1)
		return

	# Ensure pos1 is to the left
	if pos1.x > pos2.x:
		var temp := pos1
		pos1 = pos2
		pos2 = temp

	var direction := pos2 - pos1
	var length := direction.length()
	var angle := direction.angle()

	var tex_size := straight_tex.get_size()
	var uv_region := Rect2(straight_tex_region.position / tex_size, straight_tex_region.size / tex_size)
	var uv_x_end := length / tex_size.x if straight_tex_repeat else uv_region.end.x

	var half_width := tex_size.y * uv_region.size.y / 2.0
	var normal := Vector2(direction.y, -direction.x).normalized() * half_width

	# Define local points relative to pos1 (origin)
	var local_points := [
		- normal,
		+ normal,
		direction + normal,
		direction - normal
	]

	var uvs := [
		Vector2(uv_region.position.x, uv_region.end.y),
		uv_region.position,
		Vector2(uv_x_end, uv_region.position.y),
		Vector2(uv_x_end, uv_region.end.y)
	]

	var poly := Polygon2D.new()
	poly.position = pos1
	poly.polygon = local_points
	poly.uv = uvs
	poly.texture = straight_tex
	poly.modulate = connection_modulate
	poly.z_index = -1  # Render behind nodes

	if other.resource_name == "Active":
		var shader := ShaderMaterial.new()
		shader.shader = load("res://Shaders/sparkle.gdshader")
		poly.material = shader

		var particles := CPUParticles2D.new()
		particles.one_shot = true
		particles.emitting = true
		particles.texture = preload("res://Effects/SkillTree/particle_star.png")
		particles.amount = 64
		particles.lifetime = 1.5
		particles.speed_scale = 1.0

		# Emit along the angled line
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(length / 2.0, half_width)
		particles.position = direction / 2.0  # center along the line
		particles.rotation = angle

		particles.direction = Vector2(0, -1)  # local up
		particles.gravity = Vector2(0, 200)
		particles.initial_velocity_max = 50
		particles.initial_velocity_min = 20
		particles.scale_amount_max = 0.5
		particles.scale_amount_min = 0.3

		var grad := Gradient.new()
		grad.add_point(0.0, Color.WHITE)
		grad.add_point(1.0, Color(1, 1, 1, 0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = grad
		particles.color_ramp = grad
		poly.add_child(particles)

	elif other.resource_name == "Can Activate":
		var shader := ShaderMaterial.new()
		shader.shader = load("res://Shaders/sparkle.gdshader")
		shader.set_shader_parameter("glow_color", Color.SEA_GREEN)
		poly.material = shader

	canvas_parent.add_child(poly)
