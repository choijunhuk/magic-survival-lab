# Independent campaign core review — 2026-10-31

## Final cosmetic-budget delta — approved

**APPROVE the release-only cosmetic effect budget change.** Independent source inspection confirms the eviction allowlist contains only resolved-hit decorations (`hit`, `death`, `heal`, `explosion`, `bolt`, `fireball`, `frost`, `lightning`, `beam`, `vortex`). `_oldest_cosmetic_effect()` selects the earliest eligible array entry; removal does not reorder retained essential entries. Pulse, danger warnings, mark, sword_line, meteor and unknown future types are not eligible. Essential-only overflow remains allowed, and new cosmetics are rejected when no cosmetic can be evicted. The base legacy `_effect` remains unchanged. Runtime gameplay collections (fields/hazards/projectiles/pendingEffects) are not trimmed by this override.

Fresh independent focused execution: `godot --headless --path godot --script res://tests/test_release_effect_budget.gd` — **17/17, zero failures**, FX peak212→100. The test's comparison erases only `effects` from a deep state copy, compares every remaining gameplay field, separately compares RNG, and checks a fatal/deadline/boss same-frame terminal case. Protected-type tests retain payloads under2000 cosmetic emissions and preserve120 essential warnings above the target. Essential relative order is justified by the inspected stable array removal, rather than claimed as a separate explicit test assertion. The three-second200-enemy fixture is a controlled regression bound, not exhaustive gameplay or device coverage.

No CPU/FPS improvement is claimed. Root's identical-fixture profiling reports peak311→100 but essentially unchanged mean5.066ms; this approval concerns deterministic cosmetic pressure and preserved gameplay semantics only. No source edits made. Prior core/consumer findings remain closed.

## Final scoped approval

**APPROVE the reviewed core and late consumer delta. No open finding remains from this review.** A087's last P2 is closed: `artifact_rules.gd:237` now requires `targetKind == "normal"`. The added natural glyph-update case sets `enemy.kind = "elite"`, starts a0.1s dash between glyph damage ticks, updates fields, and asserts dashTime remains0.1; the adjacent existing normal case asserts cancellation. The per-target10s gate and boss exclusion remain intact.

This final micro-check was source/test inspection only, per root's request not to repeat suites. Latest92/92 unit and113/113 integration results were reported by the artifact owner, not independently rerun in this micro-check. Independently executed earlier evidence remains25/25 review,55/55 combat,89/89 artifact rules and79/79 artifact integration at their respective checkpoints. The original eight findings stay closed. Historical sections below retain the earlier findings and are superseded by this approval. Approval remains bounded to these reviewed mechanics; manual/device/visual/balance acceptance belongs to root.

## Late artifact consumer delta — bounded follow-up

**One remaining P2 condition mismatch: A087 currently cancels elite dashes as well as normal enemies.** `godot/scripts/artifact_rules.gd:237` checks `targetKind != "boss"`; the GDD and artifact matrix specify ordinary/normal enemies (`일반 적`). The newly connected encounter consumer passes actual `item.kind`, so X02/X10 elite dashes can now be canceled too. Change the eligibility guard to `targetKind == "normal"` and add a matching elite-negative assertion. Existing integration coverage only uses a normal target. This is in the specifically requested A087 consumer path; the original eight findings remain closed.

Other late changes **approved within inspected scope**:

- A017 multiplies velocity and inversely scales lifetime; projectile movement clamps its last step to remaining lifetime, preserving source range.
- A020 feeds cold needle contact radius and wall width, preserving wall length and slow strength.
- A038 multiplies only the20% normal/10% boss shock-consumption bonus; normal10 damage becomes12.2, not13.2.
- A067/A090 now consume one explosion/impact event even with zero primary hits, scheduling one aftershock and three fragments at0.5s with depth1 provenance and warnings.
- A081 consumes that explosion event once per explosion ID; secondary regions can hit outside the original radius. Forty-percent scaling uses a precalculated path, with no second damage-modifier pass or ignition application.
- A087's short-dash timing is repaired: existing glyphs inspect swept dash movement before enemy contact; the field stage also observes short dashes between damage ticks. Its target-kind condition above remains incorrect.
- A014 counts nonboss kills before the depth guard, while derived events still return before direct secondary-damage handlers. Thirty-kill capped healing remains present.

Fresh existing focused suites: **89/89 artifact rules**, **79/79 artifact integration**, zero failures, exit0. These prove the selected checked behaviors, not exhaustive96-item combinations or manual acceptance. A014's derived-kill counting assertion is an isolated stub check, not an end-to-end multi-artifact healing-chain test; A017 range is analytically checked from speed×lifetime and the final-step clamp was inspected. No claim of complete balance/device/visual coverage is added. No runtime edits performed.

## Fix-wave re-review — current verdict

