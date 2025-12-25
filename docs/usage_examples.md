# Usage Examples

This page contains short, copyable examples for common tasks.

## Bootstrap with created resources

```gdscript
var r = FW_Bootstrap.init({
	"create_resource_cache": true,
	"create_preload_queue": true,
	"create_state_machine": true,
})
var services = r["services"]
var cache = services["resource_cache"]
var preload = services["preload_queue"]
var sm = services["state_machine"]
```

## Small state machine snippet

```gdscript
state_machine.add_state(&"idle", {"on_enter": callable(self,"_on_idle")})
state_machine.start(&"idle")
state_machine.transition_to(&"run")
```

## Preload then route

```gdscript
preload_queue.start(["res://scenes/level1.tscn","res://scenes/common.tres"])
preload_queue.connect("completed", callable(self, func() -> void:
	scene_router.goto("res://scenes/level1.tscn")
))
```

### Full example (preload then route)

See `examples/preload_route_example.gd` for a reusable example that connects `preload_queue.completed` and calls `scene_router.change_scene()` when done. This pattern keeps transitions smooth while assets finish loading.

## State machine patterns

- Guard states: validate `data` passed into `start()` to decide whether to stay or redirect
- Event-driven states: use `send_event()` to forward arbitrary events into the current state
- Tick/update: enable `auto_process` on the state machine for per-frame `on_update` calls

See `examples/state_machine_patterns.gd` for copyable snippets.

## Save migration example

If you need to change save schema, implement a migration method in `FW_SaveService` following the naming convention `_migrate_<from>_to_<to>()`. For example, to go from schema `0` to `1`:

```gdscript
func _migrate_0_to_1(v0: Dictionary) -> Dictionary:
	var v1 = v0.duplicate(true)
	# add new default
	v1["data"]["player_name"] = "Player"
	return v1
```

You can find a companion example at `examples/save_migration_example.gd`.
