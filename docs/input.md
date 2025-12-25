# Input & Rebinding

Components:
- `FW_InputActions` — node that declares input actions and default mappings
- `FW_InputRebindService` — runtime rebinding, persisted under config

Usage:

- Ensure `FW_InputActions` is present at startup (Bootstrap can find it or you can pass it in).
- To rebind an action:

```gdscript
input_rebind.begin_rebind("ui_accept")
# user input is captured by the service; call apply when done
input_rebind.apply_rebind("ui_accept")
```

Persistence:
- Binds are stored in the framework config under `[input] binds` by default.
- The `input_autosave` bootstrap flag controls whether rebinding is auto-saved.

Testing tip:
- The `FW_InputActions.reset_to_defaults()` helper is useful to ensure tests use a deterministic state.
