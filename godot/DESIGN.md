# Godot Native Design

## Source of truth
- Active, 2026-10-29. User selected Godot 4 + GDScript for the mobile app.
- Full vision: ../docs/gdd/FULL_DESIGN.md. HTML reference: ../core.mjs and ../game.js, verified at commit78a47c4 with35tests.
- Native first build preserves8spells/4fusions/12artifacts, quick300s and expedition600s/boss510s. Later GDD catalogs remain proposed content.

## Brand
- Dark grimoire/ruins, high-contrast magic, teal/silver text and gold actions. Avoid noisy surfaces that obscure danger.
- Reuse imported icons with their source manifest; new art is separate. The current app is a fan-game prototype.

## Product goals
- A real native game with movement, automatic attacks, XP, choices, fusions, artifacts, boss, results and local records.
- Deliver working Godot source and a fresh Android debug APK. Desktop/headless/emulator/physical acceptance are separate.
- No account, backend, payment, ads, hidden sample records, browser WebView or duplicate engine layer.

## Personas and jobs
- Mobile player using one thumb; PC keyboard remains a convenient development/play mode.
- Understand the next attack, choose a build and retry without setup friction.

## Information architecture
- Welcome: title, short promise, quick/expedition selection, actual best record, start.
- Play: health/time/XP/level, small loadout strip, pause; boss health and direction when relevant.
- Upgrade/artifact:3readable choices, actual icon/name/effect, combat frozen.
- Pause: resume and current loadout/recipe list. Result: reason/time/kills/level, retry/home.

## Design principles
- Separate simulation from scene/render/input so rules can be tested without rendering.
- Same-frame death > deadline > bosskill; no reward/UI race after terminal outcome.
- Active danger differs from warning by fill, outline/pattern and timing, not color alone.

## Visual language
- Ink #0b1016, panel #111b25, silver #e2e8e5, gold #d9b66f, teal #80d4d1.
- Bundle an openly licensed Korean font. Body text >=18logical px and primary touch targets >=48logical px at540viewport.
- Reuse simple flat panels, slim separators, generous spacing and a restrained procedural sigil. No 3D camera/postprocessing.
- Persistent effects bounded; a filled danger region must not look identical to its warning.

## Components
- Native Control/Container/Button/Label/TextureRect/ProgressBar; styles built once and reused.
- Canvas drawing for combat entities, projectiles, rings and joystick; texture imports for existing UI icons.
- HUD owns layout and selection callbacks; game owns scene/input/camera; simulation owns all combat rules.

## Accessibility
- Korean text renders without OS-only font assumptions; text remains readable over the arena.
- Keyboard arrows/WASD, P/Esc/Android Back pause, 1/2/3choice; native button focus/Space/Enter retained.
- Choice/pause/app background freeze combat; no automatic resume from background.
- Danger outline and fill, labels for result reason, readable focus. Optional sound is not required for survival.

## Responsive behavior
- Portrait540x960logical reference, inspect narrow320x740and390x844equivalents and actual emulator resolution.
- Respect mobile display safe area. Keep pause and primary actions outside cutouts/navigation area.
- Choice panels scroll when needed; start/retry and all3choices must remain reachable. No horizontal overflow.

## Interaction states
- ready/playing/paused/upgrade/artifact/won/lost mirror the reference phase contract.
- World simulation ticks only while playing. Clear captured touch input when leaving play.
- Invalid/missing/blocked records do not stop play; save errors show a truthful short message.

## Content voice
- Short Korean instructions and concrete effect descriptions. Never call planned GDD content implemented.
- Engine/agent/build-system details stay out of player flows.

## Implementation constraints
- Godot4.7stable, GDScript, Compatibility renderer, fixed60Hzsimulation; no third-party runtime addons.
- Use seeded RandomNumberGenerator for reproducible Godot tests; JS and Godot generators need not share bitwise sequences.
- World coordinates and timings follow the reference; screen scale does not change collisions or speed.
- Export includes only native source/data/assets, no credentials, fixtures, test scripts or HTML/PDF.

## Open questions
- Device performance and human full-run balance require fresh evidence; do not infer them from headless tests.
- Source image/font redistribution terms remain documented separately before a public store release.
