# Testing & CI

This framework is designed to be testable in headless mode.

Quick commands:

- Run tests locally:

```
make test
```

This runs Godot in headless mode and executes the `tests/TestBootstrap.tscn` smoke test.

Tips for writing tests:
- Use `FW_Bootstrap.init()` with injected nodes to avoid IO and platform-specific subsystems.
- Tests should `get_tree().quit(code)` with `code` set to non-zero when failures occur so CI will catch them.

CI suggestions:
- Use the same `make test` target in CI and run in a clean environment.
- Capture logs and test outputs (stdout) to aid debugging in case of failures.
