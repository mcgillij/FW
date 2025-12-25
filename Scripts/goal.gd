extends Node

# goal information
@export var goal_texture: Texture2D
@export var max_needed: int
@export var goal_string: String

var number_collected: int = 0
var goal_met: bool = false

@export var is_piece_goal: bool

func check_goal(goal_type: String, amount: int = 1) -> void:
    if goal_type == goal_string:
        if is_piece_goal:
            if number_collected < max_needed:
                number_collected += amount
        else:
            number_collected = amount
        if number_collected >= max_needed:
            if !goal_met:
                goal_met = true
