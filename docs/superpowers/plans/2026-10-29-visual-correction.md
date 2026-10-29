# Magic Survival visual correction implementation plan

Goal: replace the rejected visual direction across menu, combat HUD, actors, terrain, FX, choices, pause/results and the live game with the explicitly requested original reference language.

Spec: docs/visual/magic-survival-reference.md; godot/DESIGN.md correction authority.

1. Capture/save official combat, upgrade and menu references; record current mismatch before code changes. Preserve functional baseline.
2. Produce actual transparent player/enemy/boss sprites and terrain/forest bitmap assets from reference with imagegen; validate alpha and save provenance.
3. Rewrite HUD presentation with distressed heading font, compact battle chrome and black rough cards; preserve setup/refresh/game callback APIs and all real state.
4. Replace world primitive actors/space-grid with sprite rendering and neutral world texture; enrich spell visuals while preserving collision/simulation. Allow unhandled touch anywhere; test the changed input boundary.
5. Use excluded capture fixtures to render equivalent menu/combat/upgrade states without fake persistent records. Compare originals directly, iterate and retain strict visual verdicts.
6. Run native/reference suites, fresh Android/Web exports, actual browser and emulator interactions, review regressions, commit/push and verify Pages updates to the new build.

Done means the original references and actual new captures visibly align, not merely that code compiles. Native first-build scope remains8/4/12; full GDD content and physical-device balance are separate.
