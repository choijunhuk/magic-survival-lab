# Final ordinary campaign playability probe — 2026-10-31

**Final closeout evidence: six baseline campaigns terminated, 3 legitimate wins, zero runtime/invariant failures; pipeline exit 0.** All simulation inputs, catalog, test and runner remained unchanged during execution. Exact dt is **1/30 second** (30 simulation ticks per game second). No bot policy or runtime changes were made for this rerun.

The prior resource-loaded sample is retained in `playability-report.precloseout.json`, `playability-report.precloseout.md`, and `*.precloseout.log`; the older prefix replay is `playability-report.replay.precloseout.json`. This final rerun supersedes those outcomes because real artifact targeting/impact consumers changed after the initial probe. It does not certify human enjoyment, broad win rates, or every class/zone pairing.

## Final actual outcomes

| Class/zone | Seed | Outcome/reason | Game seconds | Level | Kills | Realized spells (ID:level) | Fusions | Boss |
|---|---:|---|---:|---:|---:|---|---|---|
| C01/Z01 | 731001 | won/boss-defeated | 814.93 | 55 | 6808 | bolt:5, fireball:5, frost:5, m12:3, meteor:5, vortex:4 | f07, supernova, blizzard | defeated |
| C02/Z02 | 731102 | lost/timeout | 900.00 | 17 | 5055 | fireball:4, m11:1, m16:2, m22:3, meteor:2, vortex:2 | none | seen; 493.00 HP lowest surviving observation |
| C03/Z03 | 731203 | lost/death | 730.33 | 15 | 1375 | fireball:1, frost:4, lightning:1, m17:1, m18:2, m21:1 | none | unseen |
| C04/Z04 | 731304 | won/boss-defeated | 826.37 | 55 | 6870 | bolt:5, fireball:5, lightning:5, m15:5, m22:4, orbit:4 | plasma | defeated |
| C05/Z05 | 731405 | won/boss-defeated | 824.27 | 54 | 6939 | bolt:5, fireball:5, lightning:5, m11:4, orbit:4, pulse:5 | hyperion, plasma, f06 | defeated |
| C06/Z06 | 731506 | lost/death | 457.07 | 21 | 1958 | lightning:4, m13:1, m15:4, m16:3, pulse:2, vortex:3 | f34 | unseen |

`boss_min_hp` records the lowest surviving boss HP seen after a tick. A killing tick removes the enemy, so wins can retain a positive raw observation; the terminal boss-defeated result proves death. Unseen bosses retain the 550 initializer rather than a measurement.

## Comparison with the preserved first probe

Seeds, 1/30 dt, steering, menu policy and research loadout are unchanged. Source changes altered combat, RNG consumption, offered builds and collected artifacts; these are comparable seeded outcomes, not an isolated causal experiment on one artifact fix.

| Class | Precloseout | Final | Wall seconds: prior → final |
|---|---|---|---:|
| C01 | lost/death, 573.23s, Lv30, 3371 kills | won/boss-defeated, 814.93s, Lv55, 6808 kills | 18.155 → 32.844 |
| C02 | lost/timeout, 900.00s, Lv32, 7641 kills | lost/timeout, 900.00s, Lv17, 5055 kills | 53.349 → 90.208 |
| C03 | lost/death, 408.87s, Lv8, 1106 kills | lost/death, 730.33s, Lv15, 1375 kills | 29.209 → 136.915 |
| C04 | won/boss-defeated, 821.87s, Lv59, 6948 kills | won/boss-defeated, 826.37s, Lv55, 6870 kills | 33.600 → 221.159 |
| C05 | won/boss-defeated, 826.90s, Lv49, 7071 kills | won/boss-defeated, 824.27s, Lv54, 6939 kills | 38.860 → 91.656 |
| C06 | lost/death, 448.33s, Lv23, 1840 kills | lost/death, 457.07s, Lv21, 1958 kills | 13.353 → 17.257 |

The final six runs took **590.039 wall seconds**, compared with 186.526 initially. The increased time is exposed here: final trajectories have different builds and crowding, and the host had a concurrently busy Android emulator. This is not a controlled FPS benchmark or proof of a particular performance regression. No frame skipping, time scaling, policy tuning or truncation was used to shorten the final probe.

## Method and invariants

