# addons/fw/Platform/Steam/FW_SteamService.gd

*Class*: `FW_SteamService`

### Functions

<a name="fn-configure"></a>
#### `configure(config: FW_ConfigService)`

- **Signature return**: `void`

<a name="fn-is_platform_supported"></a>
#### `is_platform_supported()`

- **Signature return**: `bool`

<a name="fn-has_steam_singleton"></a>
#### `has_steam_singleton()`

- **Signature return**: `bool`

<a name="fn-initialize"></a>
#### `initialize()`

- **Signature return**: `bool`

<a name="fn-shutdown"></a>
#### `shutdown()`

- **Signature return**: `void`

<a name="fn-_process"></a>
#### `_process(_delta: float)`

- **Signature return**: `void`

<a name="fn-get_steam_id"></a>
#### `get_steam_id()`

- **Signature return**: `int`

<a name="fn-set_rich_presence"></a>
#### `set_rich_presence(key: String, value: String)`

- **Signature return**: `void`

<a name="fn-set_presence_display"></a>
#### `set_presence_display(token: String)`

- **Signature return**: `void`

<a name="fn-set_presence_player"></a>
#### `set_presence_player(player: String)`

- **Signature return**: `void`

<a name="fn-set_achievement"></a>
#### `set_achievement(achievement_id: String)`

- **Signature return**: `bool`

<a name="fn-store_stats"></a>
#### `store_stats()`

- **Signature return**: `bool`

<a name="fn-get_stat_int"></a>
#### `get_stat_int(stat_name: String, fallback: int = 0)`

- **Signature return**: `int`

<a name="fn-set_stat_int"></a>
#### `set_stat_int(stat_name: String, value: int)`

- **Signature return**: `bool`

<a name="fn-increment_stat_int"></a>
#### `increment_stat_int(stat_name: String, delta: int = 1)`

- **Signature return**: `bool`

<a name="fn-request_player_avatar"></a>
#### `request_player_avatar(avatar_type: int, steam_id: int)`

- **Signature return**: `void`

<a name="fn-request_local_avatar"></a>
#### `request_local_avatar(avatar_type: int)`

- **Signature return**: `void`

<a name="fn-_on_avatar_loaded"></a>
#### `_on_avatar_loaded(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray)`

- **Signature return**: `void`

