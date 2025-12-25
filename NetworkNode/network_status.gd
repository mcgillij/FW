extends Control

@onready var network_status_image: TextureRect = %network_status_image

@export var network_up_image: Texture2D
@export var network_down_image: Texture2D

func _ready() -> void:
	# Use NetworkUtils to check network status
	# Subscribe to automatic network-disabled events
	var _net := get_node("/root/NetworkUtils")
	_net.on_network_disabled = Callable(self, "_on_network_disabled")
	# Kick off an initial server check
	_net.is_server_up(self, Callable(self, "_on_network_status_checked"))

func _exit_tree() -> void:
	# Clear subscription so dangling callables don't persist across scenes
	var _net := get_node("/root/NetworkUtils")
	if _net.on_network_disabled.is_valid():
		_net.on_network_disabled = Callable()

func _on_network_status_checked(is_up: bool) -> void:
	if is_up:
		network_status_image.texture = network_up_image
	else:
		network_status_image.texture = network_down_image

func _on_network_disabled() -> void:
	# Called when NetworkUtils auto-disables networking due to failures
	network_status_image.texture = network_down_image