- The unchanged `godot/tests/test_campaign_playthrough.gd` constructs ReleaseSimulation in campaign mode with each explicit seed/class/zone and **empty research**. It uses only `start`, normal `tick(1.0/30.0, movement)`, and public APIs for currently offered upgrades, artifacts, event, practice and resonance choices. It never assigns simulation state, teleports, grants HP/XP/inventory, changes enemy HP/rates/cooldowns, or calls private spawning/attack APIs.
- Steering is recomputed every three ticks (10 Hz). It scores 16 directions and stop using short-horizon enemy/projectile prediction and read-only hazard geometry, then pursues XP, chests, placed events and resonance markers. Running headlessly faster than wall time does not modify the simulation clock.
- Desired builds target six material spells and three fusion pairs. Every choice is drawn from current offers; unavailable desired offers sometimes force other materials. Realized spell/fusion counts are reported above rather than claiming every target was achieved. Eligible offered fusions, planned materials, damage/haste/health and useful existing spells are prioritized. No research rerolls are available.
- Event policy accepts ordinary low-cost offers, declines E02/E05/E07/E10, chooses E01 heal/XP according to HP, and selects an offered learned spell for E08. E12 answers its displayed hazard using the normal practice-answer API, then advances only the public practice clock while campaign time stays frozen. Resonance selections use offered IDs.
- Sparse invariants validate finite HP/coordinates/time/enemy HP, HP/spell limits, six-spell/three-fusion caps, 200-enemy/300-projectile caps, frozen campaign time in menus, accepted offered choices, bounded menu loops, and termination by the normal 900-second deadline. Ordinary deaths and timeouts are recorded data; they do not make the test claim a win or fail an invariant.

## Findings and validation limits

- C01, C04 and C05 defeated scheduled bosses B01, B04 and B05 through normal damage. C02 survived the exact 900-second deadline with 6.00 HP, reduced B02 to 493.00/550 HP and correctly lost by timeout. No infinite pause, invalid state, entity overflow, non-finite value or unavoidable-boss conclusion was produced.
- C06 grew organically from its sole M15 starting spell: at 30 seconds it had 17 kills, level 3 and 6.00 HP; it eventually reached level 21 / 1,958 kills before ordinary death. The hypothesized no-XP startup blocker remains absent in final sources.
- C03 and C06 died before boss arrival. This geometry-aware bot can sacrifice XP collection and coherent materials to avoid dense enemies; its losses do not establish human impossibility. B03/B06 ordinary-run boss victories remain unverified in this sample. All six map phenomenon start times were reached.
- This is one fixed pairing for each class/zone, not the full 36 pairing matrix or a win-rate study. Human fun, visual readability, device controls, save/reward settlement, target-device performance and all bosses' complete win balance remain outside this probe. The bot reads full runtime geometry and is not a model of human perception.
- Full first-pass damage source objects were empty because of an old logging-only key. That original evidence remains archived honestly; the existing final harness reads `lastDamageSource`, so final JSON has actual source IDs. No movement or choice policy was changed by that diagnostic correction before this final run.

## Source identity and deterministic replay

`playability-report.sourcehashes.json` records all 14 tracked input SHA-256 values before and after the complete run, exact dt, UTC timestamps and pipeline exit code. **No simulation/catalog/test/runner hash changed.** Only `godot/scripts/game.gd` changed during parallel UI work; it is not loaded by this headless simulation test. The loaded simulation inputs below were stable:

| Input | SHA-256 |
|---|---|
| `godot/scripts/simulation.gd` | `6918425de4cbc8f42c9cba3efb58c028296ccfc0621aea2189f88f3aaa7036c8` |
| `godot/scripts/release_simulation.gd` | `72888b7d4070497b9d18305e58b31648cb0d4d3a340c832915e11ce6daca488d` |
| `godot/scripts/release_combat.gd` | `d78d5c38f7293a1a053b7e67375c57a0136c9dd40bff99455321657e1edbe6a4` |
| `godot/scripts/release_encounters.gd` | `4509aab8685f4bdb1dbb251d9572e15d7093ddc9783676135965a3ca8aa241a0` |
| `godot/scripts/release_events.gd` | `e9e596503929ad9f2daaf928155094c69410c8b07c1847a89fa05eb1b5ed677f` |
| `godot/scripts/artifact_rules.gd` | `3fa20a2470a8cce308728a52926d5ea7639b80f78d0552c9716a73f68c81d72d` |
| `godot/data/release_content.json` | `475068aa7b0004e3f8bd2a31704a3a7218515afd9e39379f0a9426f48156397a` |
| `godot/tests/test_campaign_playthrough.gd` | `d3762ac18fad42f27231352277cf2607a9673503236a16193862e81263829e9e` |

The final C01 deterministic prefix replay repeated seed 731001 for 900 frames / 30 seconds with identical time, HP 6, level 3, 27 kills, 2 enemies and no boss. Replay exit 0 and zero invariant failures are retained in `playability-report.replay.json` and `playability-replay.log`. This cheap prefix check is not a full-campaign deterministic replay.

## Reproduction

```sh
python3 .omx/release-implementation/playability-report.py
```

The unchanged Python runner streams `playability-probe.log`, rejects engine `SCRIPT ERROR:` / `ERROR:` even when Godot exits zero, and requires the exact six-run completion marker. A direct prefix replay against the saved report is:

```sh
godot --headless --path godot --script res://tests/test_campaign_playthrough.gd -- --replay-prefix
```

Godot 4.7 stable was used. Complete decisions, timestamps, API acceptance, final builds, damage source IDs, 30-second snapshots and outcomes are in `playability-report.json`. No runtime, catalog, UI or save files were edited by this probe; no commits or delegation were performed.
