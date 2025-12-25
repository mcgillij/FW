extends Node
class_name FW_AudioService

const MUTED_DB := -80.0

@export var sfx_bus: StringName = &"SFX"
@export var music_bus: StringName = &"Music"
@export var sfx_pool_size: int = 8

var _config: FW_ConfigService

var _sfx_by_id: Dictionary = {}
var _music_by_id: Dictionary = {}

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer

var _players_ready: bool = false

func configure(config: FW_ConfigService) -> void:
	_config = config
	if _config != null and not _config.changed.is_connected(_on_config_changed):
		_config.changed.connect(_on_config_changed)
	_apply_audio_config()

func _ready() -> void:
	_ensure_players()
	_apply_audio_config()

func _ensure_players() -> void:
	if _players_ready:
		return

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = music_bus
	add_child(_music_player)

	_sfx_players.clear()
	for i in range(max(1, sfx_pool_size)):
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		_sfx_players.append(p)

	_players_ready = true

func register_sfx(id: StringName, stream: AudioStream) -> void:
	_sfx_by_id[id] = stream

func register_music(id: StringName, stream: AudioStream) -> void:
	_music_by_id[id] = stream

func play_sfx(id: StringName, volume_db_offset: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _sfx_by_id.has(id):
		return
	if not _players_ready:
		if is_inside_tree():
			_ensure_players()
		else:
			return
	var p := _next_sfx_player()
	p.stop()
	p.stream = _sfx_by_id[id]
	p.pitch_scale = pitch_scale
	p.volume_db = _get_sfx_volume_db() + volume_db_offset
	p.play()

func play_music(id: StringName, volume_db_offset: float = 0.0) -> void:
	if not _music_by_id.has(id):
		return
	if not _players_ready:
		if is_inside_tree():
			_ensure_players()
		else:
			return
	_music_player.stop()
	_music_player.stream = _music_by_id[id]
	_music_player.volume_db = _get_music_volume_db() + volume_db_offset
	_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()

func bind_button_group(group_name: StringName = &"all_buttons", sound_id: StringName = &"ui.click") -> void:
	for n in get_tree().get_nodes_in_group(group_name):
		if n is BaseButton:
			var b: BaseButton = n
			var c := Callable(self, "_on_bound_button_pressed").bind(sound_id)
			if not b.pressed.is_connected(c):
				b.pressed.connect(c)

func _on_bound_button_pressed(sound_id: StringName) -> void:
	play_sfx(sound_id)

func _next_sfx_player() -> AudioStreamPlayer:
	if not _players_ready:
		_ensure_players()
	for p in _sfx_players:
		if not p.playing:
			return p
	if _sfx_players.is_empty():
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		_sfx_players.append(p)
	return _sfx_players[0]

func _apply_audio_config() -> void:
	if _config == null:
		return
	if not _players_ready:
		return
	for p in _sfx_players:
		p.volume_db = _get_sfx_volume_db()
	_music_player.volume_db = _get_music_volume_db()

func _get_sfx_volume_db() -> float:
	if _config == null:
		return 0.0
	var enabled := _config.get_bool(&"audio", &"sfx_enabled", true)
	if not enabled:
		return MUTED_DB
	return _config.get_float(&"audio", &"sfx_volume_db", 0.0)

func _get_music_volume_db() -> float:
	if _config == null:
		return 0.0
	var enabled := _config.get_bool(&"audio", &"music_enabled", true)
	if not enabled:
		return MUTED_DB
	return _config.get_float(&"audio", &"music_volume_db", 0.0)

func _on_config_changed(section: StringName, _key: StringName, _value: Variant) -> void:
	if section != &"audio":
		return
	_apply_audio_config()
