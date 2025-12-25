# addons/fw/State/FW_StateMachine.gd

*Class*: `FW_StateMachine`

### Functions

<a name="fn-add_state"></a>
#### `add_state(name: StringName, state: Variant)`

- **Signature return**: `void`

<a name="fn-has_state"></a>
#### `has_state(name: StringName)`

- **Signature return**: `bool`

<a name="fn-get_state"></a>
#### `get_state()`

- **Signature return**: `StringName`

<a name="fn-start"></a>
#### `start(initial: StringName, data: Variant = null)`

- **Signature return**: `Dictionary`

<a name="fn-transition_to"></a>
#### `transition_to(next: StringName, data: Variant = null)`

- **Signature return**: `Dictionary`

<a name="fn-tick"></a>
#### `tick(delta: float)`

- **Signature return**: `void`

<a name="fn-send_event"></a>
#### `send_event(event: Variant)`

- **Signature return**: `void`

<a name="fn-_process"></a>
#### `_process(delta: float)`

- **Signature return**: `void`

<a name="fn-_call_state"></a>
#### `_call_state(state_name: StringName, method: String, args: Array)`

- **Signature return**: `void`

