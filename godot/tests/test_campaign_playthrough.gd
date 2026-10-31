extends SceneTree

# Ordinary campaign probe: never writes simulation state. Decisions use only
# movement, offered menu APIs, and visible enemy/projectile/hazard geometry.
const Sim = preload("res://scripts/release_simulation.gd")
const Enc = preload("res://scripts/release_encounters.gd")
const DT := 1.0 / 30.0
const REPORT := "res://../.omx/release-implementation/playability-report.json"
var failures: Array = []
var runs: Array = []
var direction := Vector2.ZERO

func require(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func pos(item: Dictionary) -> Vector2:
	return Vector2(item.x, item.y)

func build_for(index: int) -> Array:
	if index in [3, 4]: return ["orbit", "pulse", "bolt", "lightning", "fireball", "meteor"]
	if index == 5: return ["m15", "vortex", "m16", "pulse", "bolt", "lightning"]
	return ["bolt", "lightning", "fireball", "meteor", "frost", "vortex"]

func upgrade_score(sim, item: Dictionary, desired: Array) -> float:
	var s: Dictionary = sim.state
	if item.has("requires"): return 1000.0
	var id: String = item.id
	if id == "vitality": return 160.0 if s.player.hp < s.player.maxHp * 0.65 else 15.0
	if s.spells.has(id):
		var level: int = s.spells[id]
		if desired.has(id): return 110.0 - level * 10.0 + (10.0 if level < 3 else -35.0)
		return 35.0 if level > 0 else -30.0
	return {"power": 55.0, "haste": 45.0, "magnet": 25.0}.get(id, 0.0)

func handle_menu(sim, desired: Array, log: Array) -> void:
	var s: Dictionary = sim.state
	var phase: String = s.phase
	var before: float = s.time
	sim.tick(DT)
	require(s.time == before, "menu freezes campaign time: " + phase)
	var choice := ""
	var accepted := false
	if phase == "upgrade":
		var best := -INF
		for item in s.choices:
			var score := upgrade_score(sim, item, desired)
			if score > best: best = score; choice = item.id
		accepted = sim.choose_upgrade(choice)
	elif phase == "artifact":
		var best := -INF
		for item in s.artifactChoices:
			var score: float = {"worldtreeleaf": 100.0, "aegis": 95.0, "secondheart": 90.0, "magicwand": 80.0, "blackcat": 75.0, "broom": 70.0}.get(item.id, 20.0)
			if score > best: best = score; choice = item.id
		accepted = sim.choose_artifact(choice)
	elif phase == "event":
		var id: String = s.activeEvent.id
		choice = "accept"
		if id == "E01": choice = "heal" if s.player.hp < s.player.maxHp else "xp"
		elif id == "E08": choice = s.eventChoices[0].id
		elif id in ["E02", "E05", "E07", "E10"]: choice = "decline"
		accepted = sim.choose_event(choice)
	elif phase == "resonance":
		choice = s.resonanceChoices[0].id
		accepted = sim.choose_resonance(choice)
	elif phase == "event_practice":
		if not s.practiceHazards.is_empty():
			choice = s.practiceHazards[0].shape
			accepted = sim.choose_practice_answer(choice)
		# Practice's own 15-second clock is a normal public API; campaign clock freezes.
		for frame in range(451): sim.tick_practice(DT)
	else:
		require(false, "unexpected paused phase: " + phase)
		return
	log.append({"time": before, "phase": phase, "choice": choice, "accepted": accepted})
	require(accepted, "offered choice accepted: " + phase + "/" + choice)

func steering(sim) -> Vector2:
	var s: Dictionary = sim.state
	var p := pos(s.player)
	var goal := Vector2.ZERO
	var target_distance := INF
	for item in s.gems:
		var distance := p.distance_to(pos(item))
		if distance < target_distance: target_distance = distance; goal = pos(item)
	# Approach genuinely placed events/chests; enemies can override for safety.
	for item in s.chests:
		if p.distance_to(pos(item)) < target_distance + 150: goal = pos(item); target_distance = p.distance_to(goal)
	for item in s.events:
		if item.status == "placed" and p.distance_to(pos(item)) < 400: goal = pos(item); target_distance = p.distance_to(goal)
	if not s.resonanceMarker.is_empty() and p.distance_to(pos(s.resonanceMarker)) < 400:
		goal = pos(s.resonanceMarker); target_distance = p.distance_to(goal)
	var nearest: Dictionary = {}
	var nearest_distance := INF
	var threats: Array = []
	for enemy in s.enemies:
		var distance := p.distance_to(pos(enemy))
		if distance < nearest_distance: nearest_distance = distance; nearest = enemy
		if distance < 300: threats.append(enemy)
	if target_distance == INF and not nearest.is_empty():
		var attack_distance := 170.0
		if s.level < 3 and s.classId in ["C03", "C04", "C05"]: attack_distance = 75.0
		goal = pos(nearest) + (p - pos(nearest)).normalized() * attack_distance
		# Tangential movement brings short-range starting spells into contact.
		if absf(nearest_distance - attack_distance) < 25: goal += (p - pos(nearest)).orthogonal().normalized() * 60
	var best := -INF
	var selected := Vector2.ZERO
	for candidate_index in range(17):
		var candidate := Vector2.ZERO if candidate_index == 16 else Vector2.from_angle(candidate_index * TAU / 16)
		var endpoint: Vector2 = p + candidate * s.player.speed * 0.35
		var score: float = (p.distance_to(goal) - endpoint.distance_to(goal)) * 0.1 + direction.dot(candidate) * 0.2
		for horizon in [0.14, 0.4]:
			var future: Vector2 = p + candidate * s.player.speed * horizon
			for enemy in threats:
				var ep := pos(enemy)
				var velocity: Vector2 = (p - ep).normalized() * enemy.speed
				if enemy.get("dashTime", 0) > 0: velocity = enemy.get("dashDirection", Vector2.ZERO) * 300.0
				var separation: float = future.distance_to(ep + velocity * horizon) - enemy.radius - s.player.radius
				if separation < 55: score -= pow(maxf(0, 55 - separation) / 12.0, 2.0) * 10
			for bullet in s.enemyProjectiles:
				if p.distance_to(pos(bullet)) > 250: continue
				var separation: float = future.distance_to(pos(bullet) + Vector2(bullet.vx, bullet.vy) * horizon) - bullet.radius - s.player.radius
				if separation < 25: score -= maxf(0, 25 - separation) * 4
			for hazard in s.hazards:
				if hazard.get("damage", 1) <= 0 or hazard.warning > horizon + 0.35: continue
				var predicted: Dictionary = hazard.duplicate()
				predicted.x += float(hazard.get("vx", 0)) * maxf(0, horizon - hazard.warning)
				predicted.y += float(hazard.get("vy", 0)) * maxf(0, horizon - hazard.warning)
				if Enc.contains(predicted, future, s.player.radius + 10): score -= 400
		if score > best: best = score; selected = candidate
	return selected

func invariant(sim, label: String) -> void:
	var s: Dictionary = sim.state
	require(is_finite(float(s.player.hp)) and is_finite(float(s.player.maxHp)) and s.player.hp >= 0 and s.player.hp <= s.player.maxHp, label + " finite player HP")
	require(is_finite(float(s.player.x)) and is_finite(float(s.player.y)) and is_finite(float(s.time)), label + " finite movement/time")
	require(sim.learned_count() <= 6 and s.fusions.size() <= 3, label + " build caps")
	require(s.enemies.size() <= 200 and s.enemyProjectiles.size() <= 300, label + " entity caps")
	for value in s.spells.values(): require(value >= 0 and value <= 5, label + " spell level cap")
	for enemy in s.enemies: require(is_finite(float(enemy.hp)) and is_finite(float(enemy.x)) and is_finite(float(enemy.y)), label + " finite enemy")

func save_report() -> void:
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"dt": DT, "research": [], "policy": "geometry-aware-16-direction-v1", "runs": runs, "invariant_failures": failures}, "\t"))
	else: require(false, "report output opened")