**All eight original findings addressed in the scoped re-review. No remaining blocker found in these repaired paths.** The earlier checkpoint below is retained as history and is superseded by this section. This is scoped runtime acceptance, not full-GDD, visual, balance, device, or release approval.

Fresh native Godot4.7 evidence: review regressions **25/25**, artifact integration **71/71**, release combat **55/55**, all exit0 and zero failures. The independent measurement harness was rerun, extended only to verify actual A069 execution/next-cast consumption and the A043 contact edge.

| Original issue | Status | Actual evidence |
|---|---|---|
| X16 permanent silence | Addressed | 600 updates at60Hz: delayed=false, warning completed, three hazards emitted. Clamp removed. |
| A056 prior penetration count | Addressed | First/second C01 bolt damage9.0/10.08; per-projectile completed penetration counter consumed at collision. |
| A093 connecting-line geometry | Addressed | Center-only target at(35,0) takes0.3; actual short diameter segments use geometric collision and stable line IDs. |
| R08/A032 wrong elite position | Addressed | Preview and spawn both(-266.50,158.35), discrepancy0. R08/A032 and player-overlap replan covered by the25-check suite. |
| E04/E10 no advance information | Addressed | Before first hazard at74s: position(-90,-20), next index0; suite verifies both event choices and two future order entries before hazards exist. |
| Boss slow no consumer | Addressed | B01 move5.5→4.8125 for strength0.25; B02 actual rotation is reduced within its20% cap in the regression suite. |
| A069 consumed before hit | Addressed | Cast alone grants nothing; actual execute removes target and grants token; next dagger can select target650 units away, launches, and consumes token. |
| N05/N06 facing/origin | Addressed | Opposite-side N05 damage4.95/9.0;25-check suite also verifies N06 reverse protection and1.2rad/sec bounded turn. Context carries attack origin. |

Early findings remain addressed: natural A088 bolt creates mark3.0; combat suite verifies one first target for a multi-target pulse. A043 preserves orbit72, misses a target27.5 units from blade without artifact, and hits for2.0 with artifact. A027/A035 cast/explosion versus warning radius regressions pass. A074 approved campaign M07 highest-current-HP target selection and explicit primary-target damage context are covered in the71-check artifact suite; legacy targeting is outside the changed release helper. The25-check suite additionally verifies pure shared R03 cooldown queries, R06 actual direction data, and R17 cause identity without requiring a broader UI review.

Forecast detail: E04/R02 are explicitly dynamic player-relative forecasts (`locked:false`) until ordinary warnings lock their positions, not fixed future colliders. The preview helper shares anchor/garden-offset generation with execution. This resolves absent runtime information; displaying/understanding that forecast remains root's UI/manual acceptance responsibility.

No new regression was found in the reviewed fix code. No runtime/catalog/UI file was edited by this reviewer; only the authorized scratch harness and this report changed. Tests are focused mechanics evidence and do not certify every96 artifact, human six-map clears, visuals, or device performance.

## Earlier checkpoint — superseded

Verdict: **CHANGES REQUIRED at review snapshot**. Real implementations exist for the 24 spell / 36 fusion dispatches, six zone/boss families, classes, event choices and resonance branches; counts do not establish the advertised behavior. Targeted Godot execution confirmed eight remaining mechanics defects below. Authors are actively fixing these; this is a reproducible checkpoint, not a claim about a later snapshot.

Reviewed: `simulation.gd` stage extraction, `release_simulation.gd`, `release_combat.gd`, `release_encounters.gd`, `release_events.gd`, `artifact_rules.gd`, associated tests, release plan, implementation reports, and named GDD contracts. No runtime/catalog/UI files changed by reviewer.

## Findings

1. **P1 — X16 can be permanently silenced by one cast delay.** `godot/scripts/release_encounters.gd:185` restores `castWarning` to at least 0.05 every frame while `castDelayed` remains true. `advance_cast` only clears that flag after warning reaches zero. At the normal 1/60 step, warning reaches 0.05, decrements to 0.0333, then is restored forever. Repro: delayed X16 with warning 0.1; 600 enemy updates leave warning=0.05, delayed=true, hazards=0. Make the special warning extension one-shot; test completion of the delayed attack at 60 Hz.

2. **P2 — A056 boosts the first hit and never tracks successful penetrations.** `godot/scripts/release_combat.gd:41` copies initial pierce capacity to `context.projectilePierces`; `:291`–`:297` decrement the projectile's capacity without updating this context. `release_simulation.gd:297` treats it as prior pierces. Repro: C01 bolt, base damage10, pierce1, A056: first and second targets each lose10.08; expected9 on first,10.08 on second. Track completed penetrations and cap at three; include a multi-target natural projectile test.

3. **P2 — A093 has no central connecting-line geometry.** `godot/scripts/release_combat.gd:340` collects only enemies already touched by blades; `:355` publishes those as `lineTargetIds`. The artifact then adds damage to blade contacts, while enemies on the advertised central line are untouched. Repro: four swords, A093, stationary target at(35,0), first sword at(72,0): damage0. Query actual connecting segment(s), using stable per-line/target one-second gates; test center-only target separately from blade contact.

