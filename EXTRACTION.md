# Framework Extraction Snapshot (Atiya’s Quest → Framework)

Date: 2025-12-24

This folder is a **script-only snapshot** of reusable systems extracted from the main game.

Goals:
- Preserve a copy of the project’s GDScript code under `Framework/` so we can later open this folder as a separate workspace/project and refactor it into a **generic Godot 4 framework**.
- **Do not refactor the main game yet.** The original project remains the source of truth until the Framework project is validated.

Non-goals (for this snapshot phase):
- Making `Framework/` runnable as a standalone Godot project.
- Copying scenes/resources/assets/addon binaries.
- Changing autoloads in the main game.

---

## What Was Copied

### Script-only mirror
- Copied **all** `.gd` files from the repository into `Framework/`, preserving the original folder structure.
- Excluded everything else: no `.uid`, `.tscn`, `.tres`, images, audio, shaders, `.gdextension` binaries.

Rationale:
- Keeps this extraction low-risk for the game.
- Avoids `.uid` duplication / UID conflicts.
- Lets us refactor and reorganize scripts later without touching the main project.

---

## `class_name` Namespace Policy (Collision Avoidance)

Problem:
- Godot treats `class_name` as global. If both the original scripts and Framework copies are visible to the editor, duplicate `class_name` values can cause conflicts.

Solution used here:
- In `Framework/**`, **every** `class_name X` was changed to `class_name FW_X`.
- All references inside `Framework/**` were updated accordingly (construction, type hints, `extends`, `is/as` checks).

Policy going forward:
- Framework code should keep using `FW_`-prefixed classes.
- Game code stays unprefixed.
- When the Framework becomes its own project, we can choose whether to keep `FW_` permanently or drop it once the game is no longer in the same project.

---

## Important Limitations (Why Framework Isn’t Runnable Yet)

This snapshot contains scripts only. Many scripts reference:
- Scenes (`.tscn`) and resources (`.tres`)
- Shaders (`.gdshader`)
- Textures/audio
- Addon binaries (`.gdextension` + platform libs)

Those references are intentionally **not** copied yet.

---

## Steam Integration Notes (Feature-Gated)

Current behavior (kept as-is):
- Steam is enabled only when `OS.has_feature("steam")` is true (and typically not on Android).
- The Steam wrapper is autoloaded but should become a no-op when Steam isn’t enabled.

Where Steam enablement comes from:
- `custom_features="steam"` is set in desktop export presets in [export_presets.cfg](../export_presets.cfg).
- `steam_appid.txt` is excluded from exports via `exclude_filter="steam_appid.txt"` in [export_presets.cfg](../export_presets.cfg).
- Steam app id is also recorded under `[steam]` in [project.godot](../project.godot).

What we will do later (Framework project phase):
- Copy `addons/godotsteam/` (plugin + binaries) into the Framework project (or vendor it as a dependency).
- Add a Framework-level `Platform/Steam` module with a clean interface, but keep `OS.has_feature("steam")` gating.

---

## Networking Notes (Current State)

Networking code currently:
- Is implemented as a Godot client wrapper around HTTP requests.
- Contains game-specific assumptions (endpoints, payload formats, serializers tied to game-domain classes).

Snapshot intent:
- Keep the networking scripts as reference and a starting point.
- Refactor later into a Framework-friendly net layer that returns engine-typed DTOs (`Dictionary`, `Array`, etc.).

---

## Event Bus Roadmap (FrameworkBus vs GameBus)

Decision:
- Framework signals should be **engine-typed only** (e.g., `Dictionary`, `Array`, `StringName`, `String`, `int`, `float`, `bool`, `NodePath`, `PackedByteArray`).
- Any gameplay signals that reference game-domain types (`Ability`, `Player`, `Combatant`, etc.) belong in a **game-layer bus**, not Framework.

### Phase A (now)
- Keep the existing bus script(s) as reference in the snapshot.
- Do not change the main game.

### Phase B (Framework project refactor)
1. Create `Framework/Signals/FrameworkBus.gd` (autoload in the Framework project)
   - Prefer a small API:
     - `signal event(topic: StringName, payload: Dictionary)`
     - Optional explicit signals like `signal network_status_changed(is_up: bool)` for common concerns.
   - No references to game classes in signatures.

2. Define a game-layer bus in the game project (or “example game module” inside the Framework repo)
   - `GameBus.gd` may keep typed signals.
   - It can listen to `FrameworkBus.event` and translate engine-typed payloads into game calls.

3. Bridge strategy (incremental migration)
   - Start migrating the least game-specific events first (debug logging, generic UI toasts, network status).
   - Keep gameplay events (combat, items, abilities) in GameBus until late.

4. Enforce the boundary
   - FrameworkBus never imports game classes.
   - Framework modules communicate via DTO dictionaries and IDs/paths.

---

## Planned Future Organization (When Framework Becomes Its Own Project)

Target buckets (proposed):
- `Framework/Signals/` — FrameworkBus + signal utilities
- `Framework/Net/` — HTTP wrapper, retries/backoff, DTO parsing
- `Framework/Platform/Steam/` — Steam wrapper, feature-gate, safe no-op
- `Framework/Config/` — settings persistence, schema/migrations
- `Framework/Audio/` — SFX/music controllers (data-driven playlists)
- `Framework/Save/` — JSON stores, archives, caches
- `Framework/UI/` — generic UI helpers (toasts, button wiring)
- `Framework/Utils/` — pure helpers

We will reorganize by moving/renaming **within the Framework project only**.

---

## How to Resume (New Workspace / Separate Project)

When you reopen this folder later:
1. Open `Framework/` as a separate workspace in VS Code.
2. Create a new Godot project in that folder (or a subfolder) and gradually copy in only the required non-script assets.
3. Add autoloads for Framework modules (FrameworkBus, Config, etc.).
4. Fix `res://` paths inside Framework code to reference Framework-local scenes/resources once they exist.
5. Add a minimal demo scene to validate:
   - FrameworkBus emits/receives events
   - Networking client can make a request (mock endpoint ok)
   - Steam module safely no-ops when Steam feature is absent

---

## Sanity Checks Performed
- Verified all `.gd` scripts were copied into `Framework/`.
- Verified there are **zero** unprefixed `class_name` declarations under `Framework/**`.
