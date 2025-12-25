extends Node2D

#signals

signal remove_lock

var lock_pieces: Array = []
var lock: PackedScene = preload("res://Scenes/lock.tscn")
@export var value: String

func _on_grid_make_lock(board_position: Vector2) -> void:
    if lock_pieces.size() == 0:
        lock_pieces = GDM.make_2d_array()
    var current = lock.instantiate()
    add_child(current)
    current.position = Vector2(board_position.x * GDM.grid.x_start + GDM.grid.offset, -board_position.y * GDM.grid.offset + GDM.grid.y_start)
    lock_pieces[board_position.x][board_position.y] = current

func _on_grid_damage_lock(board_position: Vector2) -> void:
    if lock_pieces.size() != 0:
        if lock_pieces[board_position.x][board_position.y]:
            lock_pieces[board_position.x][board_position.y].take_damage(1)
            if lock_pieces[board_position.x][board_position.y].health <= 0:
                lock_pieces[board_position.x][board_position.y].queue_free()
                lock_pieces[board_position.x][board_position.y] = null
                emit_signal("remove_lock", value, board_position)
