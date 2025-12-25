extends Node

class_name FW_TurnManager

# Turn states
enum TurnState {
	PLAYER_TURN,
	MONSTER_TURN,
	TURN_TRANSITION,
	GAME_ENDED
}

# Current turn state
var current_state: TurnState = TurnState.PLAYER_TURN

# Turn counters
var turn_number: int = 1
var player_turn_count: int = 0
var monster_turn_count: int = 0

# State flags
var board_stable: bool = true
var game_won: bool = false
var game_lost: bool = false

# References
var game_manager: FW_GameManager
var grid: Node

# Signals
signal turn_started(turn_state: TurnState)
signal turn_ended(turn_state: TurnState)
signal turn_transition_started(from_state: TurnState, to_state: TurnState)
signal turn_transition_completed(from_state: TurnState, to_state: TurnState)
signal board_state_changed(is_stable: bool)
signal game_ended(won: bool)

# Constants
const MONSTER_ACTION_DELAY: float = 0.7
const BOARD_STABILITY_CHECK_INTERVAL: float = 0.5
const MAX_STABILITY_CHECKS: int = 20  # 10 seconds max wait

# Internal state
var _stability_check_timer: Timer
var _stability_check_count: int = 0
var _pending_monster_action: Callable = Callable()
var _pending_action_delay: float = MONSTER_ACTION_DELAY
var _turn_transition_in_progress: bool = false

func _ready() -> void:
	_setup_timers()
	_connect_signals()

func _setup_timers() -> void:
	_stability_check_timer = Timer.new()
	_stability_check_timer.wait_time = BOARD_STABILITY_CHECK_INTERVAL
	_stability_check_timer.one_shot = false
	_stability_check_timer.timeout.connect(_on_stability_check_timeout)
	add_child(_stability_check_timer)

func _connect_signals() -> void:
	# Connect to EventBus for external turn management
	EventBus.start_of_player_turn.connect(_on_start_of_player_turn)
	EventBus.start_of_monster_turn.connect(_on_start_of_monster_turn)
	# Note: player_turn signal doesn't exist on EventBus, so we don't connect to it

func set_game_manager(manager: FW_GameManager) -> void:
	game_manager = manager

func set_grid(grid_node: Node) -> void:
	grid = grid_node

# Public API
func start_game(initial_state: TurnState = TurnState.PLAYER_TURN) -> void:
	current_state = initial_state
	turn_number = 1
	_turn_transition_in_progress = false
	player_turn_count = 1 if initial_state == TurnState.PLAYER_TURN else 0
	monster_turn_count = 1 if initial_state == TurnState.MONSTER_TURN else 0
	emit_signal("turn_started", current_state)
	if initial_state == TurnState.PLAYER_TURN:
		_emit_turn_banner(TurnState.PLAYER_TURN)
		EventBus.start_of_player_turn.emit()
	elif initial_state == TurnState.MONSTER_TURN:
		_emit_turn_banner(TurnState.MONSTER_TURN)
		EventBus.start_of_monster_turn.emit()

func end_player_turn() -> void:
	if current_state != TurnState.PLAYER_TURN or _turn_transition_in_progress:
		return

	_turn_transition_in_progress = true
	emit_signal("turn_ended", TurnState.PLAYER_TURN)
	emit_signal("turn_transition_started", TurnState.PLAYER_TURN, TurnState.MONSTER_TURN)

	# Process turn end logic directly in TurnManager
	_process_player_turn_end()

	# Start monster turn after processing
	call_deferred("_start_monster_turn")

func end_monster_turn() -> void:
	if current_state != TurnState.MONSTER_TURN or _turn_transition_in_progress:
		return

	_turn_transition_in_progress = true
	emit_signal("turn_ended", TurnState.MONSTER_TURN)
	emit_signal("turn_transition_completed", TurnState.MONSTER_TURN, TurnState.PLAYER_TURN)

	# Process turn end logic directly in TurnManager
	_process_monster_turn_end()

	# Start player turn after processing
	call_deferred("_start_player_turn")

func set_board_stable(is_stable: bool) -> void:
	if board_stable != is_stable:
		board_stable = is_stable
		emit_signal("board_state_changed", is_stable)

func is_player_turn() -> bool:
	return current_state == TurnState.PLAYER_TURN

func is_monster_turn() -> bool:
	return current_state == TurnState.MONSTER_TURN

func can_perform_action() -> bool:
	return not _turn_transition_in_progress and not game_won and not game_lost

func request_monster_action(action: Callable, delay: float = MONSTER_ACTION_DELAY) -> void:
	if not action.is_valid():
		return
	if not is_monster_turn() or _turn_transition_in_progress:
		return

	# If the board is unstable, queue the action and start stability checks.
	if not board_stable:
		_pending_monster_action = action
		_pending_action_delay = delay
		_start_stability_check()
		return

	# Otherwise, execute with the standard delay so the action mirrors tile-move timing.
	await _execute_monster_action(action, delay)

