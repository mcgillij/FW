extends CanvasLayer

@onready var player_turn_label: Label = $MarginContainer/Graphic_and_Buttons/Panel/MarginContainer/your_turn
@onready var player_turn_panel: Panel = $MarginContainer/Graphic_and_Buttons/Panel
@onready var enemy_turn_label: Label = $MarginContainer/Graphic_and_Buttons/Panel2/MarginContainer/enemy_turn
@onready var enemy_turn_panel: Panel = $MarginContainer/Graphic_and_Buttons/Panel2
@onready var prompt_timer: Timer = $prompt_timer
@export var prompt_timer_duration: int

func _ready() -> void:
	$prompt_timer.wait_time = prompt_timer_duration

	# Connect to the new EventBus turn signals
	EventBus.start_of_player_turn.connect(_on_player_turn)
	EventBus.start_of_monster_turn.connect(_on_monster_turn)

func player_turn() -> void:
	if !player_turn_label:
		player_turn_label = $MarginContainer/Graphic_and_Buttons/Panel/MarginContainer/your_turn
		player_turn_panel = $MarginContainer/Graphic_and_Buttons/Panel
	if !enemy_turn_label:
		enemy_turn_label = $MarginContainer/Graphic_and_Buttons/Panel2/MarginContainer/enemy_turn
		enemy_turn_panel = $MarginContainer/Graphic_and_Buttons/Panel2
	player_turn_label.visible = true
	player_turn_panel.visible = true
	enemy_turn_label.visible = false
	enemy_turn_panel.visible = false
	slide_in()
	$prompt_timer.start()

func enemy_turn() -> void:
	player_turn_label.visible = false
	player_turn_panel.visible = false
	enemy_turn_label.visible = true
	enemy_turn_panel.visible = true
	slide_in()
	$prompt_timer.start()

func slide_in() -> void:
	$AnimationPlayer.play("slide_in")

func slide_out() -> void:
	$AnimationPlayer.play_backwards("slide_in")

func _on_prompt_timer_timeout() -> void:
	slide_out()

# New handlers connected to EventBus signals
func _on_player_turn() -> void:
	player_turn()

func _on_monster_turn() -> void:
	enemy_turn()

# Legacy handlers - remove these once confirmed no longer in use
func _on_game_manager_2_enemy_turn() -> void:
	enemy_turn()

func _on_game_manager_2_player_turn() -> void:
	player_turn()
