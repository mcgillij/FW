extends Resource

class_name FW_SkillCheckRes

enum DIFF { SIMPLE, EASY, MEDIUM, HARD, EXTREME }

@export var skill_name: String
@export var color: Color
@export var target: int
@export var difficulty: DIFF

func _init(skill_name_p: String = "", color_p: Color = Color.WHITE, target_p: int = 0, difficulty_p: FW_SkillCheckRes.DIFF = DIFF.SIMPLE) -> void:
	skill_name = skill_name_p
	color = color_p
	target = target_p
	difficulty = difficulty_p

func get_xp_value() -> int:
	match difficulty:
		DIFF.SIMPLE:
			return 30
		DIFF.EASY:
			return 40
		DIFF.MEDIUM:
			return 50
		DIFF.HARD:
			return 60
		DIFF.EXTREME:
			return 80
	printerr("We shouldn't get here, but here we are. Returning 0 for xp")
	return 0

func _to_string() -> String:
	return "SkillCheckRes: " + skill_name + ", Value: " + str(target) + ", Color: " + str(color)