4. **P2 — R08/A032 elite preview does not reserve the actual spawn position.** `godot/scripts/release_encounters.gd:54` publishes player+(300,0), but `:63` rolls a new random angle at spawn. Repro seed42: preview(300,0), actual(-266.50,158.35), discrepancy588.22 units. Player movement also drifts the placeholder. Reserve a safe world position once when the preview begins and reuse it for spawn; preserve early warnings and skipped-window semantics.

5. **P2 — E04/E10 spend their benefits without advance information.** `godot/scripts/release_encounters.gd:381`–`:382` writes position/order only after the phenomenon has already been constructed at `:348`–`:378`. E04 promises the next three positions in advance; E10 promises two future orders. Repro: reveal counters3/2 at time74 before Z01's first phenomenon75: both preview values absent. Reserve upcoming phenomenon parameters and expose them before execution, then consume the exact reserved parameters. Do not merely publish current hazard positions after spawning.

6. **P2 — Boss slow effects are stored but never consumed.** `godot/scripts/release_encounters.gd:214`–`:222` uses fixed movement speeds and dash speed without status; `:420` uses fixed B02 rotation speed. GDD status contract specifies half slow efficiency and B02 specifies a capped rotation reduction. Repro B01 at x270: 0.1-second movement5.5 with and without a strength0.25 slow. Implement the documented per-boss resistance; verify actual displacement/rotation, not only the stored slow status.

7. **P2 — A069 execute range token is consumed by the same cast before the dagger lands.** `godot/scripts/release_combat.gd:120` emits `daggerExecute` during targeting, before projectile contact. `artifact_rules.gd:244` sets the token, then `:253` clears it on that same cast's event. Repro: targetHP5/100, M13Lv1, A069; immediately after cast token=false and target stillHP5. Emit execute only on successful hit/kill, and consume an already-existing token when selecting the next dagger target. Missed/failing execute attempts must not grant it.

8. **P2 — N05/N06 directional protection cannot express its promised flank weakness.** `godot/scripts/release_encounters.gd:78` instantly turns enemy facing toward the player every update; `godot/scripts/release_simulation.gd:321` computes attack side using that same current player vector. Thus front dot product stays1: N05 always front-protected and N06 never back-protected, including projectiles originating elsewhere. Repro N05, attacks from player x0 then x200 around enemy x100, with an enemy update each time: both deal4.95 (C01 unarmored baseline9). Establish meaningful facing/turn behavior and use actual incoming attack origin/direction for collision-side resistance.

## Fixed during the review

- A088 initially had no arcane `firstTarget` producer. Current natural bolt repro now produces mark duration3.0 after the owner added attack/target tracking. Initial blocker withdrawn; downstream mark-consumption behavior was not exhaustively retested.
- A043 initially multiplied orbit path radius while leaving blade contact radius fixed. Current orbit72 before/after acquisition confirms the unintended path change is gone. Contact-edge regression belongs in the author's fix verification.
- A027 and A035 geometry corrections plus focused assertions landed during review. Earlier A027 missing-consumer observation withdrawn; this reviewer did not rerun the whole combat suite.
- A074 highest-current-HP M07 target policy was resolved explicitly by root. The old hp>=80% inference should be replaced by actual policy provenance and verified by owner; not counted as a separate unresolved interpretation here.

## Validation evidence and limits

Command executed successfully with native Godot4.7:

`godot --headless --path godot --script /Users/choi/Documents/magic-survival-lab-release/.omx/release-implementation/core-review-repros.gd`

The harness emits measurements rather than asserting current bugs as desired behavior. Its projectile helper uses direct combat-stage calls; X16 is sampled at real60Hz. It does not prove every content item or natural end-to-end event path. Broad unchanged suites were not rerun merely to repeat reported counts.

Lifecycle audit found inherited phase gating freezes combat stages outside playing, delayed artifact damage is inside pre-terminal stages, release terminal resolution clears pending effects/hazards/projectiles, and legacy death>deadline>boss ordering remains visible. These are inspected contracts, not a fresh full regression PASS. No free starting bolt was found in the release reset/attack guard. Existing content caps are explicit for enemies/projectiles/fields/hazards/marks/seeds; artifact per-target/proc dictionaries retain historical keys and remain a profiling concern rather than an unmeasured performance-failure claim.

Manual six-map no-research balance, touch/device performance, warning readability, visuals, and rendering consumption of informational research are outside this bounded runtime review. One ordinary C04/Z04 win does not prove all maps/classes viable, and other losses do not prove impossibility. Final release approval requires owner fixes plus focused regressions and root's acceptance gates; no blanket96-artifact/full-GDD PASS is warranted by the reviewed tests.
