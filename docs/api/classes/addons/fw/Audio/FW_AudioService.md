# addons/fw/Audio/FW_AudioService.gd

*Class*: `FW_AudioService`

### Functions

<a name="fn-configure"></a>
#### `configure(config: FW_ConfigService)`

- **Signature return**: `void`

<a name="fn-_ready"></a>
#### `_ready()`

- **Signature return**: `void`

<a name="fn-_ensure_players"></a>
#### `_ensure_players()`

- **Signature return**: `void`

<a name="fn-register_sfx"></a>
#### `register_sfx(id: StringName, stream: AudioStream)`

- **Signature return**: `void`

<a name="fn-register_music"></a>
#### `register_music(id: StringName, stream: AudioStream)`

- **Signature return**: `void`

<a name="fn-play_sfx"></a>
#### `play_sfx(id: StringName, volume_db_offset: float = 0.0, pitch_scale: float = 1.0)`

- **Signature return**: `void`

<a name="fn-play_music"></a>
#### `play_music(id: StringName, volume_db_offset: float = 0.0)`

- **Signature return**: `void`

<a name="fn-stop_music"></a>
#### `stop_music()`

- **Signature return**: `void`

<a name="fn-bind_button_group"></a>
#### `bind_button_group(group_name: StringName = &"all_buttons", sound_id: StringName = &"ui.click")`

- **Signature return**: `void`

<a name="fn-_on_bound_button_pressed"></a>
#### `_on_bound_button_pressed(sound_id: StringName)`

- **Signature return**: `void`

<a name="fn-_next_sfx_player"></a>
#### `_next_sfx_player()`

- **Signature return**: `AudioStreamPlayer`

<a name="fn-_apply_audio_config"></a>
#### `_apply_audio_config()`

- **Signature return**: `void`

<a name="fn-_get_sfx_volume_db"></a>
#### `_get_sfx_volume_db()`

- **Signature return**: `float`

<a name="fn-_get_music_volume_db"></a>
#### `_get_music_volume_db()`

- **Signature return**: `float`

<a name="fn-_on_config_changed"></a>
#### `_on_config_changed(section: StringName, _key: StringName, _value: Variant)`

- **Signature return**: `void`

