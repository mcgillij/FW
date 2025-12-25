extends AudioStreamPlayer

const possible_sounds: Array[Resource] = [
	preload("res://Sounds/1.ogg"),
	preload("res://Sounds/3.ogg"),
	preload("res://Sounds/4.ogg"),
	preload("res://Sounds/5.ogg"),
	preload("res://Sounds/6.ogg"),
	preload("res://Sounds/7.ogg"),
	preload("res://Sounds/sound.ogg"),
	preload("res://Sounds/sound(1).ogg"),
	preload("res://Sounds/sound(2).ogg"),
	preload("res://Sounds/sound(3).ogg"),
	preload("res://Sounds/sound(4).ogg")
]

const money_sounds: Array[Resource] = [
	preload("res://Sounds/Coin/Pickup16.ogg"),
	preload("res://Sounds/Coin/Pickup19.ogg"),
]

const positive_sounds: Array[Resource] = [
	preload("res://Sounds/Positive/PowerUp5.ogg"),
	preload("res://Sounds/Positive/PowerUp10.ogg"),
	preload("res://Sounds/Positive/Shoot32.ogg"),
]

const negative_sounds: Array[Resource] = [
	preload("res://Sounds/Negative/Boom15.ogg"),
	preload("res://Sounds/Negative/PowerUp11.ogg"),
	preload("res://Sounds/Negative/PowerUp16.ogg"),
	preload("res://Sounds/Negative/Shoot17.ogg"),
	preload("res://Sounds/Negative/Shoot28.ogg"),
]

const explosion_sounds: Array[Resource] = [
	preload("res://Sounds/explosions/explosion(1).ogg"),
	preload("res://Sounds/explosions/explosion(2).ogg"),
	preload("res://Sounds/explosions/explosion(3).ogg"),
	preload("res://Sounds/explosions/explosion(4).ogg"),
	preload("res://Sounds/explosions/explosion.ogg"),
]
const level_unlock_sound := preload("res://Sounds/level_unlock/unlock.ogg")

# battle notification sound
const battle_notification_sound = preload("res://Sounds/battle_notification.ogg")
# Achievements unlock sound
const achievement_sound = preload("res://Sounds/achievement_unlock.ogg")
# level popout sound
const level_popout_sound = preload("res://Sounds/bubble_heavy.ogg")
# skill tree sounds
const select_sound = preload("res://Sounds/select.ogg")
const deselect_sound = preload("res://Sounds/deselect.ogg")

# Dice roll sounds
const dice_roll_sounds: Array[Resource] = [
	preload("res://Sounds/dice_roll1.ogg"),
	preload("res://Sounds/dice_roll2.ogg"),
	preload("res://Sounds/dice_roll3.ogg")
]

# Card deal sound
const deal_sound = preload("res://Solitaire/Sounds/Full deal 1.wav")
const card_noises: Array[Resource] = [
	preload("res://Solitaire/Sounds/4 Card Playing FX2_7.wav"),
	preload("res://Solitaire/Sounds/4Card Playing F2-1_2.wav"),
	preload("res://Solitaire/Sounds/5 Card Playing FX2_8.wav"),
	preload("res://Solitaire/Sounds/5Card Playing F2-1_5.wav"),
	preload("res://Solitaire/Sounds/6 Card Playing FX2_5.wav"),
	preload("res://Solitaire/Sounds/6Card Playing F2-1_4.wav")
]

var reel_tick_sounds: Array[Resource] = [
	possible_sounds[0],
	possible_sounds[1],
]

var peg_hit_sounds: Array[Resource] = [
	possible_sounds[2],
	possible_sounds[3],
]

var spin_start_sound: Resource = possible_sounds[0]
var peek_sound: Resource = possible_sounds[0]

const win_sounds: Array[Resource] = [
	preload("res://Sounds/win/level-win-6416.mp3"),
	preload("res://Sounds/win/winharpsichord-39642.mp3"),
	preload("res://Sounds/win/winning-82808.mp3")
	]

