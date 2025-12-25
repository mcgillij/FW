# State Machine (FW_StateMachine)

A small Node-based state machine that supports both:
- Object states with method hooks (`on_enter`, `on_exit`, `on_update`, `on_event`)
- Dictionary-backed states with Callable hooks (useful for lightweight tests)

## API

- `add_state(name: StringName, state: Variant)` — register a state
- `start(initial: StringName, data: Variant = null)` — start at a state
- `transition_to(next: StringName, data: Variant = null)` — change state
- `tick(delta: float)` — call `on_update` once
- `send_event(event)` — deliver an event to the current state
- `signal state_changed(prev, next)` — emitted on transitions

## Example

```gdscript
# Object-based state
class MyState extends FW_State:
	func on_enter(prev, data): print("entered")

# Dictionary-based state (test-friendly)
var state_a := {
	"on_enter": func(_prev,_data): print("enter a"),
	"on_exit": func(_next): print("leave a"),
}

state_machine.add_state(&"a", state_a)
state_machine.add_state(&"b", MyState.new())
state_machine.start(&"a")
state_machine.transition_to(&"b")
```

## Integration notes
- `FW_Bootstrap` can accept an injected `state_machine` or create one if `create_state_machine=true`.
- Keep state logic simple and testable; prefer small, single-responsibility states.
