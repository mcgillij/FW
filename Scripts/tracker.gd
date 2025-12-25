extends Node

class_name FW_Tracker

var damage_done := 0
var damage_done_bypassed_sheilds := 0
var damage_done_blocked_by_sheilds := 0
var ability_log := {}
var max_combo := 0
var highest_damage_hit := 0

var mana_gained := {
	"green": 0,
	"red": 0,
	"blue": 0,
	"orange": 0,
	"pink": 0
}
var mana_spent := {
	"green": 0,
	"red": 0,
	"blue": 0,
	"orange": 0,
	"pink": 0
}
var amount_healed := 0
var damage_taken := 0
var damage_taken_blocked := 0
var damage_taken_bypassed_sheilds := 0

func reset() -> void:
	damage_done = 0
	damage_done_bypassed_sheilds = 0
	damage_done_blocked_by_sheilds = 0
	ability_log.clear()
	max_combo = 0
	highest_damage_hit = 0
	for k in mana_gained.keys():
		mana_gained[k] = 0
	for k in mana_spent.keys():
		mana_spent[k] = 0
	amount_healed = 0
	damage_taken = 0
	damage_taken_blocked = 0
	damage_taken_bypassed_sheilds = 0

func add_to_ability_log(ability_name: String) -> void:
	if ability_log.has(ability_name):
		ability_log[ability_name] += 1
	else:
		ability_log.get_or_add(ability_name, 1)
	#ability_log[ability_name] += 1

func gain_mana(mana:Dictionary) -> void:
	for key in mana.keys():
		var value = mana[key]
		mana_gained[key] = value + mana_gained[key]

func use_mana(mana:Dictionary) -> void:
	for key in mana.keys():
		var value = mana[key]
		mana_spent[key] = value + mana_spent[key]

func track_streak(streak: int) -> void:
	if streak > max_combo:
		max_combo = streak

func track_highest_damage(damage: int) -> void:
	if damage > highest_damage_hit:
		highest_damage_hit = damage
