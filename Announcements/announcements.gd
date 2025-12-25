extends "res://Scripts/base_menu_panel.gd"

signal back_button
@onready var announcement_text: RichTextLabel = %announcement_text

var _has_loaded: bool = false
var _is_loading: bool = false


func _ready() -> void:
	connect("slide_in_started", Callable(self, "_on_slide_in_started"))
	announcement_text.text = "[center]Tap the announcements button to load the latest updates.[/center]"


func _on_back_button_pressed() -> void:
	emit_signal("back_button")


func _on_slide_in_started() -> void:
	_load_announcements_if_needed()


func _load_announcements_if_needed() -> void:
	if _has_loaded or _is_loading:
		return

	if not NetworkUtils.should_use_network():
		announcement_text.text = "[center]Offline mode: announcements unavailable.[/center]"
		return

	_is_loading = true
	announcement_text.text = "[center]Loading announcements...[/center]"
	NetworkUtils.is_server_up(self, Callable(self, "_on_server_status_checked"))


func _on_server_status_checked(is_up: bool) -> void:
	if not is_up:
		_is_loading = false
		announcement_text.text = "[center]Unable to reach the server right now.[/center]"
		return

	var url := NetworkUtils.server_url + "/announcements"
	NetworkUtils.perform_get(self, url, Callable(self, "_on_announcements_received"))


func _on_announcements_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_loading = false
	if result != OK or response_code != 200:
		announcement_text.text = "[center]Failed to load announcements. Please try again later.[/center]"
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		announcement_text.text = "[center]Announcements unavailable.[/center]"
		return

	if json.data is Dictionary and json.data.has("content"):
		announcement_text.text = str(json.data["content"])
		_has_loaded = true
	else:
		announcement_text.text = "[center]No announcements to show right now.[/center]"
