extends PanelContainer

class_name FW_CustomPopupMenu

signal index_pressed(index)

@onready var item_list: VBoxContainer = $MarginContainer/ItemList

var menu_items = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

func add_item(label: String, icon: Texture2D = null, id: int = -1):
	var item_id = id if id != -1 else menu_items.size()
	menu_items.append({"label": label, "icon": icon, "id": item_id, "disabled": false})

func set_item_disabled(index: int, disabled: bool):
	if index >= 0 and index < menu_items.size():
		menu_items[index]["disabled"] = disabled

func popup(rect: Rect2):
	# Clear previous items
	for child in item_list.get_children():
		child.queue_free()

	# Create new items
	for i in range(menu_items.size()):
		var item = menu_items[i]
		var button: Button

		if item["icon"]:
			# Create complex layout for items with icons
			var container = HBoxContainer.new()
			container.add_theme_constant_override("separation", 12)
			container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var icon_rect = TextureRect.new()
			icon_rect.texture = item["icon"]
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.size = Vector2(32, 32)
			icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			container.add_child(icon_rect)

			var label = Label.new()
			label.text = item["label"]
			label.add_theme_font_size_override("font_size", 32)
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(label)

			# Create button container
			button = Button.new()
			button.add_child(container)
			button.custom_minimum_size = Vector2(0, 48)  # Minimum height for touch targets
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			# Force button to update its minimum size after adding container
			container.update_minimum_size()
			button.update_minimum_size()
		else:
			# Simple button for items without icons (backward compatibility)
			button = Button.new()
			button.text = item["label"]
			button.add_theme_font_size_override("font_size", 32)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Common button setup
		button.disabled = item["disabled"]
		button.pressed.connect(_on_item_pressed.bind(i))

		# Alternate background color for contrast
		var base_color = Color(0.18, 0.18, 0.18)
		var alt_color = Color(0.24, 0.24, 0.24)
		button.add_theme_color_override("bg_color", base_color if i % 2 == 0 else alt_color)

		# Add hover effect
		var original_color = base_color if i % 2 == 0 else alt_color
		button.mouse_entered.connect(func():
			button.add_theme_color_override("bg_color", Color(0.32, 0.32, 0.38))
			if item["icon"]:
				button.get_child(0).scale = Vector2(1.02, 1.02)
			else:
				button.scale = Vector2(1.04, 1.04)
		)
		button.mouse_exited.connect(func():
			button.add_theme_color_override("bg_color", original_color)
			if item["icon"]:
				button.get_child(0).scale = Vector2.ONE
			else:
				button.scale = Vector2.ONE
		)

		item_list.add_child(button)

		# Add separator after each item except the last
		if i < menu_items.size() - 1:
			var sep = ColorRect.new()
			sep.color = Color(0.08, 0.08, 0.08)
			sep.custom_minimum_size = Vector2(0, 4)
			item_list.add_child(sep)

	# Force layout update to ensure proper sizing
	item_list.update_minimum_size()
	item_list.queue_redraw()

	# Calculate required popup size based on content
	var max_width := 0.0
	var total_height := 0.0

	for child in item_list.get_children():
		if child is Button:
			var button_width := 0.0
			if child.get_child_count() > 0 and child.get_child(0) is HBoxContainer:
				# Button with icon - calculate width manually
				var container = child.get_child(0) as HBoxContainer
				var label = container.get_child(1) as Label

				# Icon width + separation + text width
				button_width = 32 + 12 + label.get_minimum_size().x
			else:
				# Button without icon - measure text
				var font = child.get_theme_font("font")
				var font_size = child.get_theme_font_size("font_size")
				button_width = font.get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

			max_width = max(max_width, button_width)
			total_height += 48  # Button height
		elif child is ColorRect:
			total_height += child.custom_minimum_size.y

	# Add generous padding
	max_width += 60  # Horizontal padding (increased)
	total_height += 30  # Vertical padding (increased)

	# Set explicit minimum size for the popup
	custom_minimum_size = Vector2(max_width, total_height)
	size = Vector2(max_width, total_height)	# Show popup with correct size
	show()
	await get_tree().process_frame

	# Clamp position to stay within the viewport
	var viewport_rect = get_viewport_rect()
	var popup_size = size
	var pos = rect.position

	if pos.x + popup_size.x > viewport_rect.size.x:
		pos.x = viewport_rect.size.x - popup_size.x
	if pos.y + popup_size.y > viewport_rect.size.y:
		pos.y = viewport_rect.size.y - popup_size.y

	pos.x = max(0, pos.x)
	pos.y = max(0, pos.y)

	position = pos

	# Add drop shadow to popup
	self.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	var stylebox := self.get_theme_stylebox("panel") as StyleBoxFlat
	stylebox.bg_color = Color(0.12, 0.12, 0.12)
	stylebox.shadow_color = Color(0, 0, 0, 0.5)
	stylebox.shadow_size = 16
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12

func _on_item_pressed(index: int):
	emit_signal("index_pressed", index)
	hide()

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.is_pressed() and not get_rect().has_point(get_local_mouse_position()):
		hide()
