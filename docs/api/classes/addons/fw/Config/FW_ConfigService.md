# addons/fw/Config/FW_ConfigService.gd

*Class*: `FW_ConfigService`

### Functions

<a name="fn-register_defaults"></a>
#### `register_defaults(defaults_by_section: Dictionary)`

- **Signature return**: `void`

<a name="fn-load"></a>
#### `load(path: String = DEFAULT_PATH)`

- **Signature return**: `void`

<a name="fn-save"></a>
#### `save()`

- **Signature return**: `void`

<a name="fn-get_value"></a>
#### `get_value(section: StringName, key: StringName, fallback: Variant = null)`

- **Signature return**: `Variant`

<a name="fn-set_value"></a>
#### `set_value(section: StringName, key: StringName, value: Variant, autosave: bool = false)`

- **Signature return**: `void`

<a name="fn-get_bool"></a>
#### `get_bool(section: StringName, key: StringName, fallback: bool = false)`

- **Signature return**: `bool`

<a name="fn-get_int"></a>
#### `get_int(section: StringName, key: StringName, fallback: int = 0)`

- **Signature return**: `int`

<a name="fn-get_float"></a>
#### `get_float(section: StringName, key: StringName, fallback: float = 0.0)`

- **Signature return**: `float`

<a name="fn-get_string"></a>
#### `get_string(section: StringName, key: StringName, fallback: String = "")`

- **Signature return**: `String`

<a name="fn-get_vec2"></a>
#### `get_vec2(section: StringName, key: StringName, fallback: Vector2 = Vector2.ZERO)`

- **Signature return**: `Vector2`

<a name="fn-has_key"></a>
#### `has_key(section: StringName, key: StringName)`

- **Signature return**: `bool`

<a name="fn-_ensure_save_dir_exists"></a>
#### `_ensure_save_dir_exists(path: String)`

- **Signature return**: `void`