func _ready() -> void:
	EventBus.play_sound_for_booster.connect(_play_random_sound)
	EventBus.achievement_trigger.connect(_play_achievement_sound)
	EventBus.skilltree_select.connect(_play_select_sound)
	EventBus.skilltree_deselect.connect(_play_deselect_sound)
	wire_up_all_buttons()
	set_global_volume()

func _play_random_win_sound() -> void:
	stream = win_sounds[randi() % win_sounds.size()]
	play()

func _play_random_dice_sound() -> void:
	stream = dice_roll_sounds[randi() % dice_roll_sounds.size()]
	play()

func _play_card_deal_sound() -> void:
	stream = deal_sound
	play()

func _play_random_card_sound() -> void:
	stream = card_noises[randi() % card_noises.size()]
	play()

func _play_random_explosion_sound(streak: int) -> void:
	stream = explosion_sounds[randi() % explosion_sounds.size()]
	if streak > 1:
		pitch_scale = 1.0 + (streak - 1) * 0.1
	else:
		pitch_scale = 1.0
	play()

func _play_level_unlock_sound() -> void:
	stream = level_unlock_sound
	play()

func _player_random_money_sound() -> void:
	stream = money_sounds[randi() % money_sounds.size()]
	play()

func _play_random_positive_sound() -> void:
	stream = positive_sounds[randi() % positive_sounds.size()]
	play()

func _play_random_negative_sound() -> void:
	stream = negative_sounds[randi() % negative_sounds.size()]
	play()

func _play_sinker_spawn_sound() -> void:
	stream = negative_sounds[4]
	play()

func wire_up_all_buttons() -> void:
	var button_list = get_tree().get_nodes_in_group("all_buttons")
	for b in button_list:
		var callable := Callable(self, "_all_button_sound")
		if not b.is_connected("pressed", callable):
			b.connect("pressed", callable)

func _all_button_sound() -> void:
	SoundManager._play_sound(5)

func _play_level_popout() -> void:
	stream = level_popout_sound
	play()

func _play_battle_notification_sound() -> void:
	stream = battle_notification_sound
	play()

func _play_random_sound(streak: int = 1) -> void:
	stream = possible_sounds[randi() % possible_sounds.size()]
	if streak > 1:
		pitch_scale = 1.0 + (streak - 1) * 0.1
	else:
		pitch_scale = 1.0
	play()

func _play_reel_tick_sound() -> void:
	if reel_tick_sounds.size() == 0:
		_play_random_sound()
		return
	stream = reel_tick_sounds[randi() % reel_tick_sounds.size()]
	play()

func _play_peg_hit_sound() -> void:
	if peg_hit_sounds.size() == 0:
		_play_random_sound()
		return
	stream = peg_hit_sounds[randi() % peg_hit_sounds.size()]
	play()

func _play_spin_start_sound() -> void:
	stream = spin_start_sound
	play()

func _play_peek_sound() -> void:
	stream = peek_sound
	play()

func _play_achievement_sound(_notused) -> void:
	stream = achievement_sound
	play()

func _play_select_sound() -> void:
	stream = select_sound
	play()

func _play_deselect_sound() -> void:
	stream = deselect_sound
	play()

func _play_sound(index: int) -> void:
	stream = possible_sounds[index]
	play()

func _on_finished() -> void:
	stream = null

func set_sound_volume() -> void:
	if ConfigManager.sound_on:
		SoundManager.volume_db = ConfigManager.sound_volume
	else:
		SoundManager.volume_db = -80

func set_music_volume() -> void:
	if ConfigManager.music_on:
		MusicManager.volume_db = ConfigManager.music_volume
	else:
		MusicManager.volume_db = -80

func set_global_volume() -> void:
	set_music_volume()
	set_sound_volume()
