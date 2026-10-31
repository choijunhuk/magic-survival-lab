# Godot Native Design

## Visual correction authority - 2026-10-29
- User rejected the prior navy/gold UI and primitive characters. docs/visual/magic-survival-reference.md and the official Magic Survival screenshots override contradictory visual language below.
- Target: muted olive/gray textured ground; tiny black robed subject and ragged ink enemies; green HP below player; slim top blue XP/time/pause; black rough upgrade rows, cyan headings, white distressed ASCII type.
- Menu is black with blue forest zone art and a white PLAY action. Remove marketing hero copy and oversized dashboard blocks.
- Keep gameplay/save IDs/project config/name stable. User-data compatibility and functional tests remain binding. Native project/export/record contracts below still apply.

## Source of truth
- Active, 2026-10-29. User selected Godot 4 + GDScript for the mobile app.
- Full vision: ../docs/gdd/FULL_DESIGN.md. HTML reference: ../core.mjs and ../game.js, verified at commit78a47c4 with35tests.
- Legacy modes preserve8spells/4fusions/12artifacts, quick300s and expedition600s/boss510s. The release campaign adds900s/boss810s with24/36/96 content,6 zones/bosses/classes,24 research,12 events and24normal/18elite definitions; validation status is tracked in ../docs/implementation/1.0-acceptance.md. The 2.x catalog remains proposed.

## Brand
- Magic Survival reference: black ink silhouettes on quiet olive/gray terrain, bright magic, cyan headings and distressed white actions. See ../docs/visual/magic-survival-reference.md.
- Reuse imported icons with their source manifest; new art is separate. The current app is a fan-game prototype.

## Product goals
- A real native game with movement, automatic attacks, XP, choices, fusions, artifacts, boss, results and local records.
- Deliver working Godot source and a fresh Android debug APK. Desktop/headless/emulator/physical acceptance are separate.
- No account, backend, payment, ads, hidden sample records, browser WebView or duplicate engine layer.

## Personas and jobs
- Mobile player using one thumb; PC keyboard remains a convenient development/play mode.
- Understand the next attack, choose a build and retry without setup friction.

## Information architecture
- Welcome: fixed hub tabs and PLAY footer, scrolling map/class/research/codex/record/mode body, six distinct ink zone previews and actual profile records.
- Play: thin top XP/time/pause, short green HP below player; boss health and direction when relevant. Loadout and recipes live in pause.
- Upgrade/artifact:3readable choices, actual icon/name/effect, combat frozen.
- Pause: resume and current loadout/recipe list. Result: reason/time/kills/level, retry/home.

## Design principles
- Separate simulation from scene/render/input so rules can be tested without rendering.
- Same-frame death > deadline > bosskill; no reward/UI race after terminal outcome.
- Active danger differs from warning by fill, outline/pattern and timing, not color alone.

## Visual language
- Black #020302, olive ground #7d8065, white #f2f3eb, cyan #60eadb, yellow #ffdf56 for levels, blue #50b9ff for XP.
- Bundle Noto Sans KR for readable Korean and the provided MagicSurvival font for ASCII display text. Body text >=18logical px; separate visible thin icons from generous touch regions.
- Rough black choice rows, white brush icons, large cyan heading and a restrained occult seal. Menu art is blue fog forest. No 3D camera/postprocessing.
- Persistent effects bounded; a filled danger region must not look identical to its warning.

## Components
- Native Control/Container/Button/Label/TextureRect/ProgressBar; styles built once and reused.
- Canvas draws generated alpha sprites for player/enemies/boss, tiled ground, layered spell FX and drag feedback; texture imports for original and generated UI icons.
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
