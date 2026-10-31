extends SceneTree
const Sim = preload("res://scripts/release_simulation.gd")
const E = preload("res://scripts/release_encounters.gd")
const C = preload("res://scripts/release_combat.gd")
const Events = preload("res://scripts/release_events.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func fresh(research: Array = [], zone: String = "Z01"):
	var sim := Sim.new(327, "campaign", {"research": research, "zoneId": zone, "runId": "review"})
	sim.start(); sim.state.spawnTimer = 9999; sim.state.eliteTimer = 9999
	for id in sim.state.spells: sim.state.spells[id] = 0
	return sim
func open_event(sim, id: String) -> void:
	sim.state.events = [{"id": id, "x": 0.0, "y": 0.0, "status": "placed"}]
	Events.offer_nearby(sim)
func _initialize() -> void:
	for research_or_artifact in ["R08", "a032"]:
		var sim = fresh(["R08"] if research_or_artifact == "R08" else [])
		if research_or_artifact == "a032": sim.state.artifacts = ["a032"]
		sim.state.eliteTimer = 0.9; E.advance_spawns(sim, 0.01)
		check(sim.state.researchHints.has("elitePreviewPosition"), research_or_artifact + " actual reserved preview exists")
		var preview: Vector2 = sim.state.researchHints.elitePreviewPosition
		sim.state.eliteTimer = 0; E.advance_spawns(sim, 0.01)
		var elite: Dictionary = sim.state.enemies.filter(func(e): return e.kind == "elite")[0]
		check(preview.distance_to(sim._pos(elite)) < 0.001 and preview.distance_to(Vector2(300, 0)) > 1, research_or_artifact + " preview exactly equals actual randomized spawn")
	var sim = fresh(["R08"]); var plain = fresh()
	sim.state.eliteTimer = 1; plain.state.eliteTimer = 1; E.advance_spawns(sim, 0.01); E.advance_spawns(plain, 0.01)
	check(sim.state.eliteSpawnPlan == plain.state.eliteSpawnPlan and sim.rng.state == plain.rng.state, "preview research never rerolls encounter RNG")
	# Player moving onto a reserved spawn gets a full replacement warning and no body overlap.
	var original: Vector2 = sim.state.eliteSpawnPlan.position; sim.state.player.x = original.x; sim.state.player.y = original.y; sim.state.eliteTimer = 0; E.advance_spawns(sim, 0.01)
	check(sim.state.enemies.is_empty() and sim.state.eliteTimer >= 0.8 and sim.state.eliteSpawnPlan.position != original, "unsafe reserved spawn replans with full warning")
	for id in ["E04", "E10"]:
		sim = fresh(); sim.state.time = 74; sim.state.xp = 4; open_event(sim, id)
		check(sim.choose_event(), id + " valid choice")
		check(sim.state.hazards.is_empty() and sim.state.researchHints.has("nextPhenomenon"), id + " forecast is available before first hazard")
		if id == "E04": check(sim.state.researchHints.has("phenomenonPosition"), "E04 pre-spawn positions, not only past hazards")
		else: check(sim.state.researchHints.phenomenonOrder.size() == 2, "E10 shows two future entries before first hazard")
	sim = fresh(["R02"]); sim.state.time = 70; E.advance_phenomenon(sim, 0.01)
	check(sim.state.researchHints.nextPhenomenon.time == 75 and sim.state.researchHints.nextPhenomenon.has("position") and sim.state.hazards.is_empty(), "R02 first forecast five seconds ahead is nondamaging")
	# Slow affects boss locomotion without freezing warning clocks or B02 lenses.
	sim = fresh([], "Z02"); E.spawn_boss(sim); var boss: Dictionary = sim.state.enemies[0]; var original_x: float = boss.x
	E.move_boss(sim, boss, 0.1); var ordinary_step: float = original_x - boss.x; boss.x = original_x
	sim.apply_status(boss, "slow", 2, 0.25); E.move_boss(sim, boss, 0.1)
	check(original_x - boss.x < ordinary_step and original_x - boss.x > 0, "boss slow affects actual movement with resistance")
	var h := E.hazard(sim, "boss", "ray", Vector2.ZERO, 10, 1, 0.4, {"angle": 0.0, "length": 100, "width": 10, "rotationSpeed": 1.0}); h.warning = 0
	E.update_hazards(sim, 0.1)
	check(h.angle < 0.1 and h.angle >= 0.08, "B02 slow changes lens sweep within20percent cap")
	sim = fresh(); var elite := E.enemy(sim, 1, 16, Vector2(250, 0)); elite.speed = 0; elite.castWarning = 0.5; sim.delay_enemy_cast(elite.id, 1)
	for i in range(180): E.advance_enemies(sim, 1.0 / 60.0)
	check(not elite.castDelayed and sim.state.hazards.size() > 0, "X16 delayed cast eventually resolves, no permanent0.05s clamp")
	# Incoming origin and bounded facing provide an actual flanking window.
	sim = fresh(); var shield := E.enemy(sim, 5, 0, Vector2(150, 0)); shield.hp = 100; shield.maxHp = 100; shield.speed = 0; shield.facing = Vector2.LEFT
	var front: float = sim.apply_damage(shield, 10, sim.context("pulse").merged({"origin": Vector2.ZERO}, true))
	var rear: float = sim.apply_damage(shield, 10, sim.context("pulse").merged({"origin": Vector2(300, 0)}, true))
	check(is_equal_approx(front, 5.5) and is_equal_approx(rear, 10), "N05 distinguishes incoming front/back attack origin")
	sim.state.player.x = 300; E.advance_enemies(sim, 0.05)
	check(absf(wrapf(shield.facing.angle() - PI, -PI, PI)) <= 1.2 * 0.05 + 0.001, "shield turns at bounded1.2rad/sec instead of instantly facing player")
	shield.variant = 6
	var reverse_front: float = sim.apply_damage(shield, 10, sim.context("pulse").merged({"origin": Vector2.ZERO}, true))
	var reverse_rear: float = sim.apply_damage(shield, 10, sim.context("pulse").merged({"origin": Vector2(300, 0)}, true))
	check(reverse_front > reverse_rear, "N06 reverse shield exposes front and reduces rear")
	# Research explanation APIs are pure, matching the actual runtime calculation.
	sim = fresh(["R03", "R06", "R17"], "Z01"); sim.state.spells.meteor = 3; sim.state.artifacts = ["blackcat"]; var attack_before: int = sim.state.nextAttackId; var rng_before: int = sim.rng.state
	var expected: float = sim.cast_interval("meteor"); C.cooldown(sim, "meteor", 6, 2)
	check(is_equal_approx(expected, sim.state.cooldowns.meteor) and sim.state.nextAttackId == attack_before and sim.rng.state == rng_before, "R03 query shares runtime formula without mutating IDs or RNG")
	check(sim.upgrade_frequency("meteor").nextInterval == expected, "R03 next candidate period uses current build")
	E.spawn_boss(sim); E.warn_boss(sim, sim.state.enemies[0])
	check(sim.state.researchHints.bossFirstPreview.safeAngle == sim.state.bossSafeDirection, "R06 first safe direction matches actual boss reservation")
	sim.state.hazards.clear(); h = E.hazard(sim, "boss", "circle", Vector2.ZERO, 90, 1, 0.4); h.warning = 0; sim.state.player.hp = 1; E.update_hazards(sim, 0.05)
	check(sim.state.deathDetail.sourceId == "B01" and sim.state.deathDetail.patternId.begins_with("B01-P") and sim.state.deathDetail.hazardId == h.id, "R17 death source retains boss/pattern/hazard IDs")
	sim = fresh(); open_event(sim, "E01"); sim.choose_event("xp")
	check(sim.state.eventOutcomes.size() == 1 and sim.state.eventOutcomes[0].completed and sim.state.eventOutcomes[0].choice == "xp", "R23 actual completed choice history is available")
	sim = fresh(); open_event(sim, "E03"); sim.choose_event()
	check(not sim.state.eventOutcomes[0].completed, "R23 pending risk cannot appear as completed evidence")
	sim = fresh(); sim.state.artifacts = ["a087"]; var dasher := E.enemy(sim, 3, 0, Vector2(42, 0)); dasher.dashTime = 0.2; dasher.dashDirection = Vector2.LEFT
	C.field(sim, "glyph", Vector2.ZERO, 30, 3, {"sourceId": "m15", "damage": 0.0, "context": sim.context("m15"), "nextTick": 0.5})
	E.advance_enemies(sim, 0.05)
	check(dasher.x == 42 and sim.state.player.hp == 6 and dasher.dashTime == 0, "A087 existing glyph cancels dash before same-frame contact damage")
	print("Release review regressions: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