func force_end_current_turn() -> void:
	_clear_pending_action()
	if _stability_check_timer and !_stability_check_timer.is_stopped():
		_stability_check_timer.stop()
	if current_state == TurnState.PLAYER_TURN:
		end_player_turn()
	elif current_state == TurnState.MONSTER_TURN:
		end_monster_turn()

# Private methods
func _start_player_turn() -> void:
	if game_won or game_lost:
		return
	current_state = TurnState.PLAYER_TURN
	player_turn_count += 1
	turn_number += 1
	_turn_transition_in_progress = false

	_emit_turn_banner(TurnState.PLAYER_TURN)

	emit_signal("turn_started", TurnState.PLAYER_TURN)
	EventBus.start_of_player_turn.emit()

func _start_monster_turn() -> void:
	if game_won or game_lost:
		return
	current_state = TurnState.MONSTER_TURN
	monster_turn_count += 1
	_turn_transition_in_progress = false

	_emit_turn_banner(TurnState.MONSTER_TURN)

	emit_signal("turn_started", TurnState.MONSTER_TURN)
	EventBus.start_of_monster_turn.emit()

func _start_stability_check() -> void:
	_stability_check_count = 0
	if _stability_check_timer.is_stopped():
		_stability_check_timer.start()

func _execute_monster_action(action: Callable, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_monster_turn() or _turn_transition_in_progress or game_won or game_lost:
		return
	action.call()

func _emit_turn_banner(turn_state: TurnState) -> void:
	var banner_name := ""
	if turn_state == TurnState.PLAYER_TURN:
		if GDM.player and GDM.player.character:
			banner_name = GDM.player.character.name
		else:
			banner_name = "Player"
	elif turn_state == TurnState.MONSTER_TURN:
		if GDM.monster_to_fight:
			banner_name = GDM.monster_to_fight.name
		else:
			banner_name = "Enemy"
	var text := "----------- %s's turn begins -----------" % banner_name
	EventBus.publish_combat_log.emit(text)

func _on_stability_check_timeout() -> void:
	_stability_check_count += 1

	if board_stable:
		_stability_check_timer.stop()
		if _pending_monster_action.is_valid():
			# Add the same slight delay before executing the queued action so abilities
			# feel consistent with tile-move timing.
			var pending_action := _pending_monster_action
			var pending_delay := _pending_action_delay
			_clear_pending_action()
			await _execute_monster_action(pending_action, pending_delay)
		return

	if _stability_check_count >= MAX_STABILITY_CHECKS:
		_stability_check_timer.stop()
		_clear_pending_action()
		force_end_current_turn()

func _clear_pending_action() -> void:
	_pending_monster_action = Callable()
	_pending_action_delay = MONSTER_ACTION_DELAY

# Event handlers
func _on_start_of_player_turn() -> void:
	if current_state != TurnState.PLAYER_TURN:
		_start_player_turn()

func _on_start_of_monster_turn() -> void:
	if current_state != TurnState.MONSTER_TURN:
		_start_monster_turn()
	# Don't re-emit the signal if we're already in monster turn to prevent infinite loops

func _process_player_turn_end() -> void:
	"""Process player turn end logic"""
	# Process player cooldowns
	if game_manager:
		if game_manager.player_cooldown_manager:
			game_manager.player_cooldown_manager.decrement_cooldowns()

		# Resolve all buffs owned by the player at the close of their turn
		if GDM.player.buffs:
			GDM.player.buffs.process_turn()

func _process_monster_turn_end() -> void:
	"""Process monster turn end logic"""
	# Process monster cooldowns
	if game_manager:
		if game_manager.monster_cooldown_manager:
			game_manager.monster_cooldown_manager.decrement_cooldowns()

		# Resolve all buffs owned by the monster at the close of their turn
		if GDM.monster_to_fight and GDM.monster_to_fight.buffs:
			GDM.monster_to_fight.buffs.process_turn()

# Game end handling
func set_game_won(won: bool) -> void:
	game_won = won
	game_lost = not won
	current_state = TurnState.GAME_ENDED
	emit_signal("game_ended", won)

func set_game_lost() -> void:
	game_lost = true
	game_won = false
	current_state = TurnState.GAME_ENDED
	emit_signal("game_ended", false)

# Debug methods
func get_debug_info() -> Dictionary:
	return {
		"current_state": current_state,
		"turn_number": turn_number,
		"player_turn_count": player_turn_count,
		"monster_turn_count": monster_turn_count,
		"board_stable": board_stable,
		"game_won": game_won,
		"game_lost": game_lost,
		"transition_in_progress": _turn_transition_in_progress,
		"can_perform_action": can_perform_action()
	}
