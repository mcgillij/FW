extends Node2D

#signals

signal remove_concrete

var concrete_pieces: Array = []
var concrete: PackedScene = preload("res://Scenes/concrete.tscn")

@export var value: String

func _on_grid_make_concrete(board_position: Vector2) -> void:
    if concrete_pieces.size() == 0:
        concrete_pieces = GDM.make_2d_array()
    var current = concrete.instantiate()
    add_child(current)
    current.position = Vector2(board_position.x * GDM.grid.x_start + GDM.grid.offset, -board_position.y * GDM.grid.offset + GDM.grid.y_start)
    concrete_pieces[board_position.x][board_position.y] = current

func _on_grid_damage_concrete(board_position: Vector2) -> void:
    if concrete_pieces.size() != 0:
        if concrete_pieces[board_position.x][board_position.y]:
            concrete_pieces[board_position.x][board_position.y].take_damage(1)
            if concrete_pieces[board_position.x][board_position.y].health <= 0:
                concrete_pieces[board_position.x][board_position.y].queue_free()
                concrete_pieces[board_position.x][board_position.y] = null
                emit_signal("remove_concrete", value, board_position)
