extends AudioStreamPlayer

class_name FW_SoundTest

# Simple interactive audio sandbox that maps keys to AudioStreamInteractive clips.

enum MusicClip {
	CALM,
	EXPLORATION,
	COMBAT,
	BOSS
}

const KEY_BINDINGS := {
	KEY_1: MusicClip.CALM,
	KEY_2: MusicClip.EXPLORATION,
	KEY_3: MusicClip.COMBAT,
	KEY_4: MusicClip.BOSS
}

const CLIP_LIBRARY := {
	MusicClip.CALM: {
		"name": "calm_theme",
		"stream": preload("res://Music/theme-1.ogg"),
		"auto_advance": AudioStreamInteractive.AUTO_ADVANCE_DISABLED
	},
	MusicClip.EXPLORATION: {
		"name": "exploration_layer",
		"stream": preload("res://Music/theme-3.ogg"),
		"auto_advance": AudioStreamInteractive.AUTO_ADVANCE_DISABLED
	},
	MusicClip.COMBAT: {
		"name": "combat_loop",
		"stream": preload("res://Music/05. Last Mission.mp3"),
		"auto_advance": AudioStreamInteractive.AUTO_ADVANCE_DISABLED
	},
	MusicClip.BOSS: {
		"name": "boss_intro",
		"stream": preload("res://Music/09. Crisis.mp3"),
		"auto_advance": AudioStreamInteractive.AUTO_ADVANCE_DISABLED
	}
}

const TRANSITIONS := [
	{
		"from": AudioStreamInteractive.CLIP_ANY,
		"to": MusicClip.CALM,
		"from_time": AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
		"to_time": AudioStreamInteractive.TRANSITION_TO_TIME_START,
		"fade_mode": AudioStreamInteractive.FADE_AUTOMATIC,
		"fade_beats": 1.5
	},
	{
		"from": AudioStreamInteractive.CLIP_ANY,
		"to": MusicClip.EXPLORATION,
		"from_time": AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
		"to_time": AudioStreamInteractive.TRANSITION_TO_TIME_START,
		"fade_mode": AudioStreamInteractive.FADE_AUTOMATIC,
		"fade_beats": 2.0
	},
	{
		"from": AudioStreamInteractive.CLIP_ANY,
		"to": MusicClip.COMBAT,
		"from_time": AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT,
		"to_time": AudioStreamInteractive.TRANSITION_TO_TIME_START,
		"fade_mode": AudioStreamInteractive.FADE_CROSS,
		"fade_beats": 1.0
	},
	{
		"from": AudioStreamInteractive.CLIP_ANY,
		"to": MusicClip.BOSS,
		"from_time": AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR,
		"to_time": AudioStreamInteractive.TRANSITION_TO_TIME_START,
		"fade_mode": AudioStreamInteractive.FADE_AUTOMATIC,
		"fade_beats": 3.0
	}
]

var _interactive_stream: AudioStreamInteractive = AudioStreamInteractive.new()
var _interactive_playback: AudioStreamPlaybackInteractive

func _ready() -> void:
	_build_interactive_stream()
	stream = _interactive_stream
	play()
	_ensure_playback_ready()
	_print_usage()

func _build_interactive_stream() -> void:
	_interactive_stream.clip_count = CLIP_LIBRARY.size()
	_interactive_stream.initial_clip = MusicClip.CALM
	for clip_id in CLIP_LIBRARY.keys():
		var clip_data: Dictionary = CLIP_LIBRARY[clip_id]
		_interactive_stream.set_clip_name(clip_id, clip_data["name"])
		_interactive_stream.set_clip_stream(clip_id, clip_data["stream"])
		_interactive_stream.set_clip_auto_advance(clip_id, clip_data.get("auto_advance", AudioStreamInteractive.AUTO_ADVANCE_DISABLED))
	_configure_transitions()

func _configure_transitions() -> void:
	for transition_data in TRANSITIONS:
		_interactive_stream.add_transition(
			transition_data["from"],
			transition_data["to"],
			transition_data.get("from_time", AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR),
			transition_data.get("to_time", AudioStreamInteractive.TRANSITION_TO_TIME_START),
			transition_data.get("fade_mode", AudioStreamInteractive.FADE_AUTOMATIC),
			transition_data.get("fade_beats", 2.0)
		)

func _ensure_playback_ready() -> void:
	if _interactive_playback:
		return
	var playback := get_stream_playback()
	if playback is AudioStreamPlaybackInteractive:
		_interactive_playback = playback

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if not KEY_BINDINGS.has(event.keycode):
		return
	_ensure_playback_ready()
	if not _interactive_playback:
		return
	var clip_id: int = KEY_BINDINGS[event.keycode]
	_interactive_playback.switch_to_clip(clip_id)
	print("Switched to clip:", " ", _interactive_stream.get_clip_name(clip_id))

func _print_usage() -> void:
	print("SoundTest ready. Press 1-4 to change layers.")
