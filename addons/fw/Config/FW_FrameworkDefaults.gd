extends RefCounted
class_name FW_FrameworkDefaults

static func apply(config: FW_ConfigService) -> void:
	config.register_defaults({
		"audio": {
			"sfx_enabled": true,
			"music_enabled": true,
			"sfx_volume_db": 0.0,
			"music_volume_db": 0.0,
		},
		"display": {
			"window_size": Vector2(720, 1280),
			"window_position": Vector2(0, 0),
		},
		"net": {
			"enabled": true,
			"base_url": "",
			"api_key": "",
			"auto_disable_on_fail": false,
			"healthcheck_path": "/",
			"healthcheck_cache_seconds": 2.0,
		},
		"resources": {
			"cache_enabled": true,
			"cache_max_entries": 256,
			"preload_enabled": true,
			"preload_items_per_frame": 1,
		},
	})
