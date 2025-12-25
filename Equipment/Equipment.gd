extends FW_Item

class_name FW_Equipment

enum equipment_types { HAT, TAIL, COLLAR, HARNESS, BRACERS, WEAPON }
enum equipment_rarity { TERRIBLE, BAD, OK, COMMON, GOOD, GREAT, UNCOMMON, RARE, SPECIAL, EXTRAORDINARY, EPIC, LEGENDARY, MYTHIC, ARTIFACT, UNIQUE }

@export var type: equipment_types
@export var effects: Dictionary

@export var rarity: equipment_rarity
@export var gold_value: int

func apply_stats() -> void:
	GDM.player.stats.apply_equipment_bonus(effects)

# Function to apply the buff effect per turn, if needed
func apply_per_turn_effects() -> void:
	pass

func get_rarity_color(item_rarity: FW_Equipment.equipment_rarity) -> Color:
	match item_rarity:
		FW_Equipment.equipment_rarity.TERRIBLE:
			return Color.hex(0x44475a) # Muted gray (lowest rarity)
		FW_Equipment.equipment_rarity.BAD:
			return Color.hex(0x6272a4) # Muted blue
		FW_Equipment.equipment_rarity.OK:
			return Color.hex(0x6d6a7c) # Soft purple
		FW_Equipment.equipment_rarity.COMMON:
			return Color.hex(0x8be9fd) # Bright cyan
		FW_Equipment.equipment_rarity.UNCOMMON:
			return Color.hex(0x50fa7b) # Bright green
		FW_Equipment.equipment_rarity.GOOD:
			return Color.hex(0xf1fa8c) # Vibrant yellow
		FW_Equipment.equipment_rarity.GREAT:
			return Color.hex(0xffb86c) # Orange
		FW_Equipment.equipment_rarity.RARE:
			return Color.hex(0xbd93f9) # Vivid purple
		FW_Equipment.equipment_rarity.EXTRAORDINARY:
			return Color.hex(0xff79c6) # Hot pink
		FW_Equipment.equipment_rarity.EPIC:
			return Color.hex(0xff5555) # Bright red
		FW_Equipment.equipment_rarity.LEGENDARY:
			return Color.hex(0x00bfff) # Electric blue
		FW_Equipment.equipment_rarity.MYTHIC:
			return Color.hex(0xcaa9fa) # Neon purple
		FW_Equipment.equipment_rarity.ARTIFACT:
			return Color.hex(0x5af78e) # Neon green
		FW_Equipment.equipment_rarity.SPECIAL:
			return Color.hex(0xe2e2fa) # Pale lavender
		FW_Equipment.equipment_rarity.UNIQUE:
			return Color.hex(0xffffff) # Pure white
		_:
			return Color.hex(0x44475a) # Default to neutral gray

func _to_string() -> String:
	return "Equipment: " + str(name) + str(type) + " " + str(FW_Equipment.equipment_rarity.keys()[rarity]) + " " + str(gold_value) + " " + str(effects)
