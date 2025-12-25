extends Node2D

var ice_pieces: Array = []
var ice: PackedScene = preload("res://Scenes/ice.tscn")

# goal signals

signal break_ice
@export var value: String

func _on_grid_make_ice(board_position: Vector2) -> void:
    if ice_pieces.size() == 0:
        ice_pieces = GDM.make_2d_array()
    var current = ice.instantiate()
    add_child(current)
    current.position = Vector2(board_position.x * GDM.grid.x_start + GDM.grid.offset, -board_position.y * GDM.grid.offset + GDM.grid.y_start)
    ice_pieces[board_position.x][board_position.y] = current

func _on_grid_damage_ice(board_position: Vector2) -> void:
    if ice_pieces.size() != 0:
        if ice_pieces[board_position.x][board_position.y]:
            ice_pieces[board_position.x][board_position.y].take_damage(1)
            if ice_pieces[board_position.x][board_position.y].health <= 0:
                ice_pieces[board_position.x][board_position.y].queue_free()
                ice_pieces[board_position.x][board_position.y] = null
                emit_signal("break_ice", value, board_position)
