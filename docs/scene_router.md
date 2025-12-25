# Scene Router (FW_SceneRouter)

A lightweight scene routing utility ported from a game ScreenRotator. It helps manage scene transitions and platform-aware behavior (via `FW_Platform`).

Key behaviors:
- Rotates between configured scenes
- Provides convenience helpers for scene transitions

Usage:

- Configure a `FW_SceneRouter` instance in your scene or let `FW_Bootstrap` discover it.
- Use `router.goto(scene_path)` (or the equivalent in the provided API) to navigate.

Notes:
- You can add custom pre/post hooks to integrate preloading and fade transitions.
- Consider preloading scenes using `FW_PreloadQueue` before routing for seamless transitions.
