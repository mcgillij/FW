# addons/fw/Scenes/FW_SceneRouter.gd

*Class*: `FW_SceneRouter`

### Functions

<a name="fn-configure"></a>
#### `configure(config: FW_ConfigService)`

- **Signature return**: `void`

<a name="fn-_ready"></a>
#### `_ready()`

- **Signature return**: `void`

<a name="fn-_on_window_size_changed"></a>
#### `_on_window_size_changed()`

- **Signature return**: `void`

<a name="fn-_on_node_added"></a>
#### `_on_node_added(node: Node)`

- **Signature return**: `void`

<a name="fn-set_rotated"></a>
#### `set_rotated(value: bool, persist: bool = true)`

- **Signature return**: `void`

<a name="fn-toggle_rotation"></a>
#### `toggle_rotation(persist: bool = true)`

- **Signature return**: `void`

<a name="fn-setup_rotation_rig"></a>
#### `setup_rotation_rig()`

- **Signature return**: `void`

<a name="fn-teardown_rotation_rig"></a>
#### `teardown_rotation_rig()`

- **Signature return**: `void`

<a name="fn-change_scene"></a>
#### `change_scene(path: String, transition_params: Dictionary = {})`

- **Signature return**: `void`

<a name="fn-_change_scene_fade"></a>
#### `_change_scene_fade(path: String)`

- **Signature return**: `void`

<a name="fn-_change_scene_with_optional_shader"></a>
#### `_change_scene_with_optional_shader(path: String, transition_params: Dictionary)`

- **Signature return**: `void`

<a name="fn-_swap_scene"></a>
#### `_swap_scene(path: String)`

- **Signature return**: `bool`

<a name="fn-get_main_scene"></a>
#### `get_main_scene()`

- **Signature return**: `Node`

<a name="fn-get_current_scene_path"></a>
#### `get_current_scene_path()`

- **Signature return**: `String`

<a name="fn-_get_random_preset_name"></a>
#### `_get_random_preset_name()`

- **Signature return**: `String`

<a name="fn-_apply_rotation_from_config"></a>
#### `_apply_rotation_from_config()`

- **Signature return**: `void`

<a name="fn-_on_config_changed"></a>
#### `_on_config_changed(section: StringName, key: StringName, _value: Variant)`

- **Signature return**: `void`

