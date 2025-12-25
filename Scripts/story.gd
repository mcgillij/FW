extends "res://Scripts/base_menu_panel.gd"

signal trigger_credits

var story_images: Array[String] = [ "",
	"res://StoryImages/story1.png", #1
	"res://StoryImages/story2.png", #2
	"res://StoryImages/story3.png",
	"res://StoryImages/story4.png",
	"res://StoryImages/story5.png", #5
	"res://StoryImages/story6.png",
	"res://StoryImages/story7.png", #7
	"res://StoryImages/story8.png",
	"res://StoryImages/story9.png",
	"res://StoryImages/story10.png", #10
	"res://StoryImages/story11.png",
	"res://StoryImages/story12.png",
	"res://StoryImages/story13.png", #13
	"res://StoryImages/story14.png",
	"res://StoryImages/story15.png", # 15
	"res://StoryImages/story16.png",
	"res://StoryImages/story17.png", # 17
	"res://StoryImages/story18.png",
	"res://StoryImages/story19.png", #19
	"res://StoryImages/story20.png",
	"res://StoryImages/story21.png", #21
	"res://StoryImages/story22.png",
	"res://StoryImages/story23.png", # 23
	"res://StoryImages/story24.png",
	"res://StoryImages/story25.png", # 25
	"res://StoryImages/story26.png",
	"res://StoryImages/story27.png", # 27
	"res://StoryImages/story28.png",
	"res://StoryImages/story29.png",
	"res://StoryImages/story30.png", # 30
	"res://StoryImages/story31.png",
	"res://StoryImages/story32.png",
	"res://StoryImages/story33.png",
	"res://StoryImages/story34.png",
	"res://StoryImages/story35.png", # 35
	"res://StoryImages/story36.png",
	"res://StoryImages/story37.png",
	"res://StoryImages/story38.png",
	"res://StoryImages/story39.png",
	"res://StoryImages/story40.png", # 40
	"res://StoryImages/story41.png",
	"res://StoryImages/story42.png",
	"res://StoryImages/story43.png", #43
	"res://StoryImages/story44.png",
	"res://StoryImages/story45.png", # 45
	"res://StoryImages/story46.png",
	"res://StoryImages/story47.png",
	"res://StoryImages/story48.png"
]
var story_text: Array[String] = [ "",
	"Atiya stretched and yawned, but something felt different. The familiar scent of bacon wasn't wafting through the house. Where was the Treat Giver?",
	"Match 4 or more tiles to create column or row bone-anza!", #2
	"Leaving behind the familiar scents of home, Atiya embarked on her quest. Rolling around in some flowers first.", #3
	"Maybe another roll for good measure!",
	"The Treat Giver's absence gnawed at her. Where had he vanished?", # 5
	"A discarded tennis ball lay forgotten on the path. A playful nudge couldn't hurt, could it?",
	"Unleash the power of 5 for a super bone!", # 7
	"She squeezed under a fallen log, hoping for a moment's respite.",
	"A treasure chest! What could be in there?",
	"Atiya found a weathered armor set(harness), to protect her on her walk!", #10
	"Approaching a brook, the trail was growing fainter, would she have to cross?",
	"Cautiously, she tested the water with a paw. This might require a different approach.",
	"Unleash a dazzling combo of colorful tiles!", # 13
	"There were unspeakable monstrocities in these woods.",
	"The path ahead narrowed, turning into a dark tunnel that sent a shiver down her spine.", # 15
	"The weather was changing, how long had Atiya been adventuring?",
	"The forest floor whispered secrets of danger with each rustle of leaves.", # 17
	"Oh, I guess she's rolling in the snow now, this was an important part of her questing strategy.",
	"Hungry eyes watched Atiya from the shadows. Fear, a new scent, clung to her fur.", # 19
	"Atiya rested for a bit, the weather was letting up just a bit, or so it seemed.",
	"The wind howled through the gnarled branches, a chilling symphony.", # 21
	"Rain, again, was it ever going to let up?",
	"Undeterred, Atiya pressed on, her nose twitching with determination. The Treat Giver's scent was faint.", # 23
	"Atiya was at the threshold between the wilderness and the city.",
	"Towering office buildings on the horizon clawed at the sky, blocking out the sun.", # 25
	"Atiya pondered, what drove people to build these decrepit monoliths.",
	"Tangled chains, like grasping claws, reached out to impede her progress.", # 27
	"She tried to regain her strength for a brief minute in the ruins of a park.",
	"Atiya's tiny frame became her advantage, slipping through treacherous gaps.", # 29
	"These landscapes were getting stranger, was she losing the trail?", # 30
	"With a determined bark, she pressed forward.",
	"How could anyone navigate these maze-like streets, was Atiya losing the trail?",
	"The scent of treats was absent, replaced by a strange, metallic tang.", # 33
	"A colossal building loomed before her, its windows reflecting the setting sun. Was this... the Treat Giver's domain?",
	"A towering wall of cubicles rose before her shrouded in fluorescent lights, Each identical desk held vacant, emotionless beings.", # 35
	"She followed the faintest of trails, but what were all these shells of people doing here?",
	"An unsettling feeling crept over her. This wasn't what she expected.",
	"Atiya decided that this place was too weird, and hid in a filing cabinet for a while, but then she caught a familiar scent!",
	"The end of the labyrinthine corridors seemed to shimmer in the distance, or was it another row of identical desks?", # 39
	"Resting for a moment under a desk, Atiya planned her next steps carefully.", # 40
	"The air hung heavy with the stench of stale coffee and despair. Slime, a sickly green ooze of paperwork and unyielding bureaucracy, was seeping in.", # 41
	"Hiding between some shelves for a moment, Atiya tries to find the trail once more.",
	"She was nearing the epicenter, the source of the oppressive atmosphere. The low, monotonous hum – the relentless drone of productivity, it was everywhere!", # 43
	"Dashing across a pipe between buildings, Atiya has found the trail once again.",
	"A muffled squeak, punctuated by a frustrated sigh, echoed from behind a frosted glass door. Could this be...?", # 45
	"She followed the scent, to a nearby office, navigating this horific wasteland, what were all these prisoners doing here?",
	"A boss was approaching! Atiya steeled herself, ready to face the final challenge.", # 47
	"Atiya found the Treat Giver slumped over his desk, buried under a mountain of work tickets. A flicker of recognition sparked in his glazed eyes as he saw her.  A weary smile crept across his face, and he reached out to her, offering a treat. Atiya's tail wagged furiously. They made a break for it, escaping the office."
]

