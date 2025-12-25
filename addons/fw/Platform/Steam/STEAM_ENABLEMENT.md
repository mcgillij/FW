# Steam Enablement (External Dependency)

This framework repo does not vendor Steam addons. Steam support is feature-gated and must remain safe to no-op.

## Requirements
- Godot 4 project with a Steam integration addon installed (e.g., GodotSteam) that provides a `Steam` singleton.
- Export preset (desktop) includes a custom feature named `steam`.

## Recommended Setup Steps
1. Install and enable your Steam addon in the Framework project (or in the consuming game project).
2. Add the Steam wrapper as an autoload (example name: `SteamService`).
  - Script: `Platform/Steam/FW_SteamService.gd`
3. Set export preset custom features to include `steam`.
4. For local runs, provide `steam_appid.txt` (do not ship it in exports; exclude it).

## Runtime Behavior
- Steam is enabled only when `OS.has_feature("steam")` is true.
- The wrapper should gracefully no-op when:
  - Steam feature is absent
  - Running on Android
  - The Steam singleton is missing
  - Steam init fails

## Implementation Note
- `FW_SteamService` avoids referencing a global `Steam` identifier and instead uses `Engine.has_singleton("Steam")` + `Engine.get_singleton("Steam")`, so projects without the addon won’t hard-crash just by loading the script.

## Notes
- Keep game-facing calls going through safe wrappers so call sites never need to branch on platform.
