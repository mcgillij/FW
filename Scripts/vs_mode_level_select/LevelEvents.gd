extends RefCounted

class_name FW_LevelEvents

static func generate_random_event(_rng: RandomNumberGenerator) -> FW_EventResource:
	"""Generate a random event"""
	var event_resources = [
		"res://Events/Resources/heavy_boulder.tres",
		"res://Events/Resources/alertness_event.tres",
		"res://Events/Resources/bark_event.tres",
		"res://Events/Resources/enthusiasm_event.tres",
		"res://Events/Resources/reflex_event.tres",
		"res://Events/Resources/city_ruins.tres",
		"res://Events/Resources/crow.tres",
		"res://Events/Resources/crumbling_city.tres",
		"res://Events/Resources/frozen_lake.tres",
		"res://Events/Resources/frozen_stream.tres",
		"res://Events/Resources/munchkin.tres",
		"res://Events/Resources/river.tres",
		"res://Events/Resources/ruins.tres",
		"res://Events/Resources/waterfall.tres",
		"res://Events/Resources/foraging_event.tres",
		"res://Events/Resources/treasure.tres",
		"res://Events/Resources/squirrel_stash_event.tres",
		"res://Events/Resources/muddy_bog_event.tres",
		"res://Events/Resources/kind_campfire_event.tres",
		"res://Events/Resources/thunderstorm_shelter_event.tres",
		"res://Events/Resources/lost_collar_tag_event.tres",
		"res://Events/Resources/beehive_temptation_event.tres",
		"res://Events/Resources/old_rope_bridge_event.tres",
		"res://Events/Resources/mysterious_howl_event.tres",
		"res://Events/Resources/abandoned_backpack_event.tres",
		"res://Events/Resources/ancient_treat_shrine_event.tres",
	]

	var random_index = _rng.randi() % event_resources.size()
	return load(event_resources[random_index])
