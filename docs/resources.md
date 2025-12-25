# Resources: FW_ResourceCache & FW_PreloadQueue

## FW_ResourceCache

- Provides simple caching semantics for resources, with typed getters and structured error results.
- Main APIs: `get_resource(path: String)`, `get_result(path: String)`, `clear()`
- Config via `FW_FrameworkDefaults` under `[resources]` (enable, max_entries)

Example:

```gdscript
var r = services["resource_cache"].get_result("res://path.tres")
if r["ok"]:
	var res = r["resource"]
else:
	print("failed to load: ", r["error"]) # r can include reason and path
```

## FW_PreloadQueue

- Preloads resources across multiple frames and emits signals: `progress`, `completed`, `cancelled`.
- Use `start(paths: Array)` to kick off a preload batch.
- Optionally integrates with the cache to populate entries.

Example:

```gdscript
preload_queue.start(["res://a.tres","res://b.tres"])
preload_queue.connect("completed", callable(self,"_on_preload_done"))
```

## Notes
- Preloading and caching are useful for scene transitions; consider preloading assets you know will be needed.
- `FW_Bootstrap` can create these nodes automatically with `create_resource_cache` and `create_preload_queue`.
