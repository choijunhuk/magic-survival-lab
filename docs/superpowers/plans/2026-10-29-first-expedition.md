# First Expedition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Preserve quick mode and deliver a playable600s expedition with a telegraphed boss, reliable outcome and separate records.

**Architecture:** Extend the existing pure state/combat module; rendering and browser storage remain in game.js. Keep existing createGame(rng) callers working by adding an optional second mode argument. New content and long-term scope belong to the expanded GDD; this first playable layer does not cap that vision.

**Tech Stack:** Existing HTML/CSS/JavaScript/Canvas, Node built-in tests, no new runtime dependencies.

**Spec:** ../specs/2026-10-29-expansion-design.md sections4,5D,10,11 and ../../gdd/AUTHORING_BRIEF.md.

## Global Constraints

- Quick remains300s with existing8spells4fusions12artifacts; expedition600s, boss at510s.
- Death > deadline > bosskill; choice/pause/background must stop gameplay clocks.
- New persistent records must not erase legacy best time/kills; corrupt/blocked storage must remain playable.
- No dependencies, fake records, network requirement or implicit new controls.

## Review Focus

- Simultaneous boss death/player death/deadline must not double-commit an outcome.
- Boss warning areas must not damage during warning or continue while paused.
- Boss must remain reachable when player runs away and direction indicator must stay visible.
- Old quick records and old callers must keep their behavior.
- Focus/keyboard/IME/mobile choice controls must remain usable.

### Task1: Pure expedition rules and boss combat

**Files:** core.mjs, tests/expedition.test.mjs.

**Interfaces:** createGame(rng=Math.random, mode='quick'); exported MODES with quick/expedition id,label,duration; state.mode and state.duration; state.bossId, boss entity kind='boss', state.hazards entries with x,y,radius,warning,active,hit status; state.endReason. Existing arrays/attack collision retained.

- [ ] Write failing tests for backward-compatible mode defaults, boss once at510, telegraph before damage, pause freeze, boss death victory, deadline loss, simultaneous death priority, boss reachability and enemy cap.
- [ ] Run node --test tests/expedition.test.mjs; confirm behavioral failures.
- [ ] Implement smallest pure-state change; boss uses existing enemy damage handling and explicit state independent of elite drops. Starting boss health/hit timings are tunable hypotheses.
- [ ] Run expedition tests and all existing tests; require all green.

### Task2: Mode selection and boss presentation

**Files:** index.html, game.js, style.css, build.mjs if needed.

**Consumes:** MODES, createGame(rng,mode), state.bossId/hazards/endReason.
**Produces:** selectable quick/expedition, per-mode HUD/target, distinct boss silhouette/health/telegraphs/direction, correct result reasons and focus behavior.

- [ ] Use existing start/choice/pause components and DESIGN tokens; add no tool-specific UI.
- [ ] Wire mode selection, reset state per chosen mode, update duration displays and victory copy.
- [ ] Render warnings/active danger with distinct pattern and color, boss health and offscreen direction; maintain reduced-motion.
- [ ] Build and run browser desktop/mobile smoke, including start→playing→pause→boss→win/loss→retry.

### Task3: Mode-specific record compatibility

**Files:** game.js or small records.mjs only if separation is useful, tests/records.test.mjs, build.mjs.

**Produces:** versioned quick/expedition records, loss reasons and boss flag, preserve legacy records; no run resume.

- [ ] Test legacy valid record migration, corruption, write rejection and mode separation before implementation.
- [ ] Implement bounded reads/writes with explicit safe fallback; no accidental legacy deletion.
- [ ] Run targeted tests then full suite/check/build.

### Task4: Verify, document and deliver

**Files:** DESIGN.md, README.md, artifacts (ignored), .omx/state/first-expedition/ralph-progress.json (ignored).

- [ ] Run npm test, npm run check, npm run build; verify standalone play.html and atlas links.
- [ ] Browser verification at desktop1440x1000 and mobile390x844/320x740. Record normal-play vs controlled fixtures separately.
- [ ] Capture screens and visual verdict against existing visual language before further UI edits.
- [ ] Obtain fresh code review, fix material findings with regression proof, update current-state docs.
- [ ] Commit using Lore trailers; push authorized project branch and report exact completion/limits. Real-device performance and human full-run balance remain separately marked until executed.
