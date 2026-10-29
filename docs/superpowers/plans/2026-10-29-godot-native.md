# Godot Native Implementation Plan

> **For agentic workers:** Use the existing approved full design and this bounded implementation plan; work task-by-task and verify before completion.

**Goal:** Deliver a playable native Godot build matching the verified reference combat and a fresh Android debug APK.

**Architecture:** A pure RefCounted simulation owns combat state; native scene/HUD own rendering and input; a small record store owns user:// persistence. Copy the28used reference assets into the Godot resource root with provenance. Keep HTML as a reference, not the app runtime.

**Tech Stack:** Godot4.7stable/GDScript/Compatibility renderer, existing Android SDK and export templates. No runtime addons.

**Spec:** ../../gdd/FULL_DESIGN.md; ../../../godot/DESIGN.md; ../specs/2026-10-29-expansion-design.md for the first boss slice.

## Global Constraints

- Quick300s, expedition600s with boss510s;8spells/4fusions/12artifacts. Full GDD content is future scope.
- Death > deadline > bosskill. Choice/pause/background stop simulation. Existing assets retain provenance.
- Pure state keys follow the reference camelCase schema to simplify renderer parity. Godot methods use snake_case.
- Browser records stay untouched. Godot stores real native records in user://; no fabricated migration from inaccessible browser storage.
- No production signing credentials or store publication in this task. Debug APK, emulator and physical evidence are separate.

## Shared Interfaces

- `scripts/simulation.gd`: `extends RefCounted`; `var state: Dictionary`; `var catalog: Dictionary`; `_init(seed_value:int=1, mode:String="quick")`; `reset(mode:String="quick", seed_value:int=1)`; `start()`; `tick(dt:float,input:Vector2=Vector2.ZERO)`; `toggle_pause()`; `choose_upgrade(id:String)->bool`; `choose_artifact(id:String)->bool`; `orbit_position(index:int)->Vector2`.
- Catalog `data/content.json`: `spellIds`, `upgrades`, `fusions`, `artifacts`, `modes`; same IDs and icon paths as reference. Godot icons load as `res://`+icon.
- `scripts/records.gd`: `extends RefCounted`; `_init(path:String="user://records.json")`; `load_records()`; `for_mode(mode:String)->Dictionary`; `record(state:Dictionary)->bool`; `var last_error:String`; defaults real empty0records. Save terminal results once by game/HUD.
- `scripts/game.gd`: mainNode2D, `sim` and `records` fields; controls HUD callbacks, simulation ticks, world draw and touch. `scripts/hud.gd`: nativeCanvasLayer/Control, `setup(game:Node)` and `refresh(state:Dictionary,catalog:Dictionary,record:Dictionary,error:String="")`; UI calls game methods `begin(mode)`, `pause_run()`, `choose(id)`, `go_home()`.
- Main scene `main.tscn` attaches game.gd. UI must use preloads so clean headless runs do not require stale global class cache.

## Review Focus

- GDScript dictionary/array semantics must not create duplicate drops or skipped damage on removal.
- Native effects must match real rules; all8spells and4fusions require behavior tests.
- Pause and Android app lifecycle must freeze every timer and clear held touch.
- Hangul, three choices and primary actions fit narrow mobile layouts; warning vs active danger stays distinct.
- Corrupt/blocked/native record writes and Android export configuration must not touch unrelated user data or credentials.

### Task1: Content and simulation
- [x] Export catalog/copy28assets, preserving hashes and sources.
- [x] Write headless behavioraltests before port; observe missing-feature failures.
- [x] Port core rules to simulation.gd, preserving catalog caps, effects, fusions, artifacts, boss and terminal priorities.
- [x] Run headless suite and JS reference suite; require all green.

### Task2: Scene and native HUD
- [x] Build real start/play/pause/upgrade/artifact/result/native codex states with shared style.
- [x] Render enemy kinds, all spells, zones/strikes/hazards, boss health/direction, XP and touch joystick.
- [x] Support keyboard/touch, mobile Back and background pause without automatic resume.
- [x] Capture actual desktop/native UI and narrow layouts; run visual verdict before further visual edits.

### Task3: Native records
- [x] Test empty/corrupt/partial records, independent modes, win ranking, write failure before implementation.
- [x] Implement validated native persistence with temp write/rename and honest errors; never delete browser records.
- [x] Verify fresh start, win/loss/retry, restart persistence and isolated test cleanup.

### Task4: Android delivery and acceptance
- [x] Import project headless and parse all scripts; launch real native window.
- [x] Create Android debug preset excluding tests/fixtures/private files and export a fresh APK with matching templates.
- [x] Verify package/signature/ABI, install to an isolated emulator if available and test launch/input/pause/choices/results.
- [x] Review code independently, fix material findings with regression tests, update GDD engine choice and current-state docs.
- [x] Commit/push with Lore trailers; attach APK/project/evidence. Report physical-device and human balance limits honestly.

### Task5: Same-project web preview and GitHub Pages
- [x] Export Godot Web in Compatibility/single-thread mode, with no runtime server or custom isolation headers required.
- [x] Verify local browser loading, Korean text, start/input/pause and persistent-record error handling.
- [x] Add a least-privilege GitHub Actions workflow using official Godot binaries/templates and official Pages actions.
- [x] Enable Pages, run deployment and verify the actual HTTPS game URL after success. Never report a configured but unbuilt URL as live.
