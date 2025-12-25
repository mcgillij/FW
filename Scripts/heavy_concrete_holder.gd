extends Node2D

signal remove_heavy_concrete

var heavy_concrete_pieces: Array = []
var heavy_concrete: PackedScene = preload("res://Scenes/heavy_concrete.tscn")

@export var value: String

func _on_grid_make_heavy_concrete(board_position: Vector2) -> void:
	if heavy_concrete_pieces.size() == 0:
		heavy_concrete_pieces = GDM.make_2d_array()
	var current = heavy_concrete.instantiate()
	add_child(current)
	current.position = Vector2(board_position.x * GDM.grid.x_start + GDM.grid.offset, -board_position.y * GDM.grid.offset + GDM.grid.y_start)
	heavy_concrete_pieces[board_position.x][board_position.y] = current

func _on_grid_damage_heavy_concrete(board_position: Vector2) -> void:
	if heavy_concrete_pieces.size() != 0:
		if heavy_concrete_pieces[board_position.x][board_position.y]:
			heavy_concrete_pieces[board_position.x][board_position.y].take_damage(1)
			if heavy_concrete_pieces[board_position.x][board_position.y].health <= 0:
				heavy_concrete_pieces[board_position.x][board_position.y].queue_free()
				heavy_concrete_pieces[board_position.x][board_position.y] = null
				emit_signal("remove_heavy_concrete", value, board_position)
