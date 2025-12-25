extends Node2D

#signals
signal remove_pink_slime

var pink_slime_pieces: Array = []
var pink_slime: PackedScene = preload("res://Scenes/pink_slime.tscn")
@export var value: String

func _on_grid_make_pink_slime(board_position: Vector2) -> void:
	if pink_slime_pieces.size() == 0:
		pink_slime_pieces = GDM.make_2d_array()
	var current = pink_slime.instantiate()
	add_child(current)
	current.position = Vector2(board_position.x * GDM.grid.x_start + GDM.grid.offset, -board_position.y * GDM.grid.offset + GDM.grid.y_start)
	pink_slime_pieces[board_position.x][board_position.y] = current

func _on_grid_damage_pink_slime(board_position: Vector2) -> void:
	if pink_slime_pieces.size() != 0:
		if pink_slime_pieces[board_position.x][board_position.y]:
			pink_slime_pieces[board_position.x][board_position.y].take_damage(1)
			if pink_slime_pieces[board_position.x][board_position.y].health <= 0:
				pink_slime_pieces[board_position.x][board_position.y].queue_free()
				pink_slime_pieces[board_position.x][board_position.y] = null
				emit_signal("remove_pink_slime", value, board_position)
