# 균열 연대기 / Magic Survival Lab - GDD authoring contract

2026-10-29. User says previous proposal was too small and wants a substantive PDF longer than 70 pages, including long-term expansion. They also authorized implementation and the separate Claude hook repair. This GDD replaces the old proposal's final scope; the old first10min slice remains the first implementation step.

User platform override: native mobile app is now the production target; HTML remains the tested reference prototype. User selected Godot4 + GDScript on2026-10-29; engine selection is confirmed. Installed Godot4.7 was verified. Android-first/iOS-later is a proposed order, not a confirmed platform limitation. The existing no-new-dependencies rule does not prohibit the explicitly requested native engine. Do not describe the final product as HTML-only or native migration as indefinitely deferred.

## Product and counts (all totals, never incremental)

- Existing verified baseline: HTML/Canvas/ES modules, quick300s, 8spells/4fusions/12artifacts, procedural backdrop1, normal/swift/elite, no boss/classes/research, best time/kills localStorage, 25tests; source baseline commit4ae06b1c496dff7acb644392cb258f5b45d917a5.
- R0 first playable expedition: quick preserved; expedition maximum600s, boss spawns510s; death > deadline > bosskill priority, automatic attacks, pause stops all clocks, existing8/4/12. No fake sample records.
- Alpha build pack:12spells/8fusions/20artifacts/1map/1boss/3events, one resonance choice per run on plasma (3branches). Matches earlier slice.
- Release1.0:24base spells/36fusion recipes/96artifacts/6starting archetypes/6maps/6main bosses/24normal enemy variants/18elites/12events/24research nodes. Expedition maximum15min, finalboss13:30. Quick5min stays.
- Long-term2.x vision:48base spells/72fusions/180artifacts/12archetypes/9maps/9mainbosses/48normal variants/36elites/24events/48research nodes. These are proposed design targets, NOT implemented or user-approved numeric requirements. Distinguish a complete1.0 catalog from later expansion ranges.
- Modes:quick, expedition, seeded offline challenge, practice/sandbox; later endless/ascension/weekly local challenge. No required account/network, pay-to-win, gacha, always-online, multiplayer or live service in1.0. Multiplayer is a separate feasibility gate, not secretly required architecture.
- Distinctive pillars: fusion behavior transformations + limited resonance tradeoffs; map anomalies and optional encounters; enemy ecology/telegraphed bosses; horizontal research and codex discovery; escalating endgame that changes decision-making rather than HP-only inflation.

## Coherence

- Quick's old rules remain compatible. Expedition6magic slots/3fusion slots; fusion requires two base spellsLv3, ingredients NOT consumed, per-base maxLv5. Resonance1/run (not1/fusion). Fusion cannot cascade-trigger itself. No automatic effect before explicit selection.
- Fixed simulation step1/60s, world units correspond to initial CSS canvas px at1x camera. Future normalized damage unit D=100 corresponds to prototype base damage1; ALWAYS label future design units vs actual runtime. Player base HP6, speed220units/s in existing source. Proposed combat numbers need tests, not recall of original mobile game.
- Schools8: arcane, fire, frost, storm, gravity, shadow, vitality, seal. BaseIDs M01-M24 launch, M25-M48 reserved expansion. Original eight map M01bolt,M02orbit,M03lightning,M04frost,M05fireball,M06vortex,M07meteor,M08pulse. Agent systems owns remaining names and all fusionIDs F01-F36, artifactIDs A001-A096.
- Other IDs: maps Z01-Z06 launch/Z07-Z09 expansion; bosses B01-B06/B07-B09; classes C01-C06/C07-C12; event E01-E12; research R01-R24, laterR25-R48. Worlds author owns these.
- Resource model: only1persistent currency '연구 잔재' (research residue), and run-only XP. No second premium currency. First expedition has no permanent upgrades. Release research24 nodes, choose at most6active points, free reset outside run, no respec midfight, baseline clearable without research. Additional world rewards are unlock flags/codex, not spendable currencies. Costs/payouts provisional but specify conservative bounded formulas and worked example.
- References are evidence for original's public features, not exact current counts. All content names, formulas and targets are our proposed originals, not claims copied from original. No invented live measurements, playtest stats, permission or asset generation history.

## Sources

- S1 official Magic Survival/leme GooglePlay https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie ; retrieved2026-10-29, page updated2026-09-26, public v0.994 notes. One-hand survival with varied magic; exact latest original counts unverified.
- S2 TomkoSK builder https://github.com/TomkoSK/magic-survival-builder/tree/d58d53117e6bead22ee08f0ecac7bff9658ae922 ; combination/research/artifact planner, not combat engine, older2024-12-20 snapshot, no LICENSE verified.
- S3 local baseline commit above, core.mjs:1DURATION300,2-39catalogs, game.js:35records,273background,529pointer; DESIGN.md; tests25; assets/catalog.json266=265images+1font; assets/sources.json28used subset; atlas261content icons=153artifact58magic30passive20research, no enemy/map/player/boss sprite set.
- S4 existing shorter spec docs/superpowers/specs/2026-10-29-expansion-design.md. Retain as initial proposal, mark superseded final vision; do not discard history.

## Manuscript ownership and page mapping

- Root writes pages1-16 + rendering/editable source assembly + final integration.
- systems author owns docs/gdd/parts/02-systems.json, pages17-38 (22pages).
- worlds author owns docs/gdd/parts/03-worlds.json, pages39-66 (28pages).
- production author owns docs/gdd/parts/04-production.json, pages67-88 (22pages).
- Everyone is sharing one repo. Do not edit other parts, game code, or root brief. No commits, no subdelegation. Write only own file and report status.

## JSON page schema

Top-level {"pages":[...]}. Each page:

```json
{"id":"p017","chapter":"02 전투와 빌드","title":"구체적인 페이지 제목","strap":"핵심 결정을 짧게","status":"design","blocks":[{"kind":"p","heading":"소제목","text":"구체적 설명"},{"kind":"table","heading":"표 제목","columns":["ID","이름","규칙"],"rows":[["M01","마나 창","규칙"]]},{"kind":"list","heading":"검증","items":["조건과 기대 결과"]},{"kind":"callout","text":"결정 또는 위험"}],"sources":["S3"]}
```

Use only p/table/list/callout blocks (root may add diagrams). Paragraph text is plain text, no Markdown formatting/HTML. Tables max5columns, concise cells; split long content into explanatory paragraphs. Sources list IDs only; proposed-only pages may omit sources. Each page has unique material, concrete parameters/mechanics/counterplay/rules, not repeated boilerplate. Target~850-1300 non-whitespace characters including tables per page with3-5blocks; dense catalogs may use tables with12-18rows. Avoid huge paragraphs or table cells. No artificially blank/divider pages or repeated summary to inflate length. Tables can use a format-specific font9pt but body10-11pt.

Quality: executable design decisions, alternatives/tradeoffs, conditions/limits, failure cases, acceptance criteria. A catalog should contain real designs, not placeholder names or synonyms. Numeric values are initial hypotheses requiring simulation/playtest, not precision theater. Define terms once, reuse shared contract. Do not claim 'perfect', measured FPS or user-approved numbers. Do not include OMX agent instructions in product experience.
