# addons/fw/State/FW_State.gd

*Class*: `FW_State`

### Functions

<a name="fn-on_enter"></a>
#### `on_enter(_prev: StringName, _data: Variant = null)`

Base class for a state used by FW_StateMachine.
Override the hooks you need.

- **Signature return**: `void`

<a name="fn-on_exit"></a>
#### `on_exit(_next: StringName)`

- **Signature return**: `void`

<a name="fn-on_update"></a>
#### `on_update(_delta: float)`

- **Signature return**: `void`

<a name="fn-on_event"></a>
#### `on_event(_event: Variant)`

- **Signature return**: `void`

