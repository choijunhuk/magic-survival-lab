# Magic Survival visual correction

2026-10-29. The user rejected the prior native UI and primitive characters and explicitly requested Magic Survival's actual visual direction. The official game's screenshots are the reference authority; the prior navy/gold marketing panel and triangle/circle actors are not the target.

## Reference images

Official source: https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie

- Combat: https://play-lh.googleusercontent.com/BYKMUCvAX-LFLMC9PuosOCuYw4ojwYzyz-_8sZaHwMVvaWYLI8o8CB-j9ONPKUoILPOoXFndyIqHE-J8Ntzq0Q=s0
- Upgrade: https://play-lh.googleusercontent.com/P3FL4ki8qpZD4JHwiqsbaoPSyrilf5iXGmbD-GCXe5YrRy80K8Ys8jCGikC88rv1QQ0XH7B7-NW5io8ozV1YFw=s0
- Zone menu: https://play-lh.googleusercontent.com/3rl5bC1Rq00iZJIH0snnHfEhLR-gPXjmhF1uCFPKBNOchtrx4SqqY4HWAwmf5-3hio40R9w-R-q59_WRDcw4=s0

Downloaded full-resolution 1080x1920 references live in `.omx/artifacts/magic-survival-reference/` as combat.png, magic-choice.png, zone-menu.png. These are source references, not a generated mockup. Compare at matching portrait ratio and comparable gameplay/choice state.

## Required visual changes

- Battlefield: flat desaturated olive/gray (#7d8066 range), grain, sparse dirt/grass and slab/scuff marks. No navy star field.
- Player: small near-black ragged pointed-hat/robe humanoid silhouette. Draw a short bright green HP strip below. No ship arrow, geometric substitute or large colorful chibi.
- Enemies: irregular black ink/twig swarms, subtle ground shadows, variants by silhouette/scale; no muted blue circles or simple crown polygon boss.
- Spell FX: vivid blue XP points, yellow-white/orange fire cores and trails, jagged white-violet lightning, layered ice/void rings. Color contrast comes from magic over neutral terrain.
- Combat UI: blue XP hairline at the very top, translucent slim dark timer strip with distressed white digits left and pause icon right. No large dashboard, no permanent loadout sentence or kill statistics panel.
- Upgrade: live battlefield darkened behind yellow current level and cyan SELECT MAGIC. Three wide black, rough-edged horizontal cards; monochrome brush icons left, white Korean name/body, yellow level right. No generic gold primary cards. Do not add fake Mana Redeem or unimplemented actions.
- Menu: black full-screen, restrained white title/zone label, central blue foggy forest artwork, actual best-time/progress, low-profile mode selection and a white PLAY action. Remove marketing headline and navy bordered hero panel.
- Pause/results/grimoire: black/white/cyan ink language, compact actual stats, readable scroll and existing behavior. No fake currencies/classes/unavailable zones.
- Fonts: original provided MagicSurvival.ttf for ASCII headings and timers, bundled Noto Sans KR for Korean. Avoid glyphs not supported by their assigned font.

## Constraints

- Keep all8spells/4fusions/12artifacts, quick300/exp600/boss510, phase transitions, Back/lifecycle pause, save path and IDs intact.
- Preserve project config/name to avoid changing desktop/browser user-data identity; UI branding may change independently.
- Touch movement must work anywhere in unhandled combat area, including right-thumb use. Actual UI controls consume input. Keep target hit areas at least44logical and safe-area handling.
- New raster assets are made with built-in imagegen using the official screenshot as reference and saved under godot/assets/generated/. Track prompt/source/tool/alpha/hash; no source PNG overwritten.
- Sprite paths: player-ink.png, enemy-ink.png, boss-ink.png, ground-olive.png, zone-forest.png. ResourceLoader.exists guards may be used while assets are pending, but final captures must use the real assets, not placeholders.
- Before each visual edit pass: capture and record a visual-verdict against these original references. The previous self-referential pass score is not acceptance for this task.
- Validation: simulation52+records34+UI22 remain green, add touch regression where behavior changes, actual native portrait gameplay/choice/menu captures, live Web start/choice/pause, fresh Android APK. Clearly label controlled visual fixtures and don't write fake best records.

## Work split

HUD owner: scripts/hud.gd and new ink style/icon shader helpers only.
World owner: scripts/game.gd and presentation/asset helper only; touch guard included.
Root: generated assets, tests/capture harness, project/export/docs, comparison, APK/Web/Pages delivery.
