extends SceneTree
const Sim = preload("res://scripts/release_simulation.gd")
const E = preload("res://scripts/release_encounters.gd")
const C = preload("res://scripts/release_combat.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func fresh(zone: String = "Z01"):
	var s := Sim.new(98, "campaign", {"zoneId": zone, "runId": "repro"})
	s.start(); s.state.spawnTimer = 10000; s.state.eliteTimer = 10000
	for id in s.state.spells: s.state.spells[id] = 0
	return s
func actor(sim, id: int, position: Vector2 = Vector2(150, 0)) -> Dictionary:
	return E.enemy(sim, id, 0, position)
func _initialize() -> void:
	var s = fresh(); var a := actor(s, 2); a.hp = 100; a.maxHp = 100; s.apply_damage(a, 1, s.context("bolt")); var old_y: float = a.y; E.advance_enemies(s, 0.1)
	check(a.y != old_y, "N02 hit changes evasive direction")
	for id in [3, 4]:
		s = fresh(); a = actor(s, id); a.specialTimer = 0; E.advance_enemies(s, 0.05)
		check(a.dashWarning > 0 and a.dashTime == 0, "dash warns before motion N%d" % id)
		a.dashWarning = 0; a.dashTime = 0.3; a.dashDirection = Vector2.LEFT; E.advance_enemies(s, 0.1)
		check(a.dashDirection.y != 0 if id == 4 else a.dashDirection == Vector2.LEFT, "N03 straight / N04 single turn")
	for id in [5, 6]:
		s = fresh(); a = actor(s, id); a.hp = 100; a.maxHp = 100; a.facing = Vector2.LEFT
		var hit: float = s.apply_damage(a, 10, s.context("pulse"))
		check(is_equal_approx(hit, 5.5 if id == 5 else 10), "directional armor N%d" % id)
	for id in [7, 8]:
		s = fresh(); a = actor(s, id); a.castTimer = 0; E.advance_enemies(s, 0.05)
		check(a.castWarning > 0 and s.state.enemyProjectiles.is_empty(), "shooter cast warning N%d" % id)
		a.castWarning = 0.01; E.advance_enemies(s, 0.05)
		check(s.state.enemyProjectiles.size() == (1 if id == 7 else 3), "single/fan projectiles N%d" % id)
	s = fresh(); a = actor(s, 9); a.hp = 0.1; s.apply_damage(a, 1, s.context("bolt"))
	check(s.state.enemies.size() == 1 and s.state.enemies[0].summon and s.state.enemies[0].variant == 1, "N09 death summons one nonrecursive fragment")
	s = fresh(); a = actor(s, 10); a.hp = 0.1; s.apply_damage(a, 1, s.context("bolt"))
	check(s.state.hazards.size() == 1 and s.state.hazards[0].warning >= 1, "N10 death leaves delayed blast")
	s = fresh(); a = actor(s, 12); var b := actor(s, 11, Vector2(155, 20)); var old: float = a.x; E.advance_enemies(s, 0.1)
	check(old - a.x > 10.5, "N12 nearby swarm accelerates")
	s = fresh(); a = actor(s, 14); old = a.x; E.advance_enemies(s, 0.1)
	check(a.x > old, "N14 close lure retreats")
	for id in [15, 16]:
		s = fresh(); a = actor(s, id); b = actor(s, 1, Vector2(160, 0)); a.specialTimer = 0; E.advance_enemies(s, 0.05)
		check(b.shield > 0 if id == 15 else b.get("supportSpeedUntil", 0) > 0, "support gives single timed benefit N%d" % id)
	for id in [17, 18]:
		s = fresh(); a = actor(s, id); a.castWarning = 0.01; a.castTarget = Vector2.ZERO; E.advance_enemies(s, 0.05)
		check(s.state.hazards.size() == (1 if id == 17 else 2), "one/two beat delayed area N%d" % id)
	for id in [19, 20]:
		s = fresh(); a = actor(s, id); a.castWarning = 0.01; a.castTarget = Vector2.ZERO; E.advance_enemies(s, 0.05)
		check(s.state.hazards[0].angle == (0 if id == 19 else PI * 0.5), "projection direction differs N%d" % id)
	s = fresh(); a = actor(s, 21); a.hp = 100; a.maxHp = 100
	check(s.apply_damage(a, 2, s.context("bolt").merged({"projectile": true})) == 0 and s.apply_damage(a, 2, s.context("bolt").merged({"projectile": true})) > 0, "N21 absorbs one weak projectile then exposes")
	s = fresh(); a = actor(s, 22); C.field(s, "vortex", Vector2(150, 0), 80, 3); E.advance_enemies(s, 0.05)
	check(s.status_time(a, "vulnerable") > 0, "N22 area exposure creates vulnerability")
	for id in [23, 24]:
		s = fresh(); a = actor(s, id); a.specialTimer = 0; E.advance_enemies(s, 0.05)
		check(a.hidden > 0 and s.state.effects.any(func(x): return x.type == "reappear_warning"), "stealth reappearance has positional warning N%d" % id)
	# Special casting can be delayed once; bosses are immune and already fired bullets survive glyphs.
	s = fresh(); a = actor(s, 7); a.castWarning = 0.5; s.delay_enemy_cast(a.id, 1); s.delay_enemy_cast(a.id, 1)
	check(is_equal_approx(a.castWarning, 1.5), "ordinary cast can be delayed only once")
	a.kind = "boss"; s.delay_enemy_cast(a.id, 1)
	check(is_equal_approx(a.castWarning, 1.5), "boss warning never interrupted")
	s = fresh(); a = actor(s, 7); E.bullet(s, a, Vector2.LEFT); C.field(s, "glyph", Vector2(150, 0), 100, 2, {"damage": 0, "context": s.context("m15")}); C.update_fields(s, 0.01)
	check(s.state.enemyProjectiles.size() == 1, "glyph cannot erase already fired projectile")
	# Collision uses actual shape geometry and safe gaps.
	var ray := {"shape": "ray", "x": 0.0, "y": 0.0, "radius": 10, "angle": 0.0, "length": 200, "width": 10}
	check(E.contains(ray, Vector2(150, 0), 15) and not E.contains(ray, Vector2(0, 90), 15), "ray collision is a segment, not a circle")
	var ring := {"shape": "ring", "x": 0.0, "y": 0.0, "radius": 200, "innerRadius": 90, "safeGap": {"angle": 0.0, "width": PI / 2}}
	check(not E.contains(ring, Vector2(150, 0), 15) and E.contains(ring, Vector2(-150, 0), 15), "ring safe gap is real collision space")
	s = fresh("Z03"); s.state.time = 150; E.advance_phenomenon(s, 0.01); a = s.state.hazards[0]; s.state.cleansingStones[0].x = a.x; s.state.cleansingStones[0].y = a.y; s.state.player.x = a.x; s.state.player.y = a.y
	for i in range(31): E.advance_world(s, 0.05)
	check(s.state.cleansingStones[0].cooldown > 0 and s.state.hazards.is_empty(), "Z03 stone dwell cleans one patch and starts20s cooldown")
	s = fresh("Z04"); s.state.time = 180; E.advance_phenomenon(s, 0.01); a = s.state.hazards[0]; a.warning = 0; s.state.player.y = a.y; old = s.state.player.x; E.update_hazards(s, 0.05)
	check(absf(s.state.player.x - old) <= 45 * 0.05 + 0.001 and s.state.player.hp == 6, "Z04 current capped45/sec without damage")
	s = fresh("Z04"); E.spawn_boss(s); a = s.state.enemies[0]; a.hp = 100; E.warn_boss(s, a)
	check(s.state.hazards.size() == 2 and s.state.hazards[1].warning >= 6 and s.state.hazards[0].flowX == -s.state.hazards[1].flowX, "B04 stage2 reverses two streams sequentially")
	# Actual input-driven simulation replay, not only isolated fixtures.
	var first := replay(); var second := replay()
	check(first == second, "same seed+input+choices reproduces simulation state")
	check(first.time > 10 and first.kills > 0 and first.maxEnemies <= 200 and first.maxProjectiles <= 300, "ordinary replay exercises combat within budgets")
	print("Release encounters: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
func replay() -> Dictionary:
	var sim := Sim.new(901, "campaign", {"runId": "same-input"}); sim.start()
	var max_enemies := 0; var max_projectiles := 0
	for i in range(3600):
		if sim.state.phase == "upgrade": sim.choose_upgrade(sim.state.choices[0].id)
		elif sim.state.phase == "artifact": sim.choose_artifact(sim.state.artifactChoices[0].id)
		elif sim.state.phase == "event": sim.decline_event()
		elif sim.state.phase == "resonance": sim.decline_resonance()
		elif sim.state.phase in ["won", "lost"]: break
		sim.tick(1.0 / 60.0, Vector2.from_angle(i * 0.002))
		max_enemies = maxi(max_enemies, sim.state.enemies.size()); max_projectiles = maxi(max_projectiles, sim.state.projectiles.size())
	return {"time": sim.state.time, "kills": sim.state.kills, "level": sim.state.level, "hp": sim.state.player.hp, "phase": sim.state.phase, "rng": sim.rng.state, "maxEnemies": max_enemies, "maxProjectiles": max_projectiles}
