# Framework

This repository is the build-from-here root for the extracted Godot 4 framework code.

This repository is still a scripts-only snapshot; you will need a standalone Godot project to actually run anything.

Documentation

- The framework documentation lives in `docs/`. Start at `docs/index.md` for a guided overview and detailed pages on Bootstrap, services, testing, and examples.


## Recommended Autoloads (Framework Project)

Keep the autoload surface small. Suggested autoload names:
- `Config` -> `Config/FW_ConfigService.gd`
- `FrameworkBus` -> `Signals/FW_FrameworkBus.gd`
- `Net` -> `Net/FW_NetService.gd`
- `Audio` -> `Audio/FW_AudioService.gd`

Steam is optional:
- `SteamService` -> `Platform/Steam/FW_SteamService.gd` (see `Platform/Steam/STEAM_ENABLEMENT.md`)

Optional:
- `WindowPrefs` -> `Config/FW_WindowPrefs.gd`

## Bootstrap Order

In your main scene (or an early boot node), call the following in order:

1) Load config
- `Config.load()`

2) Register framework defaults
- `FW_FrameworkDefaults.apply(Config)`

3) Configure services from config
- `Net.configure(Config)`
- `Audio.configure(Config)`

Optional window handling (desktop):
- `WindowPrefs.configure(Config)`
- `WindowPrefs.apply_to_current_window()`

## Default Config Keys

The framework registers baseline defaults under:
- `[audio]`
  - `sfx_enabled` (bool)
  - `music_enabled` (bool)
  - `sfx_volume_db` (float)
  - `music_volume_db` (float)
- `[net]`
  - `enabled` (bool)
  - `base_url` (string)
  - `api_key` (string)
  - `healthcheck_path` (string)
  - `healthcheck_cache_seconds` (float)

Optional Steam keys (only used if you call `SteamService.configure(Config)`):
- `[steam]`
  - `require_feature` (bool)
  - `require_ownership` (bool)

## UI Helpers

- `UI/FW_ModalOverlay.gd`: full-screen click/touch capture overlay for dismissing modals
- `UI/FW_ContextMenu.gd`: framework-safe context menu wrapper around `PopupMenu`

## Remaining Work (Short List)

- Create a minimal runnable Godot project/demo scene that autoloads `Config`, `FrameworkBus`, `Net`, `Audio` and exercises:
  - config load/save + defaults
  - a sample bus event
  - a net health check against a mock endpoint
  - audio register/play (with placeholder streams)
- Decide packaging strategy for external dependencies (`addons/` stays external; document expected singletons/features).
- Add a tiny “bootstrap” node/script example (one file) that shows the recommended init order.