func run_probe(index: int) -> void:
	var seed_value := 731001 + index * 101
	var class_id := "C%02d" % (index + 1)
	var zone_id := "Z%02d" % (index + 1)
	var sim := Sim.new(seed_value, "campaign", {"classId": class_id, "zoneId": zone_id, "research": [], "runId": "ordinary-probe-%d" % seed_value})
	var desired := build_for(index)
	var choices: Array = []
	var snapshots: Array = []
	var damage: Array = []
	var frames := 0
	var menu_count := 0
	var peak_enemies := 0
	var started := Time.get_ticks_msec()
	var last_hp: float = sim.state.player.hp
	var boss_min_hp := 550.0
	direction = Vector2.ZERO
	sim.start()
	while sim.state.phase not in ["won", "lost"] and frames < 27010 and failures.is_empty():
		if sim.state.phase != "playing":
			menu_count += 1
			require(menu_count < 500, "no infinite menu loop")
			handle_menu(sim, desired, choices)
			continue
		if frames % 3 == 0: direction = steering(sim)
		sim.tick(DT, direction)
		frames += 1
		peak_enemies = maxi(peak_enemies, sim.state.enemies.size())
		if sim.state.player.hp < last_hp:
			damage.append({"time": sim.state.time, "hp": sim.state.player.hp, "source": sim.state.get("lastDamageSource", "unknown")})
		last_hp = sim.state.player.hp
		for enemy in sim.state.enemies:
			if enemy.kind == "boss": boss_min_hp = minf(boss_min_hp, enemy.hp)
		if frames % 900 == 0:
			invariant(sim, class_id)
			var snapshot := {"time": sim.state.time, "hp": sim.state.player.hp, "level": sim.state.level, "kills": sim.state.kills, "enemies": sim.state.enemies.size(), "boss": sim.state.bossSpawned}
			snapshots.append(snapshot)
			print("CHECKPOINT ", class_id, " ", JSON.stringify(snapshot))
	invariant(sim, class_id)
	require(sim.state.phase in ["won", "lost"], class_id + " terminates within 900s")
	var spells := {}
	for id in sim.state.spells:
		if sim.state.spells[id] > 0: spells[id] = sim.state.spells[id]
	var result := {"class": class_id, "zone": zone_id, "seed": seed_value, "phase": sim.state.phase, "reason": sim.state.endReason, "time": sim.state.time, "frames": frames, "level": sim.state.level, "xp": sim.state.xp, "hp": sim.state.player.hp, "spells": spells, "desired_spells": desired, "fusions": sim.state.fusions, "artifacts": sim.state.artifacts, "kills": sim.state.kills, "boss_seen": sim.state.bossSpawned, "boss_min_hp": boss_min_hp, "peak_enemies": peak_enemies, "completed_events": sim.state.completedEvents, "resonances": sim.state.resonances, "choices": choices, "damage": damage, "snapshots": snapshots, "wall_seconds": (Time.get_ticks_msec() - started) / 1000.0}
	runs.append(result)
	save_report()
	print("RUN_RESULT ", JSON.stringify(result))

