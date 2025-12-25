extends RefCounted

class_name FW_EquipmentFactory

var config: FW_EquipmentConfig
var rarity_manager: FW_EquipmentRarityManager
var affix_manager: FW_EquipmentAffixManager
var name_generator: FW_EquipmentNameGenerator

func _init():
	config = FW_EquipmentConfig.new()
	rarity_manager = FW_EquipmentRarityManager.new(config)
	affix_manager = FW_EquipmentAffixManager.new()
	name_generator = FW_EquipmentNameGenerator.new()

# Main equipment generation methods
func create_equipment(desired_rarity = null, equipment_type = null) -> FW_Equipment:
	if not affix_manager.are_affixes_loaded():
		push_error("Cannot generate equipment: affixes not loaded")
		return null

	var equipment = FW_Equipment.new()

	# Set equipment type
	if equipment_type != null:
		equipment.type = equipment_type
	else:
		equipment.type = randi() % FW_Equipment.equipment_types.size()

	_set_base_properties(equipment)
	_apply_affixes_and_rarity(equipment, desired_rarity)
	_finalize_equipment(equipment)

	return equipment

func create_equipment_of_type(type: FW_Equipment.equipment_types, desired_rarity = null) -> FW_Equipment:
	return create_equipment(desired_rarity, type)

func create_random_equipment() -> FW_Equipment:
	return create_equipment()

func create_equipment_with_luck(luck: float) -> FW_Equipment:
	var weights = rarity_manager.get_rarity_weights(luck)
	var chosen_rarity = rarity_manager.weighted_random_rarity(weights)
	return create_equipment(chosen_rarity)

# Private helper methods
func _set_base_properties(equipment: FW_Equipment) -> void:
	var type_data = config.get_equipment_type_data(equipment.type)
	if type_data.is_empty():
		push_error("No data found for equipment type: " + str(equipment.type))
		return

	if type_data.names.is_empty():
		push_error("Equipment name list is empty for type: " + str(equipment.type))
		return

	equipment.texture = type_data.texture
	equipment.name = type_data.names[randi() % type_data.names.size()]

func _apply_affixes_and_rarity(equipment: FW_Equipment, desired_rarity = null) -> void:
	var target_score = -1
	if desired_rarity != null:
		target_score = rarity_manager.get_target_score_for_rarity(desired_rarity)

	var max_attempts = 100
	var score_tolerance = 20

	for attempt in max_attempts:
		var prefix = affix_manager.get_random_prefix()
		var suffix = affix_manager.get_random_suffix()

		var prefix_effects = affix_manager.roll_effects(prefix.effect)
		var suffix_effects = affix_manager.roll_effects(suffix.effect)

		var combined_effects = FW_Utils.merge_dict(prefix_effects, suffix_effects)
		var current_score = config.calculate_effect_score(combined_effects)

		# Check if this combination meets our requirements
		if desired_rarity != null:
			if abs(current_score - target_score) <= score_tolerance:
				_apply_affix_results(equipment, prefix, suffix, combined_effects, desired_rarity)
				return
		else:
			# No specific rarity requested, use any valid combination
			var determined_rarity = rarity_manager.get_rarity_from_score(current_score)
			_apply_affix_results(equipment, prefix, suffix, combined_effects, determined_rarity)
			return

	# Fallback if we couldn't meet requirements
	var fallback_prefix = affix_manager.get_random_prefix()
	var fallback_suffix = affix_manager.get_random_suffix()
	var fallback_effects = FW_Utils.merge_dict(
		affix_manager.roll_effects(fallback_prefix.effect),
		affix_manager.roll_effects(fallback_suffix.effect)
	)
	var fallback_score = config.calculate_effect_score(fallback_effects)
	var fallback_rarity = desired_rarity if desired_rarity != null else rarity_manager.get_rarity_from_score(fallback_score)

	_apply_affix_results(equipment, fallback_prefix, fallback_suffix, fallback_effects, fallback_rarity)

func _apply_affix_results(equipment: FW_Equipment, prefix: Dictionary, suffix: Dictionary, effects: Dictionary, rarity: FW_Equipment.equipment_rarity) -> void:
	equipment.rarity = rarity
	equipment.effects = affix_manager.convert_int_stats(effects)
	equipment.name = name_generator.generate_name(prefix.name, equipment.name, suffix.name)
	name_generator.set_effect_context(prefix.effect, suffix.effect)
	equipment.flavor_text = name_generator.generate_flavor_text(prefix.name, suffix.name)

func _finalize_equipment(equipment: FW_Equipment) -> void:
	equipment.gold_value = rarity_manager.calculate_gold_value(equipment.rarity)
	equipment.item_type = FW_Item.ITEM_TYPE.EQUIPMENT
