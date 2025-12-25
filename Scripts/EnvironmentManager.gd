extends Node
class_name FW_EnvironmentManager
var environments: Array = []

# Initialize the environment list with a variety of environment names
func _init():
	environments = [
		"res://EnvironmentalEffects/Resources/CrystalCaves.tres",
		"res://EnvironmentalEffects/Resources/Darkness.tres",
		"res://EnvironmentalEffects/Resources/Desert.tres",
		"res://EnvironmentalEffects/Resources/Fire.tres",
		"res://EnvironmentalEffects/Resources/FrozenTundra.tres",
		"res://EnvironmentalEffects/Resources/Graveyard.tres",
		"res://EnvironmentalEffects/Resources/Grease.tres",
		"res://EnvironmentalEffects/Resources/Ice.tres",
		"res://EnvironmentalEffects/Resources/Jungle.tres",
		"res://EnvironmentalEffects/Resources/LightningField.tres",
		"res://EnvironmentalEffects/Resources/MagmaChamber.tres",
		"res://EnvironmentalEffects/Resources/Mountain.tres",
		"res://EnvironmentalEffects/Resources/MysticForest.tres",
		"res://EnvironmentalEffects/Resources/Ocean.tres",
		"res://EnvironmentalEffects/Resources/PoisonBog.tres",
		"res://EnvironmentalEffects/Resources/Ruins.tres",
		"res://EnvironmentalEffects/Resources/Storm.tres",
		"res://EnvironmentalEffects/Resources/Swamp.tres",
		"res://EnvironmentalEffects/Resources/Underground.tres",
		"res://EnvironmentalEffects/Resources/Volcano.tres"
	]

# Returns a random environment from the list
func get_random_environment() -> FW_EnvironmentalEffect:
	return load(environments[randi() % environments.size()])

func get_environmental_effects() -> Dictionary:
	var effects := {}
	if GDM.current_info and GDM.current_info.environmental_effects:
		for e in GDM.current_info.environmental_effects:
			if e is FW_EnvironmentalEffect:
				effects = FW_Utils.merge_dict(effects, e.effects)
			else:
				printerr("Warning: FW_EnvironmentalEffect expected, got ", typeof(e), " (", e, ")")
	return effects

func get_random_environments(count: int) -> Array[FW_EnvironmentalEffect]:
	var shuffled := environments
	shuffled.shuffle()
	var results: Array[FW_EnvironmentalEffect] = []
	for i in min(count, shuffled.size()):
		var res = load(shuffled[i])
		results.append(res)
	return results