func replay_prefix() -> void:
	# Cheap deterministic replay of the first run's first 30 seconds.
	var file := FileAccess.open(REPORT, FileAccess.READ)
	require(file != null, "recorded report exists for prefix replay")
	if file == null: quit(1); return
	var recorded: Dictionary = JSON.parse_string(file.get_as_text())
	var original: Dictionary = recorded.runs[0]
	var expected: Dictionary = original.snapshots[0]
	var sim := Sim.new(int(original.seed), "campaign", {"classId": original.class, "zoneId": original.zone, "research": [], "runId": "prefix-replay"})
	var log: Array = []
	var frames := 0
	direction = Vector2.ZERO
	sim.start()
	while frames < 900 and failures.is_empty():
		if sim.state.phase != "playing": handle_menu(sim, build_for(0), log); continue
		if frames % 3 == 0: direction = steering(sim)
		sim.tick(DT, direction); frames += 1
	var actual := {"time": sim.state.time, "hp": sim.state.player.hp, "level": sim.state.level, "kills": sim.state.kills, "enemies": sim.state.enemies.size(), "boss": sim.state.bossSpawned}
	for key in expected: require(is_equal_approx(float(actual[key]), float(expected[key])) if expected[key] is float else actual[key] == expected[key], "deterministic prefix " + key)
	invariant(sim, "prefix replay")
	var result := {"seed": original.seed, "frames": frames, "expected": expected, "actual": actual, "invariant_failures": failures}
	var output := FileAccess.open("res://../.omx/release-implementation/playability-report.replay.json", FileAccess.WRITE)
	if output: output.store_string(JSON.stringify(result, "\t"))
	print("PREFIX_REPLAY ", JSON.stringify(result))
	quit(1 if not failures.is_empty() else 0)

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--replay-prefix"):
		replay_prefix(); return
	for index in range(6):
		run_probe(index)
		if not failures.is_empty(): break
	print("PLAYABILITY_RUNS ", runs.size(), " INVARIANT_FAILURES ", failures.size())
	quit(1 if not failures.is_empty() else 0)