@onready var story_label: Label = %story_label
@onready var story_continue_button: TextureButton = %story_continue_button
@onready var story_image: TextureRect = %story_image

var is_out = false
var final_level: int = 48
var current_level: int = 0

func _on_you_win_trigger_story(level: int) -> void:
	current_level = level
	Achievements.increment_achievement_progress_by_type("puzzle")
	GDM.safe_steam_increment_stat("puzzles_solved")

	# unlock boomer after the last bonus levels
	if level == 1:
		Achievements.unlock_achievement("welcome", true)
		UnlockManager.set_progress("welcome", true)
		GDM.safe_steam_set_achievement("Welcome")
		GDM.safe_steam_set_achievement("Achievements!")
	if level == 10:
		UnlockManager.set_progress("puzzle_act1", true)
		UnlockManager.set_just_unlocked_act("act1")
		Achievements.unlock_achievement("act1")
		GDM.safe_steam_set_achievement("Act1")
	if level == 20:
		UnlockManager.set_progress("puzzle_act2", true)
		UnlockManager.set_just_unlocked_act("act2")
		Achievements.unlock_achievement("act2")
		GDM.safe_steam_set_achievement("Act2")
	if level == 24:
		UnlockManager.set_progress("puzzle_act3", true)
		UnlockManager.set_just_unlocked_act("act3")
		Achievements.unlock_achievement("act3")
		GDM.safe_steam_set_achievement("Act3")
	if level == 30:
		UnlockManager.set_progress("puzzle_act4", true)
		UnlockManager.set_just_unlocked_act("act4")
		Achievements.unlock_achievement("act4")
		GDM.safe_steam_set_achievement("Act4")
	if level == 36:
		UnlockManager.set_progress("puzzle_act5", true)
		UnlockManager.set_just_unlocked_act("act5")
		Achievements.unlock_achievement("act5")
		GDM.safe_steam_set_achievement("Act5")
	if level == 42:
		UnlockManager.set_progress("puzzle_act6", true)
		UnlockManager.set_just_unlocked_act("act6")
		Achievements.unlock_achievement("act6")
		GDM.safe_steam_set_achievement("Act6")
	if level == 48:
		UnlockManager.set_progress("puzzle_bonus", true)
		UnlockManager.set_just_unlocked_act("bonus")
		Achievements.unlock_achievement("bonus")
		GDM.safe_steam_set_achievement("Bonus")

	if level == final_level:
		Achievements.unlock_achievement("rosie")
		GDM.safe_steam_set_achievement("Rosie")
		story_continue_button.visible = false
		$Timer.start()

	story_image.texture = load(story_images[level])
	story_label.text = story_text[level]
	if is_out == false:
		is_out = true
		slide_in()

func _on_timer_timeout() -> void:
	emit_signal("trigger_credits")

func _on_story_continue_button_pressed() -> void:
	ScreenRotator.change_scene("res://Scenes/level_select.tscn")
