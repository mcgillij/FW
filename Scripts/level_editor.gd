extends Node

var current_obstacle: String = ""
var obstacle_active: bool = false
signal screen_fade_in
signal screen_fade_out

signal make_concrete
signal make_ice
signal make_lock
signal make_slime
signal make_pink_slime
signal make_heavy_concrete

func place_obstacle() -> void:
	if current_obstacle == "concrete":
		emit_signal("make_concrete")
	elif current_obstacle == "heavy_concrete":
		emit_signal("make_heavy_concrete")
	elif current_obstacle == "ice":
		emit_signal("make_ice")
	elif current_obstacle == "lock":
		emit_signal("make_lock")
	elif current_obstacle == "slime":
		emit_signal("make_slime")
	elif current_obstacle == "pink_slime":
		emit_signal("make_pink_slime")
	obstacle_pressed(current_obstacle)

func obstacle_pressed(obstacle_type: String) -> void:
	if obstacle_active:
		current_obstacle = ""
		emit_signal("screen_fade_out")
		obstacle_active = false
	elif !obstacle_active:
		current_obstacle = obstacle_type
		emit_signal("screen_fade_in")
		obstacle_active = true

func _on_obstacles_ui_level_edit_concrete() -> void:
	obstacle_pressed("concrete")

func _on_obstacles_ui_level_edit_heavy_concrete() -> void:
	obstacle_pressed("heavy_concrete")

func _on_obstacles_ui_level_edit_ice() -> void:
	obstacle_pressed("ice")

func _on_obstacles_ui_level_edit_lock() -> void:
	obstacle_pressed("lock")

func _on_obstacles_ui_level_edit_slime() -> void:
	obstacle_pressed("slime")

func _on_obstacles_ui_level_edit_pink_slime() -> void:
	obstacle_pressed("pink_slime")

func _on_grid_level_edit_input(in_grid: bool) -> void:
	if in_grid and obstacle_active:
		place_obstacle()
	elif !in_grid and obstacle_active:
		obstacle_pressed(current_obstacle)
