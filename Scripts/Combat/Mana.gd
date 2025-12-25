extends Node

class_name FW_Mana
# can probably move this to a player class etc or split it, need to think about
# where it should live
var player: Dictionary = {
    "green": 0,
    "red": 0,
    "blue": 0,
    "orange": 0,
    "pink": 0
}

var enemy: Dictionary = {
    "green": 0,
    "red": 0,
    "blue": 0,
    "orange": 0,
    "pink": 0
}
