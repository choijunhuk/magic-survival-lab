# Campaign simulation implementation

Owner: campaign_core_sol. No commits performed; no changes to legacy content.json, records/profile, artifact_rules.gd or UI ownership.

## Files and architecture

- `godot/scripts/simulation.gd`: mechanical extraction of the eight agreed stage seams. Original statements, RNG order and same-frame terminal priority retained; fresh legacy suite52/52 passes.
- `godot/scripts/release_simulation.gd`: release state, class/research modifiers, validated upgrade/artifact selection, damage/status/defense event boundary, capped healing, artifact primitives. Inherits tick ordering; no post-super.tick damage pass.
- `godot/scripts/release_combat.gd`:24 real spell dispatches,36 fusion hooks,12 resonance branches, projectiles, area geometry, status clocks, independent source/depth event provenance.
- `godot/scripts/release_encounters.gd`:12×2 normal variants,18 elite variants/windows,6 map phenomena,6 boss pattern families and HP phases, shape-based hazard collision.
- `godot/scripts/release_events.gd`:12 distinct event choices and costs/tasks, world-marker approach gate, atomic choice/decline, E12 warning identification practice and one-use resonance.
- Dedicated tests: `test_release_simulation.gd`, `test_release_combat.gd`, `test_release_encounters.gd`, `test_release_review_regressions.gd` (26/26 review regressions).

## Content mechanics

Artifact choice rarity uses70/25/5 weighted tier selection and same-ID exclusion. All24 spell entries have executable mechanics; no free bolt for C02-C06. C06's M15 ordinary-enemy weak periodic damage is the leader-approved clarification. M14 uses12 safe seconds (8 in F28 glyph); M20 rotates real hostile projectile velocity and excludes beams; M23 delays an existing warned cast once and never bosses; M24 intercepts fatal damage before A091 and grants retreat/recharge.

F01-F36 all have explicit transformation paths; targeted fixtures exercise every fusion and all12 F01-F04 resonance branches. Secondary damage is depth1; overlapping vortex fields retain a per-target shared tick gate. DOT refresh retains its existing next-tick clock. Aggregate haste is capped+80%, cast intervals at0.4s, total movement at220×1.6, total XP at1.75 and all healing at5%maxHP/sec. A081 uses precalculatedDamage for exact40% final damage without a second modifier pass. MaterialLv3 is revalidated on choose and retained, spellLv5/6 learned spells/3 fusions are checked on offer and choose.

Normals use the actual12 GDD families (walk/dash/shield/shoot/split/swarm/lure/support/delay/barrier/absorb/stealth), two behavior variants each. Elites use X01-X18 special behaviors, four160/320/490/660s windows, max1 scheduled active and max8 summoned minions. Boss entry retires elites without chest reward; overall200 enemy,300 friendly/300 hostile projectile,60 field/hazard,100visual-effect pressure target with essential-signal overflow protection and100 delayed-effect budgets.

Maps use delayed position rifts, rotating safe-angle ring, growing toxic patches/1.5s stone cleanse/20s recharge,45unit/s nondamaging current, once-reflected grid rays/panels, and numbered moving waves with a central safe gap. Bosses own separate reservations; map hazards pause/suppress during boss sequences. B01 circle/radial sequence; B02 lens/rings and staggered lens pair; B03 fixed root/branches/spores/stone lock/weak recovery; B04 stream reversal/dash and sequential double reversals; B05 single reflection and full rewarning after panel recalculation; B06 staggered3 waves/extra opposite wave/central line. Warning/active/geometry data is shared with rendering.

Research gameplay effects R01/R04/R05/R09/R10/R11/R12/R15/R20 and previews R02/R06/R08 are consumed in simulation. Remaining informational research produces explicit `researchHints` values for the UI; these do not remove default costs/rewards/safe routes/contrast from unresearched runs.

## API contracts for integration

`ReleaseSimulation.new(seed=1,mode='campaign',options={zoneId,classId,research,runId})`; `reset(mode,seed,options)`; state/catalog/start/tick/choose_upgrade/choose_artifact/toggle_pause/orbit_position match legacy. `mode='practice'` is unlimited/no rewards with boss at2s; `mode='seededchallenge'` has fixed seed/rulesVersion and explicit challenge/rewardEligible flags, separate from campaign reward settlement.

