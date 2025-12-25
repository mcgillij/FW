# FW_Bootstrap

FW_Bootstrap is the orchestrator: it discovers services on the scene tree or accepts explicit injection. Callers typically call `FW_Bootstrap.init(options: Dictionary)` from a main scene or test harness.

## Basic usage

```gdscript
var r := FW_Bootstrap.init({
	"init_steam": false,
	"input_actions": input_actions_node,
	"input_rebind": input_rebind_node,
	"resource_cache": resource_cache_node,
	"preload_queue": preload_queue_node,
})

if not r.get("ok", false):	# handle failures
	print("bootstrap failed: ", r)

var services := r["services"]
```

## Options

- `init_steam` (bool): whether to try to init Steam platform bindings
- `input_actions` (Node): node that defines actions and defaults
- `input_rebind` (Node): optional input rebinding service
- `resource_cache` / `preload_queue` (Node): optional resource services
- `state_machine` (Node): optional state machine to inject
- `create_resource_cache` / `create_preload_queue` / `create_state_machine` (bool): instruct bootstrap to create & attach these nodes when not injected
- `require_*` flags: make missing services a hard opt-in check and issue a warning if missing

## Return value

The init call returns a Dictionary with keys:
- `ok` (bool)
- `services` (Dictionary) — map of found/created services
- `warnings` (Array of Strings)

## Testing tips

- Use `FW_Bootstrap.init()` with short-lived nodes injected when writing unit tests, or use `create_*` flags to test the bootstrap creation path.
- The repo contains `tests/TestBootstrap.gd` as an example smoke test.
