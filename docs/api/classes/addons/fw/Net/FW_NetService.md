# addons/fw/Net/FW_NetService.gd

*Class*: `FW_NetService`

### Functions

<a name="fn-configure"></a>
#### `configure(config: FW_ConfigService)`

- **Signature return**: `void`

<a name="fn-_apply_from_config"></a>
#### `_apply_from_config()`

- **Signature return**: `void`

<a name="fn-set_network_enabled"></a>
#### `set_network_enabled(value: bool, autosave: bool = true)`

- **Signature return**: `void`

<a name="fn-should_use_network"></a>
#### `should_use_network()`

- **Signature return**: `bool`

<a name="fn-is_available"></a>
#### `is_available()`

- **Signature return**: `bool`

<a name="fn-health_check"></a>
#### `health_check(callback: Callable, use_cache: bool = true, scene: Node = null)`

- **Signature return**: `void`

<a name="fn-request_json"></a>
#### `request_json(method: int, path_or_url: String, payload: Variant, callback: Callable, extra_headers: PackedStringArray = PackedStringArray()`


<a name="fn-_request_raw"></a>
#### `_request_raw(method: int, url: String, headers: PackedStringArray, body: PackedByteArray, callback: Callable, scene: Node = null, auto_disable: bool = false)`

- **Signature return**: `void`

<a name="fn-_build_headers"></a>
#### `_build_headers(extra_headers: PackedStringArray)`

- **Signature return**: `PackedStringArray`

<a name="fn-_join_url"></a>
#### `_join_url(a: String, b: String)`

- **Signature return**: `String`

<a name="fn-_set_available"></a>
#### `_set_available(ok: bool)`

- **Signature return**: `void`

<a name="fn-_on_config_changed"></a>
#### `_on_config_changed(section: StringName, _key: StringName, _value: Variant)`

- **Signature return**: `void`

