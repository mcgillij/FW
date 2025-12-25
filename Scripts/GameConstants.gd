extends RefCounted
class_name FW_GameConstants

# Damage constants
const DEFAULT_DOT_AMOUNT: int = 5
const BOMB_DAMAGE: int = 25

# Mana constants
const MONSTER_MAX_MANA := {"red": 100, "blue": 100, "green": 100, "orange": 100, "pink": 100}

# Dice rolling constants
const DICE_ROLL_DELAY: float = 2.0

# Timer constants
const XP_GAIN_DELAY: float = 0.7

# Ascension Levels
const ascension_levels := [
	"0. No changes - This is the default difficulty",
	"1. Monsters are smarter, more levels per world", # AI bumped up to no longer use RandomAI for all moves
	"2. All monsters now have an Ability, even more levels",
	"3. Monsters now have job / stats based on the abilities, more levels!",
	"4+ Monsters grow stronger, moar levels!"
	]
