extends Node2D

#signals

signal remove_slime

var slime_pieces: Array = []
var slime: PackedScene = preload("res://Scenes/slime.tscn")
@export var value: String

func _on_grid_make_slime(board_position: Vector2) -> void:
    if slime_pieces.size() == 0:
        slime_pieces = GDM.make_2d_array()
    var current = slime.instantiate()
    add_child(current)
    current.position = Vector2(board_position.x * GDM.grid.x_start + GDM.grid.offset, -board_position.y * GDM.grid.offset + GDM.grid.y_start)
    slime_pieces[board_position.x][board_position.y] = current

func _on_grid_damage_slime(board_position: Vector2) -> void:
    if slime_pieces.size() != 0:
        if slime_pieces[board_position.x][board_position.y]:
            slime_pieces[board_position.x][board_position.y].take_damage(1)
            if slime_pieces[board_position.x][board_position.y].health <= 0:
                slime_pieces[board_position.x][board_position.y].queue_free()
                slime_pieces[board_position.x][board_position.y] = null
                emit_signal("remove_slime", value, board_position)