- `choose_event(option='accept')`, `decline_event()`. `state.events` are world markers{id,x,y,status}; `activeEvent` full card+marker; `eventChoices` [{id,name,enabled?}]. E01 accepts heal/xp, E08 accepts an owned non-max spell ID. R15 replaces chosen card with confirm/decline before cost mutation.
- E12 phase`event_practice`: call `tick_practice(dt)`, present `practiceHazards` and `practiceAnswers`; `choose_practice_answer(shape)` returns correctness, updates `practiceFeedback/practiceCorrect`.15s practice clock runs separately; combat time is frozen.
- `choose_resonance(id)`, `decline_resonance()`. Multiple supported fusions first produce target cards, then3 branch cards. `resonanceMarker`, `resonanceTarget`, `resonanceChoices`, `resonances`. Any branch/decline consumes the single opportunity.
- `reroll_upgrade(index)`, `reroll_artifact(index)` for R01/R20, `reroll_artifact_upgrade()` for A072 same-tier cards.
- `presentation_modifiers()` returns veilOutline/chestMarkerRange/eventMarkerRange/eventAdvance for artifact presentation.
- `researchHints`: compareFrequency,codexClues,fusionHint,chestDirection,confirmEvents,xpDirection,detailedDeath,phenomenonMeter,materialFilter,eventRewardCategory,eventDirection,resultConnections,finalSummary, firstPhenomenonPreview,bossFirstDirection,elitePreview and runtime preview coordinates/times.

Artifact partner primitives implemented exact agreed signatures: `apply_damage(target,amount,context)`, `apply_status(target,tag,duration,strength)`, `heal(amount,sourceId)`, `spawn_seed(position,extra)`, `pull_gems(radius)` (0 means visible420 range), `spawn_heal_field(position,duration)`, `absorb_projectiles(center,radius,limit)`, `delay_enemy_cast(targetId,seconds)`, `cancel_enemy_dash(targetId)`, `extend_status(targetId,tag,seconds,maxDuration)`, `damage_radius(center,radius,amount,context)`, `schedule_artifact_effect(delay,kind,data)`; `_nearest/_enemy_index/_pos/_effect/state/catalog/rng` retained.

All events carry kind/type/time/depth/zoneId plus source/attack/target IDs where meaningful. Hit context carries status flags/targetPosition/firstHit/firstTarget/chain/center/meteor/explosion geometry, derived depth guard. Control handles seed spawn/heal/execute/dodge/deflect/cast-delay/slow expiry/dash-in-glyph/ground exit. Artifact balance quantities not specified in GDD are exposed as artifactEffectDamage/artifactEffectRadius/fragmentPositions/secondaryPositions/lineTargetIds;100D is1runtime damage.

## Renderer additions

`state.fields` kind: meteor_warning,ash_warning,well_warning,well,vortex,electric_ring,glyph,veil,mine,wall,pulse,burn,ash,heal. Common{id,x,y,radius,life,maxLife,sourceId}; wall has direction/width; pulse currentRadius. `state.seeds` x/y/life/value; `state.marks` targetId/delay. `enemyProjectiles` x/y/vx/vy/radius/life/ownerId/deflected/beam; `mapPanels` x/y/life.

Hazards `{owner:map|boss|enemy,shape:circle|ray|ring|wave,kind:shape,x,y,radius,warning,maxWarning,active,maxActive,angle,length,width,innerRadius,safeGap:{angle,width},vx,vy}`. Ring safeGap width is radians; wave safeGap width is world units. Flow waves are nondamaging and carry flow/flowX/flowY. `effects` adds artifact_warning/enemy_dash_warning/enemy_cast_warning/reappear_warning/mark.

## Evidence and limits

Fresh targeted results before final integration: legacy52/52; release simulation194/194; fusion/resonance combat55/55; artifact integration71/71 + standalone artifact rules37/37. Encounter behavioral/replay suite35/35 passes, including two real60s input-driven fixed-seed runs producing identical time/kills/level/HP/RNG state. Catalog468/468 passes. Tests are headless mechanics evidence, not real-device balance/readability acceptance. Numeric new-content damage/radii are explicit initial balance hypotheses;100D=1 preserves existing core scale. Human no-research clears across all6 maps, phone input/thermal/load and warning readability remain manual acceptance work owned by root. This report does not convert those gaps to PASS.

A057 geometry note: all six GDD launch maps explicitly have no blocking physical walls; M18 is permeable and enemy projections are damage telegraphs. Pull-gems therefore checks the actual visible420-unit range; no blocked-wall traversal exists in the current map geometry.

## Independent-review corrections (second checkpoint)

Root approved campaign-only M07 target selection: highest current HP in the existing search range; F29's explicit vulnerable priority remains its transformation. Legacy nearest-target meteor is unchanged. `targetingPolicy/targetPolicy='highest_hp'` plus `priorityTargetId` identifies only the actual prioritized first hit for A074. A074 collateral/DOT/repeat do not inherit the flag.

A088 now gets centralized first-target provenance per attack. A056 counts successful penetrations starting at0, not allowed capacity. A043 expands sword contact radius, preserving the orbit path. A093 has actual short central diameter segments with per-line target collision and per-line1s artifact cooldown. A069 execution control emits after a real eligible dagger kill, and A083 identifies the actual last successful chain hit even if the chain ends early. A039 vulnerability is capped4s after bonuses. Ground occupancy transitions are tracked every update independently from damage ticks, so A060 handles brief exits.

