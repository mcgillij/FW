## Simple registry mapping glossary list item text -> PackedScene path
## Edit this file to add new mappings for help entries.

const ENTRIES := {
	"Basics": {
		"scene": "res://Help/Subjects/Basics.tscn",
	},
	"Bombs": {
		"scene": "res://Help/Subjects/Bombs.tscn",
	},
	"T or L Bombs": {
		"scene": "res://Help/Subjects/TLBombs.tscn",
	},
	"Rainbow Bombs": {
		"scene": "res://Help/Subjects/Rainbow.tscn",
	},
	"Combos": {
		"scene": "res://Help/Subjects/Combos.tscn",
	},
	"Chains": {
		"scene": "res://Help/Subjects/Chains.tscn",
	},
	"Bomb Combos": {
		"scene": "res://Help/Subjects/BombCombos.tscn",
	},
	"Sinkers": {
		"scene": "res://Help/Subjects/Sinkers.tscn",
	},
	"Character Affinities": {
		"scene": "res://Help/Subjects/CharacterAffinities.tscn",
	},
	"Affinities": {
		"scene": "res://Help/Subjects/Affinities.tscn",
	},
	"Stats and Skills": {
		"scene": "res://Help/Subjects/StatsAndSkills.tscn",
	},
	"Abilities": {
		"scene": "res://Help/Subjects/Abilities.tscn",
	},
	"Equipment": {
		"scene": "res://Help/Subjects/FW_Equipment.tscn",
	},
	"Consumables": {
		"scene": "res://Help/Subjects/Consumables.tscn",
	},
	"Jobs": {
		"scene": "res://Help/Subjects/Jobs.tscn",
	},
	"Ascension": {
		"scene": "res://Help/Subjects/Ascension.tscn",
	},
	"Achievements/Unlocks": {
		"scene": "res://Help/Subjects/Achievements.tscn",
	}
}

static func get_entry(name: String) -> Dictionary:
	if ENTRIES.has(name):
		return ENTRIES[name]
	return {}
