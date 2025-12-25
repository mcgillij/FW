extends Resource
class_name FW_SolitaireLayoutMetrics

@export var card_width: float = 80.0
@export var card_height: float = 120.0
@export var tableau_vertical_spacing: float = 30.0
@export var tableau_horizontal_gap: float = 15.0
@export var waste_fan_horizontal_offset: float = 20.0
@export var waste_fan_vertical_offset: float = 4.0
@export var drag_start_threshold: float = 5.0
@export var double_click_time: float = 0.5
@export var card_corner_radius: float = 8.0
@export var card_border_width: float = 2.0
@export var card_shadow_size: float = 2.0
@export var card_shadow_offset: Vector2 = Vector2(1, 1)
@export var foundation_slot_size: Vector2 = Vector2(96, 136)
@export var tableau_slot_size: Vector2 = Vector2(96, 136)
@export var stock_slot_size: Vector2 = Vector2(96, 136)
@export var waste_slot_size: Vector2 = Vector2(96, 136)
@export var slot_corner_radius: float = 8.0
@export var slot_border_width: float = 2.0
@export var corner_rank_font_size: int = 32
@export var corner_symbol_font_size: int = 32
@export var center_pip_font_size: int = 48
@export var center_face_font_size: int = 32
@export var margin_left: float = 4.0
@export var margin_top: float = 6.0
@export var margin_right: float = 3.0
@export var margin_bottom: float = 4.0

func get_card_size() -> Vector2:
	return Vector2(card_width, card_height)

func get_foundation_slot_size() -> Vector2:
	return foundation_slot_size if foundation_slot_size.length_squared() > 0.0 else get_card_size()

func get_tableau_slot_size() -> Vector2:
	return tableau_slot_size if tableau_slot_size.length_squared() > 0.0 else get_card_size()

func get_stock_slot_size() -> Vector2:
	return stock_slot_size if stock_slot_size.length_squared() > 0.0 else get_card_size()

func get_waste_slot_size() -> Vector2:
	return waste_slot_size if waste_slot_size.length_squared() > 0.0 else get_card_size()