Elite previews reserve the same randomized spawn plan with or without research/artifacts. A player entering that reserved position triggers replanning plus a complete replacement warning instead of spawning on top of the player. E04/E10 provide pre-spawn forecast position/order; player-relative forecasts update until ordinary warning locks its coordinates, explicitly `locked:false` while predictive. This preserves Z01's0.6-second historical targeting. Boss slow affects actual locomotion (boss resistance) and B02 lens sweep (maximum20%); X16 no longer clamps delayed casts above zero. Shield enemies turn at1.2rad/s and compare the actual incoming attack origin to their facing, enabling flanking.

A081 receives unique `explosionId` per explosion, preserving `attackId` cause; exact40% secondary damage bypasses a second modifier pass. A027 affects actual explosion radius at cast, while A035 only enlarges warning display: meteor fields now carry `damageRadius` separate from `radius`.

Research-facing public APIs: `cast_interval(spellId)` and `upgrade_frequency(id)` share the actual `Combat.interval` calculation without consuming RNG or attack IDs. `researchHints.bossFirstPreview` contains actual first pattern origin/target/angle/safeAngle. `deathDetail` carries sourceId/attackId/kind/damage/time/targetKind/waveNumber/patternId/phenomenonId/hazardId/ownerId. `eventOutcomes` records actual choice/reward/condition/acceptedAt/completedAt/HP/XP before/after; only `completed:true` is result evidence. UI owner received these contracts directly.

## Artifact consumer closeout (third checkpoint)

Root resumed a bounded seven-item consumer wave after matrix audit. Source fixes are now applied and targeted tests pass113/113 artifact integration plus56/56 combat and26/26 review regressions (artifact owner also reports92/92 standalone rules):

- A017 projectile speed changes lifetime inversely, preserving source range; last travel step is clamped to remaining lifetime.
- A020 cold needle contact radius and cold wall width consume the cold radius multiplier; A045 wall length remains separate.
- A038 `shock_bonus_mult` scales only the shock increment (normal20%, boss10%), rather than the base hit.
- A067/A081/A090 listen to one explicit `explosion` event per actual impact, even without an original target. Payload has preserved attackId/new explosionId, exact center, full secondary geometry, raw artifactEffectDamage and originalDamage (first actual hit if present, otherwise source-modified pre-target amount). A081 stays40% and depth1/noIgnite; delayed meteor children retain warning and no recursion.
- A087 glyph dash detection runs every field update with the actual current/previous enemy segment and dashingThisStep flag, independently from the0.5s damage tick. Existing glyphs intercept the proposed dash segment in the enemy stage before contact damage, so a short dash cannot deal its contact damage before cancellation.

These are targeted headless consumer regressions, including empty meteor impact, zero-primary-target secondary explosion, short glyph dash and range preservation. The leader owns the next combined run and final release acceptance.

Final artifact timing correction: A024 had shortened vortex field scheduling to0.45s while the overlap-deduplication gate remained0.5s, causing alternate ticks to be rejected. Both now share the same computed interval with a comparison epsilon. A focused two-overlapping-field regression proves2 total hits at0.0/0.45s rather than duplicate hits or a0.9s delay. Latest targeted combat56/56 and artifact integration113/113 pass. Artifact owner reports no remaining confirmed dead consumer; A041 final visual evidence belongs to the UI owner. Core edits are stable at this checkpoint.

## Cosmetic pressure bound (fourth checkpoint)

Independent tick profiling measured311 simultaneous effects in the controlled200-enemy advanced fixture. GDD p076 describes100 simultaneous visual effects as an initial pressure-scene target, not permission to discard gameplay or danger signals. Release-only `_effect` now evicts oldest explicitly cosmetic resolved-hit decorations first (hit/death/heal/explosion/bolt/fireball/frost/lightning/beam/vortex), aiming at100 total active effects. Warning types, mark, sword_line, pulse and unknown future types are protected. If essential signals alone exceed100, they may overflow; new cosmetics are dropped. Legacy Simulation._effect and gameplay pulse behavior are unchanged.

`test_release_effect_budget.gd` passes17/17:2000-emission stress bound, all protected payloads preserved,120-warning-only overflow retained, and a real200-enemy advanced3-second tick sequence compared against an unbounded visual reference. Effects peak212→100; every other gameplay-state field, RNG state and death/deadline/boss terminal outcome remains exactly equal. Legacy52/52 also passes. These establish presentation-only behavior; no six-bot replay was rerun for this cosmetic-only checkpoint. The independent profiler owns the single identical-fixture before/after timing comparison; timing gains are not assumed from effect-count reduction and this does not prove device60FPS.

Independent identical-fixture after measurement is now available in `tick-profile.before.json/.log` and `tick-profile.after.json/.log`: advanced effects peak311→100; tick mean5.066176→5.066173ms (effectively unchanged), P958.566→8.726ms, max39.799→39.324ms. Start-kit effects102→100; mean3.615553→3.523497ms, P955.013→5.140ms. Both runs report zero fixture failures and matching nonvisual final counts/time/phase. This confirms predictable cosmetic pressure, not a latency improvement or60FPS.
