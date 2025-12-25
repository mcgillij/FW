# addons/fw/Input/FW_InputRebindService.gd

*Class*: `FW_InputRebindService`

### Functions

<a name="fn-configure"></a>
#### `configure(config: FW_ConfigService, actions: Variant, autosave_enabled: bool = true)`

- **Signature return**: `void`

<a name="fn-begin_rebind"></a>
#### `begin_rebind(action: StringName)`

- **Signature return**: `void`

<a name="fn-cancel_rebind"></a>
#### `cancel_rebind()`

- **Signature return**: `void`

<a name="fn-feed_event"></a>
#### `feed_event(event: InputEvent)`

- **Signature return**: `bool`

<a name="fn-apply_event"></a>
#### `apply_event(action: StringName, event: InputEvent)`

- **Signature return**: `void`

<a name="fn-clear_bind"></a>
#### `clear_bind(action: StringName)`

- **Signature return**: `void`

<a name="fn-restore_defaults"></a>
#### `restore_defaults()`

- **Signature return**: `void`

<a name="fn-_apply_config_binds"></a>
#### `_apply_config_binds()`

- **Signature return**: `void`

<a name="fn-_persist_action_binds"></a>
#### `_persist_action_binds(action: StringName)`

- **Signature return**: `void`

