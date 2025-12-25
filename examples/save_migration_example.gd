extends Node

# Example: How to implement a migration in FW_SaveService
# Suppose you add a new key in schema v1 called 'player_name'.

func migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	# data is the canonical v0 dict shape
	var new = data.duplicate(true)
	if not new["data"].has("player_name"):
		new["data"]["player_name"] = "Player"
	return new

# Hook this into FW_SaveService by adding a method named `_migrate_0_to_1` and
# ensuring `_migrate_to_current()` calls it when previous schema == 0.
# The SaveService already uses the `_migrate_minus1_to_0` naming convention for the -1 -> 0 step.
